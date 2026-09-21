# Runbook

Operational guide for the `dev` and `prod` environments. Audience: the operator (and AI agents
helping them).

## Architecture (summary)

- **AWS `us-east-1`:** two independent environments, each with its own VPC (dev `10.0.0.0/16`,
  prod `10.1.0.0/16`), EKS cluster (`todolist-dev`, `todolist-prod`; managed node group, `t3.small`,
  min 1 / max 3), Aurora PostgreSQL Serverless v2 (single writer, 0.5–2 ACU), Secrets Manager,
  Route 53 + ACM, and a budget. ECR and the GitHub App are **shared**.
- **Prod safeguards:** `deletion_protection`, final snapshot on destroy, 14-day backups, and EKS
  control-plane logging. The footprint matches dev on purpose — this demonstrates feasibility, not
  scale (ADR-011).
- **Cluster add-ons:** External Secrets Operator, AWS Load Balancer Controller, ExternalDNS,
  metrics-server, Cluster Autoscaler, **Argo CD**, and ARC runners (one per environment for the app,
  one for the platform pipeline).
- **Delivery (GitOps):** GitHub Actions → ARC runner (IRSA, in-VPC) → ECR (by digest) → **commit the
  digest to Git** → Argo CD reconciles the app chart → pods. Access: Route 53 → ALB (ACM TLS) →
  Ingress → Service → pods → Aurora.
- Argo CD is the only owner of the application release; CI never runs `helm upgrade` (ADR-012). The
  app reads credentials from Secrets Manager via ESO; no credentials are committed.

See [Decisions](../decisions/index.md) for the rationale, [Costs](../costs.md) for the budget model,
and the [hardening backlog](hardening.md) for the proposed follow-ups.

## Prerequisites

- AWS credentials (short-lived; `aws login` + a bridge profile for the SDK).
- OpenTofu ≥ 1.10, `kubectl`, `helm`, `docker`.
- The GitHub App credentials stored in Secrets Manager as `todolist-dev/github-app` (shared).
- A GitHub Environment named `prod` with a **required reviewer** (gates promotion).

## Provision

1. **Bootstrap remote state (once).** Apply with local state, then self-host it:
   ```bash
   tofu -chdir=platform/bootstrap init -backend=false
   tofu -chdir=platform/bootstrap apply
   tofu -chdir=platform/bootstrap init -migrate-state -backend-config=backend.hcl
   ```
2. **Dev foundation + add-ons.**
   ```bash
   tofu -chdir=platform/environments/dev init -backend-config=backend.hcl
   tofu -chdir=platform/environments/dev apply
   ```
3. **Prod foundation + add-ons** (separate state key `prod/terraform.tfstate`).
   ```bash
   tofu -chdir=platform/environments/prod init -backend-config=backend.hcl
   tofu -chdir=platform/environments/prod apply
   ```
   Or run the platform pipeline (plan on PR/push, apply with approval) for either root.

## Platform pipeline

`.github/workflows/platform.yml` runs `tofu plan` on push/PR and `tofu apply` on
`workflow_dispatch` (gated by the `platform` environment). It runs on `arc-infra-runner`, which is
registered to the **platform** repository (the app runner registers to the app repository). It needs:

- the runner's IRSA role (broad in dev) and the AWS CLI on the runner (the workflow installs it);
- platform-wide, non-secret config in SSM — `/platform/base_domain` and `/platform/budget_alert_emails`,
  published once by the `bootstrap` root — loaded as `TF_VAR_*` before `init`. Without these, `plan`
  fails because `terraform.tfvars` is not committed.

## Deploy the app

- **Dev:** push to `main`. CI builds, scans (Trivy, fails on CRITICAL), pushes to ECR by digest,
  commits the digest to `charts/todolist/gitops/dev.yaml`, and waits for Argo CD to sync. See
  [the pipeline](../onboarding/pipeline.md).
- **Prod:** publish a GitHub Release (or run the `Promote prod` workflow manually). Promotion copies
  the digest dev already runs into `charts/todolist/gitops/prod.yaml`; no rebuild. The `prod`
  environment requires an approval before the job runs.
- Wiring comes from the [contract](../concepts/contract.md): SSM parameters under `/platform/<env>`
  (environment facts) and `/platform/<env>/apps/<app>` (application facts). It is not stored in the
  app repo.
- **Platform handbook (`platform-docs`):** the same path with its own runner and contract under
  `/platform/<env>/apps/platform-docs/*`; the site itself is a static S3 + CloudFront deployment
  owned by the platform-docs repository.

## Argo CD

```bash
aws eks update-kubeconfig --name todolist-dev --region us-east-1 --alias todolist-dev
kubectl -n argocd get applications
kubectl -n argocd get application todolist -o jsonpath='{.status.sync.status} {.status.health.status}'
kubectl -n argocd port-forward svc/argocd-server 8080:443   # UI/API at https://localhost:8080
```

- The initial admin password is in the `argocd-initial-admin-secret` Secret in the `argocd`
  namespace.
- **Force a refresh:** `kubectl -n argocd annotate application todolist argocd.argoproj.io/refresh=hard --overwrite`.
- **Sync/rollback:** `kubectl -n argocd get application` shows the desired revision; roll back by
  reverting the digest commit (or `argocd app rollback`), not by editing the cluster.
- **One-time ownership transfer (dev):** Argo CD adopted the objects Helm had created (same release
  name, so no duplicates). The inert Helm release history was then removed so Argo CD is the sole
  owner: `kubectl -n todolist delete secret -l owner=helm,name=todolist`. Do **not** run
  `helm upgrade` for the app afterwards (ADR-012).

## Access

```bash
aws eks update-kubeconfig --name todolist-dev --region us-east-1 --alias todolist-dev
kubectl get nodes -o wide
```

- Dev URL: `https://dev.todolist.<base_domain>`; prod URL: `https://prod.todolist.<base_domain>`
  (login `admin`; the password is in Secrets Manager `todolist-<env>/app`).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Error acquiring the state lock` | Stale S3 lock from an interrupted run. `tofu force-unlock <id>` after confirming no run is active. **Never** `-lock=false`. |
| `kubectl`/k9s timeout | The operator IP changed. Update the allowlist out-of-band, then reconcile: `aws eks update-cluster-config --name <cluster> --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=<ip>/32`, `aws eks wait cluster-active --name <cluster>`, update `cluster_public_access_cidrs`, `tofu apply`. |
| Argo CD `OutOfSync` / `Missing` | The digest file changed but Argo CD has not polled yet. Force a refresh (above) or wait ~3 min. Check `kubectl -n argocd logs deploy/argocd-application-controller`. |
| Argo CD `Degraded` | Inspect the child resources: `kubectl -n todolist get pods`, `kubectl -n todolist describe deploy`. A bad digest or an unready ExternalSecret shows here. |
| Helm release stuck in `failed` (add-ons) | Add-on releases use `atomic = true`, so a failed install rolls back. If one lingers, `helm uninstall <release> -n <ns>` and re-apply. |
| Pods `Pending` | Node pod-density limit. Cluster Autoscaler adds a node (min 1 / max 3); check `kubectl -n kube-system logs deploy/cluster-autoscaler-aws-cluster-autoscaler`. |
| App `CrashLoopBackOff` | Database not reachable or the ExternalSecret has not synced: `kubectl -n todolist get externalsecret`, `kubectl -n todolist get configmap todolist -o yaml`. |
| ALB webhook `x509` errors | The ALB controller webhook cert rotated. `keepTLSSecret` prevents this on upgrades. |
| Destroy fails: `DependencyViolation` on a subnet/IGW, or `ResourceInUseException` on ACM | An orphaned ALB still holds ENIs, public IPs, and the certificate. Delete the ALB (and its target groups and `k8s-*` security groups), wait for the ENIs to disappear, then re-run. See *Teardown*. |
| Destroy fails: `Unable to uninstall Helm release arc-runner-set` (context deadline exceeded) | Lingering `AutoscalingRunnerSet` CRs/finalizers. Clear them, or remove the ARC release from state. See *Teardown*. |
| Recreate fails: `a secret with this name is already scheduled for deletion` | A previous teardown deleted the secret with the default 30-day recovery window, so the name is still held. Force-delete it (`aws secretsmanager delete-secret --secret-id <name> --force-delete-without-recovery`) and re-apply, or restore it and import. The `app-secrets` module now sets `recovery_window_in_days = 0`. |

## Teardown and recreate

!!! warning "Order matters"
    The ALB is created by the AWS Load Balancer Controller, **not** by Terraform. While it exists its
    ENIs hold the subnets, its public IPs block the internet-gateway detach, and the ACM certificate
    is in use. Terraform cannot delete any of those until the ALB is gone. Remove the load balancer
    **before** destroying, or the destroy fails with `DependencyViolation` / `ResourceInUseException`.

1. **Pause app deploys** (disable the workflows) so CI does not race with teardown.
2. **Stop GitOps, then remove the load balancer while the cluster is still running.** Argo CD
   self-heal would recreate a deleted Ingress, so delete the Application first:
   ```bash
   kubectl -n argocd delete application todolist --ignore-not-found
   kubectl -n todolist delete ingress todolist --ignore-not-found
   until [ -z "$(aws ec2 describe-network-interfaces \
     --filters Name=description,Values='ELB app/*' \
     --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)" ]; do echo waiting; sleep 10; done
   ```
   If the cluster is already gone, delete the orphaned ALB directly and wait for its ENIs to
   disappear:
   ```bash
   ALB_ARN=$(aws elbv2 describe-load-balancers --names <alb-name> \
     --query 'LoadBalancers[0].LoadBalancerArn' --output text)
   aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
   ```
   Also delete leftover target groups and the ALB controller's `k8s-*` security groups, or the VPC
   will not delete.
3. **Clear lingering ARC resources if the ARC Helm uninstall times out** (a known issue; the
   controller cannot finish removing the `AutoscalingRunnerSet` CRs):
   ```bash
   kubectl -n arc-runners delete autoscalingrunnerset --all --ignore-not-found
   for n in $(kubectl -n arc-runners get autoscalingrunnerset -o name 2>/dev/null); do
     kubectl -n arc-runners patch "$n" -p '{"metadata":{"finalizers":[]}}' --type=merge; done
   ```
   If it still fails, remove the ARC releases from state (the cluster is going away anyway) and
   re-run: `tofu state rm <arc helm_release addresses>`.
4. **Decide on data:** dev data is disposable (`skip_final_snapshot = true`); prod takes a final
   snapshot and has `deletion_protection = true`, so **disable deletion protection first**.
5. **Destroy each environment** (state bucket is `prevent_destroy` and is **not** removed):
   ```bash
   tofu -chdir=platform/environments/dev destroy
   tofu -chdir=platform/environments/prod destroy -var 'db_deletion_protection=false' -var 'db_skip_final_snapshot=true'
   ```
6. **Recreate:** repeat *Provision*, then push to `main` (dev) and publish a release (prod).
7. **Audit residual billable resources:** retained snapshots, ECR images, logs, public IPs, orphaned
   load balancers, and target groups.

## Recovery

- **App rollback (GitOps):** revert the digest commit, or run `Promote prod` with a previous `digest`
  input for prod; Argo CD reconciles. Image rollback does not revert the schema.
- **Database:** 7-day (dev) / 14-day (prod) backups with point-in-time restore; restore into a new
  cluster. Database migration recovery is handled separately from image rollback.
- **State:** retained and versioned in S3.

## Verification evidence (DEV-VERIFY)

- Login + task operations over HTTPS; `/healthz` → `ok`.
- Pod replacement: deleting a pod is recovered in ~7s with no downtime.
- Rolling updates: `maxUnavailable: 0` + PDB; deploys roll pods with the service staying up.
- **HPA** scaled 2 → 6 replicas under load; **Cluster Autoscaler** added a node (2 → 3).
- Aurora: 7-day retention and point-in-time restore.

**HA distinctions (explicit dev compromises):** pod recovery is not node/AZ HA (one node group, one
NAT gateway), and a single Aurora writer is not database HA (no reader/failover).

### Prod and GitOps (PROD-PROMOTION / GITOPS)

- **Prod provisioned** (93 resources) from `environments/prod`, independent of dev's state, VPC,
  database, secrets, and IAM; shared ECR and GitHub App.
- **Prod access:** `https://prod.todolist.<base_domain>/healthz` → `200`; the ExternalSecret synced
  and the ALB was created from the app Ingress.
- **Promotion by digest (no rebuild):** the dev-validated digest was promoted to prod and Argo CD
  reconciled prod to it (`Synced`/`Healthy`).
- **Rollback:** reverting the prod digest rolled the deployment back to the previous image; restoring
  the digest returned it to the promoted image — both reconciled by Argo CD.
- **Ownership:** CI never runs `helm upgrade`; Argo CD owns the application release in both
  environments, and the pipelines only commit the desired digest.
- **Limitations:** prod mirrors dev's footprint (no reader/AZ redundancy) on purpose; the `prod`
  GitHub Environment reviewer and Argo CD repository credentials (for a private app repo) are set up
  out of band.

## Costs

See [Costs](../costs.md). Both environments are ephemeral. Two levers, in `platform/scripts/cost.sh`:

- **Sleep (short breaks).** `scripts/cost.sh sleep` stops Aurora and scales the node groups to 0;
  `scripts/cost.sh wake` reverses it. This removes the node and Aurora lines but keeps EKS and NAT.
- **Destroy (longer gaps).** `tofu destroy` removes everything, including the EKS control planes and
  NAT gateways — the ~$0.29/hour floor that cannot be paused. Use it for anything longer than a day.

`scripts/cost.sh status` shows what is running and the estimated burn.

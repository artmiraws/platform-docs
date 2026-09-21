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

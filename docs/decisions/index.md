# Platform decisions

Decision record for the platform: the AWS foundation, the `dev` and `prod` environments, delivery,
and the platform/application boundary. Decisions are recorded before the work they describe and are
referenced by the architecture pages and the runbook.

- **Status:** Accepted (pending the open items noted in individual records)
- **Scope:** the `dev` and `prod` EKS environments and the platform that hosts applications.

!!! question "Open discussion"
    Whether an application should own its infrastructure (database, queue, bucket, secret) in its own
    repository, with the platform providing only the modules, is **not decided**. See
    [App infrastructure ownership](../discovery/app-infrastructure-ownership.md).

## ADR-001 — Infrastructure repository placement and ownership

**Context.** The project uses a dedicated infrastructure repository and an application repository.
The delivery plan requires a clear boundary between infrastructure lifecycle and application
releases.

**Decision.**

- The infrastructure repository owns the AWS foundation, managed with OpenTofu.
- The application repository keeps the image, Helm chart, and CI workflow.
- OpenTofu owns the cluster and all cluster add-ons. GitHub Actions owns only the application Helm
  release. Neither owns the other's resources.
- Add-on bootstrap is applied by the infrastructure repository (OpenTofu and/or bootstrap Helm). The
  application repository must not install cluster-wide controllers.

**Consequences.** Two repositories to maintain and a documented bootstrap order (cluster → add-ons →
app). Prevents state ownership conflicts and accidental app-pipeline destruction of infrastructure.

## ADR-002 — AWS account and region

**Decision.**

- Use the existing AWS account and region **`us-east-1`**.
- Use short-lived credentials and OIDC where possible; no long-lived access keys in the repository.
- Account identifiers and account-specific details are never committed.

**Consequences.** A single region to reason about. If latency matters more than cost, revisit
`sa-east-1` knowing its hourly rates are higher.

## ADR-003 — Environment scope, sizing, and budget

**Context.** The required cloud deliverable is one dev environment, not production. It is a
short-lived proof of concept that is destroyed after use. Budget target: **US$50/month**.

**Decision.**

- Provision exactly one `dev` EKS environment.
- Worker node type: **`t3.small`** (2 vCPU, 2 GiB), **two nodes** (min 1 / max 2). A `t3.small`
  node supports only **11 pods**, and the system add-ons plus the cluster controllers exceed that on
  a single node, so two nodes are required for the application and scaling headroom. (Prefix
  delegation could raise pod density on a single node; it needs node recreation and is a future
  optimization.)
- Keep cluster add-ons lean to fit 2 GiB: one CoreDNS replica and one EBS CSI controller replica;
  add Cluster Autoscaler, metrics-server, AWS Load Balancer Controller, and External Secrets
  Operator as the epics require them.
- Fallback: switch to **`t3.medium`** (2 vCPU, 4 GiB) if pods go `Pending` or are OOM-killed.
  `t4g.small` (ARM, slightly cheaper) is an option only if the image is built for `arm64`.
- Treat dev as ephemeral: create for validation/demo windows and destroy afterward.
- Configure AWS Budget alerts (50/80/100% of US$50). Alerts are not spending caps.
- A single NAT gateway and a single Aurora writer are explicit dev compromises.

**Rationale.** `t3.micro` (1 GiB) is too small. `t3.small` is the smallest practical x86 node: on a
2 GiB node roughly 1.4 GiB is allocatable after kubelet reservations, and the add-on set consumes
most of it, leaving little headroom for the application. Node size is a small share of total cost —
EKS, NAT, ALB, and Aurora dominate — so `t3.medium` is a low-cost fallback (about US$0.03 more per
hour) when demo stability matters more than the absolute minimum.

**Consequences.** See [`costs.md`](../costs.md). US$50/month requires short-lived windows; an
always-on stack is roughly 4× the budget. No production promotion stage is required.

## ADR-004 — EKS and add-on version selection

**Context.** The plan forbids hard-coding an outdated version as "latest"; versions are chosen at
implementation time and remain in standard support.

**Decision.**

- EKS Kubernetes **1.36**, the latest version in standard support in `us-east-1` at decision time.
  Re-check before apply and pin it in a variable rather than assuming.
- Managed add-ons, recommended/default builds for 1.36 at decision time:
  - `vpc-cni` `v1.22.4-eksbuild.3`
  - `coredns` `v1.14.3-eksbuild.23`
  - `kube-proxy` `v1.36.0-eksbuild.25`
  - `aws-ebs-csi-driver` `v1.66.0-eksbuild.1`
- Helm add-ons (AWS Load Balancer Controller, External Secrets Operator, metrics-server, Cluster
  Autoscaler): pin chart versions in variables and record them here when applied. The External
  Secrets Operator chart `2.10.0` is pinned for the initial implementation.
- Pin the OpenTofu providers (`hashicorp/aws`, `hashicorp/kubernetes`, `hashicorp/helm`) and commit
  `.terraform.lock.hcl`.
- **Vendor the Helm charts** as `.tgz` files under each module's `charts/` directory and reference
  them by local path, so `plan` and `apply` never depend on external chart repositories. Currently
  `aws-load-balancer-controller` 3.5.0, `external-secrets` 2.10.0, and `external-dns` 1.22.0.
  Updating a chart version means re-vendoring the tarball. Sources and SHA-256 checksums are
  recorded in [`vendored-charts.md`](../discovery/vendored-charts.md).

**Consequences.** Version choices are reproducible and reviewable, and plans work offline (a
transient chart-repository failure cannot break `plan`). Versions are re-verified at apply time;
re-vendoring is a deliberate step when upgrading a chart.

## ADR-005 — Aurora PostgreSQL Serverless v2 settings

**Context.** The application uses PostgreSQL. Dev must be managed and cheap, but Aurora Serverless
v2 is **not** free when idle.

**Decision.**

- Engine: **Aurora PostgreSQL Serverless v2** (`aurora-postgresql`), version **18.4** at decision
  time; re-check before apply.
- Capacity: minimum **0.5 ACU**, maximum **2 ACU** for dev; a single writer, no reader.
- Private connectivity only: a database subnet group in the private subnets, with a security group
  that allows PostgreSQL only from the VPC CIDR. Production would scope this to the node or cluster
  security group.
- Master credentials are generated and stored by **Secrets Manager** (`manage_master_user_password`),
  so no password is set in configuration; the secret is consumed through External Secrets Operator in
  EPIC-5.
- Backups: 7-day retention. `skip_final_snapshot` defaults to true because dev data is disposable;
  set it to false when retention is required.
- `deletion_protection` disabled for dev, with a documented snapshot step before destroy.

**Consequences.** Serverless v2 has **no auto-pause**: the cluster accrues at least the minimum ACU
plus storage while it exists, so idle cost is not zero. Aurora storage is distributed across AZs,
but a single compute instance is **not** equivalent to redundant compute/failover.

## ADR-006 — CI access to the EKS API

**Context.** GitHub-hosted runners have dynamic public IPs. Exposing the EKS API endpoint to the
internet, even authenticated, is rejected as a shortcut.

**Decision.**

- Run CI on a **self-hosted GitHub Actions runner inside the VPC**.
- Preferred implementation: `actions-runner-controller` (ARC) on the cluster, scaled to zero when
  idle. Fallback: a single small runner EC2 instance in a private subnet if ARC is too
  time-consuming.
- Keep the EKS API endpoint **private** (`endpoint_public_access = false`). If temporary public
  access is needed for operator use, restrict it to explicit CIDRs and never leave it open.
- Runner AWS access uses OIDC/IRSA with least privilege (ECR push, scoped EKS/Helm deploy). Runner
  Kubernetes RBAC is scoped to the application namespace.
- CI reaches EKS in-VPC; outbound to GitHub and AWS uses the dev NAT gateway.

**Consequences.** No public control-plane exposure; an extra bootstrap step to register the runner.
If the runner is unavailable, deploys pause — acceptable for dev.

## ADR-007 — Browser access, DNS, and TLS

**Context.** R3 requires validating the actual documented hostname through the load balancer. A
custom domain is managed in **Route53** and TLS is issued with **ACM**.

**Decision.**

- Expose the app through an **ALB** created by the AWS Load Balancer Controller from a Helm-owned
  `Ingress` with a ClusterIP backend, not a literal `Service type: LoadBalancer`.
- Dev hostname: **`dev.todolist.<base_domain>`**.
- Certificate: an **ACM** certificate for that hostname, DNS-validated through the existing Route53
  hosted zone. An `A`/alias record points the hostname at the ALB.
- The base domain is a **required variable** (`base_domain`, no default) supplied at apply time via
  `terraform.tfvars` or CI secrets, and is never committed.

**Consequences.** HTTPS on the documented hostname, satisfying R3 more strongly than a bare ALB DNS
name. Adds Route53/ACM work and a required variable that must be set before apply.

## ADR-008 — Remote state, bootstrap, and pipeline model

**Context.** CI runners are ephemeral, so OpenTofu state cannot live on a runner. State must be
shared, locked, and protected, and the application pipeline must never manage infrastructure.

**Decision.**

- All state is remote. The `bootstrap` root creates the S3 bucket and then stores its own state in
  it (`key = bootstrap/terraform.tfstate`); the dev root uses `key = dev/terraform.tfstate`. This
  makes the first bootstrap a two-phase step: apply with local state, then `init -migrate-state`.
- The state bucket has versioning, SSE-S3 encryption, a public-access block, an HTTPS-only bucket
  policy, noncurrent-version expiry, and `prevent_destroy = true`.
- State locking uses S3 native lock files (`use_lockfile = true`, OpenTofu 1.10+), so no DynamoDB
  table is required.
- S3 lock files have no TTL: a cancelled, timed-out, or failed run can leave a stale lock. Recovery
  is `tofu force-unlock` after confirming no run is active, never `-lock=false`. CI uses a
  per-environment concurrency group so two runs cannot race.
- The bucket name is supplied as partial backend configuration and never committed. In CI it is
  derived at runtime from the caller identity; locally it comes from a gitignored `backend.hcl`.
- Pipelines authenticate with OIDC and short-lived credentials. A plan is produced as an artifact and
  applied only after approval. A CI concurrency group and the state lock prevent overlapping runs.
- Each environment uses a separate state key and its own IAM role. The application deploy pipeline
  never runs `tofu apply` or `tofu destroy`.
- Dev teardown destroys only the environment stack; the state bucket and required snapshots persist.

**Consequences.** Every stack is reproducible from remote state, bootstrap is self-hosted after the
first apply, and infrastructure stays isolated from application releases. `prevent_destroy` requires
a deliberate code change for an intentional bucket removal.

## ADR-009 — Cluster add-on management

**Context.** EKS needs several cluster add-ons. They can be installed by OpenTofu (`aws_eks_addon`
and the Helm provider), by a GitOps controller, or by CI. Installing the same release from more than
one owner causes drift and destructive updates, and the Helm provider does not manage CRDs reliably.

**Decision.**

- AWS-managed add-ons (`vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`) are installed with
  the `aws_eks_addon` resource, pinned to explicit versions.
- Third-party controllers tightly coupled to infrastructure (AWS Load Balancer Controller, External
  Secrets Operator, metrics-server, Cluster Autoscaler) are installed by this repository with the
  Helm provider. Chart versions are pinned in variables, and values are wired to Terraform outputs
  (for example, IRSA role ARNs).
- CRDs required by a chart are installed explicitly before the chart, rather than relying on the
  Helm provider to create or upgrade them.
- Exactly one owner per Kubernetes object. Terraform manages the add-ons above; the application
  repository owns the app `Deployment`, `Service`, `Ingress`, `HPA`, `PDB`, and `ExternalSecret`; CI
  owns only the application Helm release.
- If GitOps (ArgoCD, EPIC-10) is adopted, ownership of in-cluster releases transfers to ArgoCD and
  Terraform stops managing them. The transfer is explicit, not gradual.

**Consequences.** Add-ons are reproducible, their IAM wiring is reviewable in one plan, and
`tofu destroy` removes them in order. CRDs need an explicit installation step. A future ArgoCD
adoption is a deliberate migration rather than a competing owner.

**Alternatives considered.** Managing all in-cluster resources with ArgoCD from the start is the more
cloud-native pattern, but it requires a bootstrap controller before the cluster is usable and is
deferred to EPIC-10. Using CI to install cluster add-ons would give the application pipeline
infrastructure privileges, which ADR-001 rejects.

## ADR-010 — Application secrets

**Context.** The application needs database credentials. Credentials must not be stored in Git or
set in configuration, and only the workloads that need them should be able to read them.

**Decision.**

- The RDS-managed master credentials are generated and stored by **Secrets Manager**
  (`manage_master_user_password`); no password appears in code or state, only the secret ARN.
- The **External Secrets Operator** is installed by this repository with the Helm provider and uses
  an IRSA role scoped to the specific database secret ARN, granting only
  `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`.
- A cluster-scoped `ClusterSecretStore` (`aws-secrets-manager`) authenticates as the operator's
  service account through the cluster OIDC provider.
- Ownership is split: this repository owns the operator, its IRSA role, and the store; the
  application repository owns the `ExternalSecret` (created with the app chart in EPIC-7) that
  references the store.
- The `ExternalSecret` syncs the database credentials into a Kubernetes `Secret` consumed by the
  application; no secret value is committed or printed.

**Rotation and restart.** Secrets Manager rotation updates the source secret. The operator refreshes
the Kubernetes `Secret` on its refresh interval, but the application reads credentials at startup,
so a pod restart is required to pick up a rotated password. In-place credential reload is not
expected.

**Consequences.** Credentials are centralized and access is least-privilege, and state remains free
of secret values. Rotation requires a restart, which is acceptable for dev and documented as a
limitation.

## ADR-011 — Production environment and digest promotion

**Context.** R1/R2/R4 are met by one `dev` environment. The remaining gap is a production path that
promotes the artifact dev already validated, rather than rebuilding for production. The timebox and
budget do not allow production-grade capacity or HA, so production here demonstrates **feasibility**,
not scale.

**Decision.**

- Add a second environment root, `environments/prod`, that reuses the same modules with its own
  remote state (`prod/terraform.tfstate`), VPC (`10.1.0.0/16`), EKS cluster (`todolist-prod`),
  Aurora cluster, Secrets Manager secrets, IAM roles, SSM parameters (`/todolist/prod/*`), DNS name,
  and ARC runner. The ECR repository and the GitHub App are **shared** (the artifact store and the
  repo-scoped app are environment-independent).
- Production uses the **same small footprint as dev** (`t3.small`, two nodes) and turns on the
  production safeguards that cost nothing at this size: Aurora `deletion_protection = true`,
  `skip_final_snapshot = false`, 14-day backups, and EKS control-plane logging
  (`api`, `audit`, `authenticator`). True multi-AZ redundancy (reader, multiple NAT gateways) stays
  a documented limitation, consistent with the dev posture.
- **Promotion is by digest, never a rebuild.** The dev pipeline builds, scans, pushes, and records
  the resulting digest in Git (`charts/todolist/gitops/dev.yaml`, see ADR-012). A production deploy
  reads that digest and deploys the same image to prod.
- **Trigger:** a published GitHub Release (or an approval-gated `workflow_dispatch`), never a push to
  `main`. The `prod` GitHub Environment requires a reviewer, so promotion is an explicit approval.
- **Rollback** is a redeploy of the previous digest (the value is in Git history), tested as part of
  the environment verification. Database migration recovery is handled separately from image
  rollback (a schema change is not undone by rolling the image back).

**Consequences.** A second cluster roughly doubles the running cost while both exist; both are
ephemeral and destroyed after the demo. The promotion path is audit-friendly (digest + approval) and
does not rebuild for production.

## ADR-012 — GitOps with ArgoCD and explicit ownership transfer

**Context.** Today the application pipeline runs `helm upgrade` directly (CI owns the app release),
while OpenTofu owns the cluster add-ons (ADR-009). Introducing ArgoCD without a clear transfer would
leave two owners for the same objects.

**Decision.**

- Install **ArgoCD** in each environment with a new OpenTofu module (vendored chart). ArgoCD is
  cluster add-on infrastructure and is owned by this repository, like the other controllers.
- This repository creates one ArgoCD `Application` per environment. It points at the **application
  repository** chart (`charts/todolist` on `main`) and reads two sources of values:
  - a **digest file committed in the app repository** (`charts/todolist/gitops/<env>.yaml`), which CI
    updates; and
  - **non-secret wiring injected inline by OpenTofu** (`valuesObject`: database host, secret ARNs,
    hostname, certificate ARN), so account-specific values never enter Git.
- **Ownership transfer is explicit.** CI stops running `helm upgrade`; ArgoCD becomes the only owner
  of the application release. The application pipeline now builds, scans, pushes, and commits the
  image digest to the environment's digest file. Terraform continues to own the cluster add-ons; it
  does not create the application release.
- Dev syncs automatically from `main`. Prod syncs automatically too, but its digest file only changes
  through the approval-gated promotion flow (ADR-011), so "auto-sync" cannot deploy unreviewed code.
- ArgoCD is reachable in-cluster (ClusterIP) and is operated through `kubectl port-forward` for the
  demo. The application repository must be readable by ArgoCD; if it is private, repository
  credentials are added out of band and never committed.

**Consequences.** One owner per object, a reconcilable desired state in Git, and rollback by
reverting a commit or syncing a previous revision. Adds ArgoCD to the cluster and a Git write step to
CI. Argo Rollouts/canary stays a separate optional increment, not part of this transfer.

## ADR-013 — Platform vs application separation, one Argo CD, and the platform contract

**Context.** The first GitOps increment ran one Argo CD per cluster, named clusters after the
application (`todolist-dev`, `todolist-prod`), and let the dev environment root own the shared ECR
repository. That works for a single-app challenge but not for a real platform: a cluster hosts many
services, the platform owns foundational concerns, and an application must not be coupled to another
environment's lifecycle (destroying dev deleted the shared ECR that prod depended on).

**Decision.**

- **One Argo CD, no hub cluster (for now).** Argo CD runs in the `prod` cluster and manages every
  environment from a single view. A dedicated hub cluster stays the scale-out option once there are
  several clusters. Because EKS endpoints are private, Argo CD needs network reachability to each
  environment's API (VPC peering between environments now, a hub/Transit Gateway later); each
  environment registers with Argo CD as a cluster.
- **Platform-scoped naming.** Clusters and platform resources are named for the platform and the
  environment, never the application (for example `platform-dev`, `platform-prod`). An application
  name never appears in a platform resource name.
- **The platform owns foundations and the contract.** The platform repository (renamed from `infra`)
  owns the clusters, cluster add-ons, Argo CD, ingress/DNS/TLS, the secrets store, and the shared
  artifact registry (ECR). It publishes a per-environment **contract** in SSM that applications
  consume; applications never read Terraform state or platform internals.
- **Applications own their topology.** An application repository holds its chart and an
  **ApplicationSet** that generates its per-environment Applications. The application pipeline
  builds, scans, pushes, and commits the desired digest; Argo CD reconciles. Promotion stays
  digest-based and approval-gated.
- **Sizing.** `prod` scales to **3** worker nodes (max), more headroom than a two-node ceiling.
- **Documentation.** Platform documentation is centralized in a new `platform-docs` repository: a
  static site (which can itself be deployed onto the platform) covering how the platform was planned
  and built, its contract, and how to onboard an application. Application documentation stays with
  the application.

**Consequences.** One control plane to operate for GitOps, one place to onboard applications, and a
clean boundary between platform and application. The platform must solve cross-environment
reachability for Argo CD (peering or a hub), and the contract must be versioned because applications
depend on it.

**Open questions (resolve in GITOPS-HUB / PLATFORM-DOCS).**

- Cross-environment connectivity for Argo CD: VPC peering now, hub/Transit Gateway later.
- How Argo CD consumes the contract — **resolved by ADR-015**: a render-time config-management plugin
  reads the contract; Terraform injection is only the interim for the current single application.
- Which resources the platform provides as a service (database, secrets) versus which the
  application provisions; today the platform provisions the database for the single app.
- Static-site tooling for `platform-docs` (for example MkDocs Material, Docusaurus, or plain
  Markdown served statically).

## ADR-014 — Trunk-based delivery, versioned artifacts, and PR-based promotion

**Context.** Both environments currently track `main`, so a chart/template change on `main` reconciles
into prod even though the image digest is gated by `gitops/prod.yaml` — the promotion flow is only
half-enforced. The alternative, long-lived `dev`/`prod` branches, avoids that but introduces branch
divergence, merge-to-promote fragility, and a moving branch head as the audit target.

**Decision.**

- **One branch (`main`), trunk-based.** No long-lived environment branches; branch-per-environment is
  **rejected**.
- **Environment configuration lives in directories** (`envs/dev/`, `envs/prod/`), each pinning the two
  immutable artifacts: the **image digest** and the **chart version**.
- **Two versioned artifacts.** The image is built per commit and deployed by **digest** (build tag =
  commit SHA). The chart is packaged and pushed to ECR as an **OCI** artifact with a **semver** version
  when a release is published. Version tags on the image are **not** used; the digest is the identity.
- **dev tracks the chart source on `main`** so chart and app changes are validated continuously; CI
  updates `envs/dev/values.yaml` with the new digest.
- **prod pins the released chart version** (OCI) and the promoted digest in `envs/prod/values.yaml`,
  so `main` commits never reach prod.
- **Promotion is a pull request**, not a branch merge: it updates `envs/prod/values.yaml` to the
  dev-validated digest and the released chart version. Merging it is the approval; Argo CD reconciles.
- **Rollback** is another pull request (or a revert) restoring the previous version and digest.

**Consequences.** `main` affects only dev; prod changes only through a reviewed PR; the deployed
revision is an explicit pair (chart version + digest) instead of a moving branch head. This requires
packaging and publishing the chart as an OCI artifact and an ApplicationSet that reads the per-env
config.

**Promotion flow.**

1. Merge to `main` → the dev pipeline builds, scans, and pushes the image (SHA tag + digest) and
   commits the digest to `envs/dev/values.yaml`; Argo CD reconciles dev (chart source on `main`).
2. Publish a release (`vX.Y.Z`) → the release workflow packages the chart as `X.Y.Z` and pushes it to
   the OCI registry.
3. The promotion workflow opens a **PR** updating `envs/prod/values.yaml` with the released chart
   version and the dev-validated digest.
4. Review and merge the PR → Argo CD reconciles prod (OCI chart `X.Y.Z` + promoted digest).
5. Rollback: a PR (or a revert) restoring the previous chart version and digest.

## ADR-015 — Contract delivery: a render-time plugin, not Terraform injection

**Context.** The platform publishes a per-environment contract (SSM). Applications need it at render
time (image repository, database host, secret ARNs, ingress host/annotations). The first increment
injected those values from Terraform straight into the Argo CD `Application` (`valuesObject`). That
works for one application but couples the platform to each application's chart schema — every new
application would be a Terraform change, which contradicts the platform/application separation of
ADR-013.

**Decision.**

- Applications **resolve the contract at render time** with a **config-management plugin** (a CMP in
  Argo CD's repo-server that reads the contract from SSM and feeds it to Helm). The application owns
  its `ApplicationSet`; the platform stays application-agnostic.
- The plugin runs with **IRSA** scoped to read only the contract parameters.
- **Interim:** the current single application keeps Terraform-injected Application values until the
  plugin lands. This is explicitly a stopgap, not the target.
- **Rejected:** committing non-secret wiring to Git (keeps account data out of Git) and a runtime
  ConfigMap (cannot feed render-time values such as ingress annotations or the image repository).

**Consequences.** New applications onboard with no platform change — they consume the contract. The
platform must operate one small plugin and grant it SSM read access. The contract becomes the real
interface, so it must be versioned.

## ADR-016 — Single Argo CD: exposure, cross-cluster management, and ApplicationSets

**Context.** The first increment runs one Argo CD per cluster. ADR-013 chose a single Argo CD (in
prod, no hub) and ADR-014 chose trunk-based delivery with an `ApplicationSet` per application. This
records the operational shape and the security posture.

**Decision.**

- **Placement.** One Argo CD, in the `prod` cluster, managing every environment.
- **Reachability.** EKS endpoints are private, so the platform peers the environment VPCs (prod to
  dev) and registers each environment as an Argo CD cluster. A hub cluster or Transit Gateway is the
  scale-out path once there are more than a few clusters.
- **Exposure.** Argo CD is published at `argocd.<base_domain>` through an internet-facing ALB with an
  ACM certificate. Argo CD runs with `server.insecure=true` so TLS terminates once, at the ALB.
- **Hardening.** The UI is a cluster-admin surface: an ALB inbound-CIDR allowlist (never
  `0.0.0.0/0`), SSO (OIDC) with RBAC instead of the shared admin password, and the admin secret kept
  only as break-glass.
- **ApplicationSet.** Each application ships an `ApplicationSet` in its own repository. A `list`
  generator (`env: dev | prod`) produces one Application per environment; dev renders the chart from
  source on `main` and prod pins the released OCI chart version (ADR-014).
- **Contract.** The `ApplicationSet` does not read SSM itself; a config-management plugin resolves the
  platform contract into Helm values at render time (ADR-015).

**Consequences.** One UI and one control plane for every environment. The platform must solve
cross-VPC reachability and protect a single, high-value endpoint. Cluster registration and the
render-time plugin are the main new moving parts.

**Rejected.** One Argo CD per cluster (duplicated control planes, no single view); exposing Argo CD
without an allowlist or SSO; letting the `ApplicationSet` read Terraform/SSM directly.

## ADR-017 — GitOps engine: Argo CD over Flux CD

**Context.** The platform is a multi-environment, many-applications GitOps target (ADR-013, ADR-016).
Both Argo CD and Flux CD are CNCF-graduated and can reconcile Helm/Kustomize from Git, so the choice
was made on the operational shape the platform needs — a single view across environments and a
repeatable way to instantiate one application per environment. Argo CD was chosen in the first GitOps
increment (ADR-012); this record documents the comparison and reaffirms the decision.

**Comparison.**

| Dimension | Argo CD | Flux CD |
|---|---|---|
| Model | Centralized controller with a UI/API server; each environment is an `Application` CR | Distributed, composable controllers (source, helm, kustomize, notification) with no central server |
| Multi-cluster | First-class: one instance registers many clusters and manages them from one view | Each cluster runs its own controllers; multi-cluster needs per-cluster bootstrap and has no central view by default |
| UI | Built-in web UI and CLI with visual diff, sync, and health | No first-party UI (CLI and CR status; third-party UIs exist) |
| Templating / instantiation | Helm, Kustomize, plain YAML, and CMP plugins; `ApplicationSet` generators (list, cluster, git, matrix) | Helm and Kustomize controllers, OCI sources; composition via `Kustomization` chaining, no `ApplicationSet` equivalent |
| Secrets | No built-in secret engine; integrates with External Secrets Operator (used here), Sealed Secrets, or a plugin | Built-in SOPS/age integration for secrets encrypted in Git |
| Maturity / ecosystem | CNCF Graduated; very large ecosystem and the de-facto standard for UI-driven GitOps | CNCF Graduated; reference GitOps implementation, lighter and more controller-native |
| Reconcile model | Pull (agent in each managed cluster) or push from the central instance | Pull-native: each cluster watches Git |
| Operational cost | Server, repo-server, Redis, and a UI that is a cluster-admin surface to secure; needs network reachability to each managed cluster | No central server to run; simpler runtime, but no single view and per-cluster setup |

**Decision.** Use **Argo CD**.

**Rationale.** The platform needs a **single control plane and view** across environments
(ADR-013/016), an **`ApplicationSet`** to generate one Application per environment without editing
the platform (ADR-014/016), a **UI** for operations and the demo, and a **render-time config-management
plugin** to resolve the SSM contract (ADR-015). Secrets are already handled by External Secrets
Operator (ADR-010), so Flux's native SOPS integration is not a differentiator here. Flux's lighter,
pull-native model is attractive, but it optimizes for a different shape than this platform.

**Consequences.** The platform operates Argo CD's components and secures its UI, and must provide
network reachability from the central instance to each environment's private API. The GitOps engine is
now a dependency to keep upgraded.

**Revisit if.** The platform wants to remove the central server and its blast radius, move to fully
pull-native per-cluster reconciliation, or adopt SOPS-encrypted secrets in Git. At many clusters a hub
or a distributed model is reconsidered regardless of engine.

## ADR-018 — No service mesh

**Context.** The platform currently runs a single application (a Flask service and its database). A
service mesh (Istio, Linkerd) adds a control plane, per-pod proxies, and a new operational surface.
Its main benefits — mutual TLS, L7 traffic policy, and service-to-service telemetry — apply to
east-west traffic between multiple services, which this platform does not yet have.

**Decision.** Do **not** deploy a service mesh. Use the primitives already in place:

- **North-south TLS:** ALB with an ACM certificate in front of the Ingress (ADR-007).
- **Network isolation:** Kubernetes `NetworkPolicy` for coarse pod-level segmentation.
- **Health and rollout safety:** probes, a PodDisruptionBudget, and `maxUnavailable: 0` (the chart).
- **Observability:** metrics scraped by the kube-prometheus-stack baseline ([`OBSERVABILITY`](../tasks.md)).
- **App-level progressive delivery:** Argo Rollouts covers canary without a mesh (future work).

**Consequences.** Fewer moving parts and lower cost and latency now, at the price of no mTLS between
pods and no mesh-level traffic policy. The application's traffic is north-south only, so this is not a
current gap.

**What would change it.**

- **Multiple services** with meaningful east-west traffic, where per-service identity matters.
- **mTLS / zero-trust** requirements between workloads.
- **Traffic splitting** or fine-grained routing beyond what Argo Rollouts and the Ingress provide.
- **Finer-grained L7 observability**, retries, timeouts, or circuit breaking at the mesh layer.
- **Multi-tenant isolation** requirements stronger than `NetworkPolicy` can express.

Revisit alongside [`OBSERVABILITY`](../tasks.md) and the canary work; adopt a mesh only when one of the above is a
concrete requirement, not preemptively.

## Assumptions

- The AWS account, region, and required service quotas are available.
- A Route53 hosted zone for `base_domain` exists and ACM DNS validation can be completed.
- The estimates in [`costs.md`](../costs.md) are validated against current AWS pricing before apply.
- The selected EKS and add-on versions remain in standard support at apply time.

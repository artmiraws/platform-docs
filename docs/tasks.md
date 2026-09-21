# Tasks

The work tracker, summarized. Each task has a stable ID, a status (`done`, `open`, `in_progress`,
`deferred`), a priority, and a one-line description. The full entries — verification, evidence, and
notes — live in the repository's `TASKS.yaml`.

**21 done · 6 open · 1 in progress · 1 deferred.**

| ID | Status | Pri | Task |
|---|---|---|---|
| `PLAN` | done | - | Create and maintain the delivery plan, decisions, and requirement-aligned epics. |
| `LOCAL-DEPLOY` | done | - | Build a multi-stage image and run the app with PostgreSQL in local k3d/k3s. |
| `LOCAL-GUIDE` | done | - | Add a beginner-oriented local Kubernetes guide and Makefile entry points. |
| `LOCAL-VERIFY` | done | P0 | Audit the local setup, fix the docs, and verify login, CRUD, and health checks. |
| `AWS-DECISIONS` | done | P0 | Confirm repository ownership, account/region/budget, costs, and versions. |
| `AWS-STATE-NETWORK` | done | P0 | Bootstrap remote state and define the VPC/subnet modules and the dev root. |
| `AWS-EKS` | done | P0 | Provision the EKS cluster and a small managed node group with least-privilege IAM. |
| `AWS-DATABASE` | done | P0 | Provision private Aurora PostgreSQL Serverless v2 with bounded capacity. |
| `AWS-SECRETS` | done | P0 | Use Secrets Manager and External Secrets Operator for application secrets. |
| `APP-HELM` | done | P0 | Package the app with Helm, digest images, probes, resources, HPA, and a PDB. |
| `LOCAL-HELM` | done | P0 | Consolidate local onto the Helm chart (one chart, values per environment). |
| `AWS-ACCESS` | done | P0 | Add the ALB controller and expose the app through a Helm-owned Ingress and ALB. |
| `DEV-CICD` | done | P0 | Add ECR and the CI pipeline: build, scan, publish by digest, deploy, verify. |
| `DEV-VERIFY` | done | P0 | Verify access, pod recovery, rolling updates, HPA/autoscaler scaling, and recovery. |
| `DOCS-RUNBOOK` | done | P0 | Write the operational docs and the ADRs alongside the implementation. |
| `DOCS-REVIEW` | done | P0 | Review every document for accuracy and add context-optimized entry points. |
| `APP-RELEASES` | done | P1 | Automate semantic versioning and GitHub Releases from Conventional Commits. |
| `PROD-PROMOTION` | done | P1 | Add a prod environment and promote the dev-validated digest with approval. |
| `GITOPS` | done | P1 | Introduce Argo CD and transfer application ownership from Helm to it. |
| `FUTURE-HARDENING` | done | P2 | Split hardening improvements into an individually approvable backlog. |
| `GITOPS-HUB` | open | P1 | One Argo CD for every environment, platform-scoped names, and a shared registry. |
| `OBSERVABILITY` | open | P1 | Add a lean Prometheus + Grafana stack with app and cluster dashboards. |
| `ARCH-DOCS` | done | P2 | Document the Argo CD vs Flux decision and the no-service-mesh decision. |
| `PLATFORM-RENAME` | open | P1 | Rename resources to platform scope and move the contract. |
| `PLATFORM-DOCS` | done | P1 | Improve the plan/tracker and serve the handbook as a static site. |
| `GITOPS-ADDONS` | deferred | P2 | Move the third-party controllers from Terraform to Argo CD (app-of-apps). |
| `CONTRACT-SHAPE` | done | P0 | Adopt the platform-scoped contract (`/platform/<env>/...`). |
| `HANDBOOK-POLISH` | done | P1 | Apply the handbook adjustments (discovery, evidence, trimmed runbook, ...). |
| `TASKS-DOC` | in_progress | P1 | Publish a concise tracker as a handbook page and link task references. |

## How tasks move

```text
Idea ──► Discovery (timeboxed spike) ──► Decision (ADR) ──► Delivery (task) ──► Done
```

See the [Roadmap](roadmap.md) for the horizons and the [Discovery](discovery/app-infrastructure-ownership.md)
items.

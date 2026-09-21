# Repository structure

The platform is three repositories with a clear split: the **platform** provides foundations, an
**application** repository owns its chart and pipeline, and this **handbook** is itself an
application deployed onto the platform.

| Repository | Owns |
|---|---|
| `platform` | Clusters, networking, add-ons, Argo CD, the registry, the contract, and CI runners. |
| `todolist-app` | The application image, Helm chart, pipeline, and app-specific resources. |
| `platform-docs` | This handbook (content, chart, and pipeline). |

## `platform` — the foundation

```text
platform/
├── bootstrap/                     # one-time: S3 state bucket + /platform/* config
├── modules/
│   ├── vpc/                       # platform: networking
│   ├── eks/                       # platform: cluster + node group + managed add-ons
│   ├── ecr/                       # platform: the shared artifact registry
│   ├── eso/                       # platform: External Secrets Operator + store
│   ├── alb/                       # platform: AWS Load Balancer Controller
│   ├── dns/                       # platform: ExternalDNS (publishes Ingress hostnames)
│   ├── acm/                       # certificate for a hostname (used by apps)
│   ├── arc/                       # platform: ARC controller + first runner scale set
│   ├── arc-runner/                # platform: an extra per-repo runner scale set
│   ├── infra-runner/              # platform: the runner the platform pipeline uses
│   ├── metrics-server/            # platform: metrics for HPA
│   ├── cluster-autoscaler/        # platform: node scaling
│   ├── argocd/                    # platform: Argo CD itself
│   ├── argocd-app/                # platform: registers an Application with Argo CD
│   ├── app-secrets/               # app: an application's Secrets Manager secret
│   └── app-todolist/              # app: the TodoList database, secret, cert, Application
├── environments/
│   ├── dev/                       # root: platform modules + the app module(s)
│   └── prod/                      # root: same shape, separate state
└── .github/workflows/platform.yml # plan on push/PR, apply on approval
```

- The **platform** modules are instantiated once per environment. They never reference an
  application by name.
- The **app** modules (`app-todolist`, `app-secrets`) are the app-specific resources. The platform
  root instantiates them with platform inputs (VPC, cluster, zone, registry) and publishes the
  resulting values as the [contract](../concepts/contract.md).
- Each environment is a root with its own state key (`dev/terraform.tfstate`,
  `prod/terraform.tfstate`). The app resources live in that state today; moving them to per-app roots
  is tracked in [`GITOPS-HUB`](../tasks.md) (ADR-013).

## `todolist-app` — an application

```text
todolist-app/
├── app.py                     # the Flask application
├── requirements.txt
├── Dockerfile                 # multi-stage image
├── charts/todolist/           # the Helm chart (one chart, values per environment)
│   ├── Chart.yaml
│   ├── values.yaml            # cloud defaults
│   ├── values-local.yaml      # local k3d overrides
│   ├── gitops/
│   │   └── dev.yaml           # desired image digest (written by CI)
│   └── templates/             # Deployment, Service, Ingress, HPA, PDB, CronJob, ...
├── deploy/applicationset.yaml # one Argo CD Application per environment (target)
├── .github/workflows/
│   ├── deploy-dev.yml         # build, scan, push, commit digest, wait, smoke
│   ├── promote-prod.yml       # promote the dev-validated digest (approval)
│   └── release.yml            # release-please + chained promotion
├── docs/                      # app-specific docs (local run, chart)
└── README.md
```

## `platform-docs` — this handbook

```text
platform-docs/
├── docs/                      # the Markdown you are reading
├── mkdocs.yml                 # site config and navigation
├── Dockerfile                 # mkdocs build -> nginx
├── charts/platform-docs/      # the Helm chart
│   ├── gitops/dev.yaml        # desired image digest (written by CI)
│   └── templates/
├── .github/workflows/deploy-dev.yml
└── Makefile
```

## What lives where

| Concern | Where |
|---|---|
| Cluster, VPC, add-ons, Argo CD, ECR, runners | `platform/` (platform modules) |
| An app's database, secret, hostname cert, Application | `platform/modules/app-<app>/` |
| An app's image, chart, values, pipeline | the application repository |
| Platform concepts, decisions, runbook | `platform-docs/` |
| App-specific how-to (local run, chart values) | the application repository |

See [Ownership](../concepts/ownership.md) for the rules and
[Worked example: TodoList](../onboarding/worked-example.md) for the concrete case.

# Ownership

The platform and its applications are separate concerns with a clean boundary. Every Kubernetes
object and every cloud resource has exactly one owner, and the Terraform reflects it: **platform**
modules never reference an application by name, and each application's resources live in an
`app-<name>` module.

## Who owns what

| Concern | Owner | Where |
|---|---|---|
| VPC, subnets, NAT, internet gateway | Platform | `modules/vpc` |
| EKS cluster, node group, managed add-ons | Platform | `modules/eks` |
| Shared artifact registry (ECR) | Platform | `modules/ecr` |
| External Secrets Operator + store | Platform | `modules/eso` |
| AWS Load Balancer Controller | Platform | `modules/alb` |
| ExternalDNS | Platform | `modules/dns` |
| Argo CD itself | Platform | `modules/argocd` |
| CI runners | Platform | `modules/arc`, `modules/arc-runner`, `modules/infra-runner` |
| The published contract (SSM parameters) | Platform | `environments/<env>/ssm.tf` |
| An app's database, secret, hostname cert, and Argo CD Application | Application | `modules/app-<app>` |
| The app's chart, image, and objects (Deployment, Service, Ingress, HPA, PDB, ExternalSecret) | Application | the application repository |
| The app's `ApplicationSet` | Application | the application repository |

The platform root instantiates the app module with platform inputs (VPC, cluster, zone, registry,
store) and publishes the resulting values as the contract. The app's resources live in the
environment's Terraform state today; moving them to per-app roots is tracked in [`GITOPS-HUB`](../tasks.md).

See [Repository structure](../getting-started/repository-structure.md) for the trees and
[Worked example: TodoList](../onboarding/worked-example.md) for the concrete case.

## Rules

- **The application pipeline never runs `tofu`.** Infrastructure is applied by the platform pipeline
  only.
- **CI does not `helm upgrade` the application.** Argo CD owns the release (ADR-012); CI commits the
  desired digest.
- **One owner per object.** Terraform does not manage application objects; the application does not
  manage platform add-ons.
- **No application name in platform modules.** Platform modules are app-agnostic; only `app-<name>`
  modules mention an application.

See [The contract](contract.md) for the interface between the two.

!!! question "Open discussion"
    Whether an application should own its database, queue, and other app-scoped resources in its own
    repository (with the platform providing the modules) is **not decided**. See
    [App infrastructure ownership](../discovery/app-infrastructure-ownership.md).

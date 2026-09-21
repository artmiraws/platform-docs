# Ownership

The platform and its applications are separate concerns with a clean boundary. Every Kubernetes
object and every cloud resource has exactly one owner.

## Who owns what

| Concern | Owner |
|---|---|
| Clusters, node groups, VPC, NAT, subnets | Platform |
| Cluster add-ons (ALB controller, ExternalDNS, External Secrets, metrics-server, Cluster Autoscaler, ARC) | Platform |
| Argo CD itself | Platform |
| Shared artifact registry (ECR) | Platform |
| The published contract (SSM parameters) | Platform |
| Argo CD `Application` / `ApplicationSet` for an app | Application |
| The app's chart, image, and objects (Deployment, Service, Ingress, HPA, PDB, ExternalSecret) | Application |
| The app's database and secrets | Platform provisions, application consumes (today) |

## Rules

- **The application pipeline never runs `tofu`.** Infrastructure is applied by the platform pipeline
  only.
- **CI does not `helm upgrade` the application.** Argo CD owns the release (ADR-012); CI commits the
  desired digest.
- **One owner per object.** Terraform does not manage application objects; the application does not
  manage platform add-ons.
- **No application name in platform resources.** Names reflect the platform and environment.

See [The contract](contract.md) for the interface between the two.

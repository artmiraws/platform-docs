# Prerequisites

## Tools

| Tool | Why |
|---|---|
| AWS credentials (short-lived) | Provision and inspect the platform. |
| OpenTofu ≥ 1.10 | The platform is defined as code. |
| `kubectl` | Inspect clusters and Argo CD. |
| `helm` | Inspect the platform's add-on releases. |
| `docker` | Build application images locally. |

## Access

- An AWS account and region with the required service quotas.
- A Route 53 hosted zone for the base domain, and permission to create ACM certificates.
- A GitHub App (for the self-hosted CI runners) whose credentials are stored in Secrets Manager.

## Knowledge

You do not need to be a Kubernetes expert to deploy an application onto the platform. You do need to
understand containers, Helm values, and Git. The [onboarding guide](../onboarding/add-an-application.md)
assumes that.

## For platform maintainers

- The platform repository and its remote state (S3, native locking).
- The `platform-docs` build toolchain (MkDocs Material) to publish this handbook.

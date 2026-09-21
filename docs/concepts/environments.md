# Environments

An **environment** is an isolated instance of the platform where applications run. There are two:
`dev` and `prod`. Each is a separate OpenTofu root with its own state, VPC, EKS cluster, database,
secrets, IAM, and DNS name, so one can be created or destroyed without touching the other.

| | dev | prod |
|---|---|---|
| Purpose | Continuous delivery from `main`; validate an artifact | Approved releases only |
| Networking | its own VPC and subnets | its own VPC and subnets |
| Compute | EKS with a small managed node group, bounded autoscaling | same footprint, plus control-plane logging |
| Database | Aurora PostgreSQL Serverless v2 (0.5–2 ACU) | same, plus deletion protection, a final snapshot, and 14-day backups |
| Delivery | every merge to `main` (build, scan, digest, Argo CD) | a published release, digest-promoted from dev behind an approval |
| Contract | `/platform/dev/*` | `/platform/prod/*` |

**Shared:** the artifact registry (ECR) and the GitHub App are environment-independent — that is what
lets `prod` deploy the exact digest `dev` validated.

## What an environment provides

Each environment gives an application: a cluster and node pool, ingress with DNS and TLS, a secrets
store, a shared image registry, CI runners, Argo CD, and the [contract](contract.md) it reads for
wiring. Applications never read Terraform state or platform internals.

## Isolation and lifecycle

Each environment has its own state key, so destroying one never touches the other. They are
**ephemeral**: created for a validation or demo window and destroyed afterwards. The remote state
bucket and retained snapshots persist; the clusters and databases do not.

## Sizing and cost

`prod` mirrors dev's small footprint on purpose: the goal is a working promotion path, not scale.
Production-grade capacity and redundancy are future work. See [Costs](../costs.md) and the
[runbook](../operations/runbook.md) for the cost levers.

## Naming

Environments are named `dev` and `prod`. Platform resources are named for the platform and the
environment, never the application, so a cluster can host many services (ADR-013).

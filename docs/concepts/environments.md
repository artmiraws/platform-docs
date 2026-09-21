# Environments

An **environment** is an isolated instance of the platform where applications run. Today there are
two: `dev` and `prod`.

| | dev | prod |
|---|---|---|
| Purpose | Continuous delivery from `main`; validate an artifact | Approved releases only |
| Cluster | `platform-dev` (planned) | `platform-prod` (planned) |
| Worker nodes | `t3.small`, 1–3 | `t3.small`, 1–3 |
| Database | Aurora PostgreSQL Serverless v2, 0.5–2 ACU | Same, plus deletion protection and 14-day backups |
| Promotion | Every merge to `main` | A published release, digest-promoted from dev |

!!! note "Naming"
    Clusters are named for the platform and environment, never the application, so a cluster can host
    many services (ADR-013). Earlier names (`todolist-dev`, `todolist-prod`) are being replaced.

## Lifecycle

Environments are **ephemeral**: created for a validation or demo window and destroyed afterwards.
The remote state bucket and retained snapshots persist; the clusters and databases do not.

## Sizing and cost

`prod` mirrors dev's small footprint on purpose: the goal is a working promotion path, not scale.
Production-grade capacity and redundancy are future work (see the
[hardening backlog](../operations/hardening.md)). See [Costs](../costs.md).

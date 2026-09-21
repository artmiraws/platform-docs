# Roadmap

The umbrella view of what is left: what is **committed**, what needs **discovery**, and what waits
for a **trigger**. It links to the detailed sources rather than duplicating them.

## How this is organized

Every item sits in one of three horizons, and moves through a **decision funnel**:

```text
Idea ──► Discovery (timeboxed spike) ──► Decision (ADR) ──► Delivery (task) ──► Done
                    │                          │                  │
              open-discussion.md          decisions/         TASKS.yaml
```

- **Now — committed.** The *what* is decided; only execution remains. Lives in `TASKS.yaml` and the
  [hardening backlog](operations/hardening.md).
- **Discovery — a spike, then an ADR.** Options are open. A timeboxed spike compares them and produces
  a decision record; see [open discussion](decisions/open-discussion.md) for the first one.
- **Later — future / optional.** Revisit only when a documented trigger fires (scale, a requirement,
  or a cost threshold).

The rule of thumb: **decided → task; open with real options → spike → ADR; trigger-dependent →
later.** This keeps us from implementing something before we have chosen it, and from endlessly
debating something we have.

## Now — committed

| Item | Theme | Source |
|---|---|---|
| Tests + coverage, dependency scanning, IaC scanning, SAST, pinned actions | Security | HS-01…HS-04, HS-07 |
| NetworkPolicies, Pod Security Admission, DB security-group scope, split runner IAM | Security | HS-09…HS-12 |
| Single Argo CD, platform-scoped naming, ECR owned by the platform, ApplicationSet, render-time plugin | Platform / GitOps | `GITOPS-HUB` |
| Rename clusters/resources and move the contract to platform scope | Platform | `PLATFORM-RENAME` |
| Observability baseline (metrics + a few dashboards and alerts) | Observability | `OBSERVABILITY`, HS-18 |

## Discovery — spike, then an ADR

Each item is a timeboxed investigation that ends in a decision record (and, if accepted, a task).

| # | Question | Options to compare | Output |
|---|---|---|---|
| D1 | Should an application own its infrastructure? | platform-applied · app-owned root · app-declares/platform-applies · Kubernetes-native | ADR superseding parts of ADR-001/013 |
| D2 | Kubernetes-native cloud resources? | Crossplane · AWS Controllers for Kubernetes (ACK) · keep Terraform | ADR |
| D3 | IaC language? | OpenTofu (HCL) · Pulumi (general-purpose languages) | ADR |
| D4 | GitOps engine (revisit)? | Argo CD (ADR-017) · Flux CD | Revisit ADR-017 |
| D5 | Observability stack? | kube-prometheus-stack · managed (CloudWatch/AMP) · Grafana Cloud | ADR + `OBSERVABILITY` |
| D6 | Progressive delivery? | Argo Rollouts · mesh-based (gated on D5) | ADR |
| D7 | Policy / admission engine? | Kyverno · Gatekeeper · OPA | ADR (unblocks image verification) |
| D8 | Chart distribution and promotion? | OCI chart + PR-based promotion (ADR-014 target) · current digest commit | Implementation of ADR-014 |
| D9 | Contract delivery? | Render-time CMP plugin (ADR-015 target) · Terraform injection (interim) | Implementation of ADR-015 |
| D10 | Single-Argo CD reachability? | VPC peering · hub / Transit Gateway | ADR (part of `GITOPS-HUB`) |

**Why these need discovery, not execution:** each has more than one defensible answer whose trade-offs
depend on scale and requirements we do not have yet (for example, Crossplane only pays off with many
resources and teams; Pulumi only pays off with developers who prefer general-purpose languages). A
spike is cheaper than committing.

**Flux CD is already decided** (ADR-017 chose Argo CD); D4 is a *revisit*, not a fresh evaluation —
only if the central-server/pull-native trade-off changes.

## Later — future / optional (revisit when a trigger fires)

| Item | Trigger to revisit | Source |
|---|---|---|
| Move third-party add-ons to Argo CD (app-of-apps) | wanting one reconciliation model for the cluster | `GITOPS-ADDONS`, ADR-009 |
| Karpenter + Spot, pod-density (prefix delegation), scheduled scaling | cost or capacity pressure | HS-26…HS-28 |
| Production-like staging, load and migration testing | before any performance or migration claim | HS-23, HS-24 |
| WAF, VPC endpoints, customer-managed KMS keys, audit logs | exposure, egress cost, or a compliance requirement | HS-14…HS-17 |
| SBOM, image signing, verify-at-admission | after D7 (admission engine) | HS-05, HS-06 |
| Aurora reader / failover, secret rotation, restore drill | an availability or recovery requirement | HS-19…HS-21 |
| Service mesh | multiple services needing mTLS, traffic splitting, or L7 telemetry | ADR-018 |
| Multi-region, hub cluster | more than a few clusters or a latency requirement | ADR-013, ADR-016 |
| Developer portal (Backstage) / service catalog | onboarding volume that a template cannot handle | — |

## Where things live

| Artifact | Purpose |
|---|---|
| `TASKS.yaml` | the execution board (open / in progress / done) |
| [hardening backlog](operations/hardening.md) | security, reliability, and cost items (HS-xx) |
| [decisions](decisions/index.md) | accepted decisions (ADR-xxx) |
| [open discussion](decisions/open-discussion.md) | options not yet decided |
| this page | the umbrella: horizon, theme, and status of every item |

## Related

- [Decisions](decisions/index.md) · [Hardening backlog](operations/hardening.md) ·
  [Open discussion](decisions/open-discussion.md) · [Costs](costs.md)

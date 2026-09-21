# Backlog

**Status:** Proposed — none of the items below are implemented. This document is the deliverable for
the `FUTURE-HARDENING` task: it records improvements as **individually approvable tasks** so each can
be planned, applied, and reviewed on its own. The `dev` environment is a short-lived proof of concept;
these are the deliberate next steps before anything resembling production traffic.

**Principle:** the current Trivy image scan is one control, not a complete security program.

## How to use this backlog
- Each row is a candidate task with its own PR and, where it touches AWS, its own authorized `apply`.
- Effort: **S** (hours), **M** (a day or two), **L** (multi-day).
- Priority: **P1** first; **P2** when the cost or requirement justifies it.
- "Current" describes what exists today so a reviewer can see the delta.

## 1. Quality gates and supply chain

| ID | Item | Current | Proposed | Effort | Pri |
|---|---|---|---|---|---|
| HS-01 | Application tests + coverage policy | smoke test after deploy; no unit/integration suite | add a pytest suite, run it in CI, enforce a coverage floor | M | P1 |
| HS-02 | Dependency scanning | none for `pip`/Actions | Dependabot or Renovate for Python, Docker, and GitHub Actions | S | P1 |
| HS-03 | IaC scanning | `tofu fmt`/`validate` only | run `trivy config` (or Checkov/tfsec) over `platform/` on PR, fail on high findings | S | P1 |
| HS-04 | SAST | none | CodeQL or Semgrep on the app on PR | S | P1 |
| HS-05 | SBOM + signing + provenance | none | generate an SBOM (Syft) and sign the image (cosign) with SLSA provenance | M | P2 |
| HS-06 | Verify signatures at admission | none | admit only signed images (Kyverno or a validating webhook) | M | P2 |
| HS-07 | Pin CI actions by SHA | tags (`@v4`) | pin third-party actions to full commit SHAs; update via Dependabot | S | P2 |
| HS-08 | Image scan depth | Trivy, fail on CRITICAL | add a fixable-HIGH policy, an ignore file with expiry, and scheduled scans | S | P2 |

## 2. Cluster and network hardening

| ID | Item | Current | Proposed | Effort | Pri |
|---|---|---|---|---|---|
| HS-09 | NetworkPolicies | none (flat cluster network) | default-deny per namespace + explicit allows (app to Aurora, DNS egress, runner egress) | M | P1 |
| HS-10 | Pod Security Admission | unset | label namespaces `restricted`/`baseline`; make the app chart pass `restricted` | M | P1 |
| HS-11 | Database security group | allows PostgreSQL from the whole VPC CIDR | scope to the node/cluster security group only | S | P1 |
| HS-12 | CI runner IAM | `arc-infra-runner` has `AdministratorAccess` (documented dev compromise) | split least-privilege roles per job; drop admin once the pipeline is stable | M | P1 |
| HS-13 | IRSA review | roles scoped to specific ARNs | periodic review; add condition keys (source account, VPC) | S | P2 |
| HS-14 | WAF | none | AWS WAF managed rules + rate limiting on the ALB | M | P2 |
| HS-15 | VPC endpoints | AWS traffic via NAT | S3 gateway endpoint and ECR/Secrets Manager/SSM interface endpoints to cut egress and exposure | M | P2 |
| HS-16 | KMS customer-managed keys | SSE-S3 for state; AWS-managed keys elsewhere | CMKs for state, secrets, and EBS, with key policies and rotation | M | P2 |
| HS-17 | Control-plane audit logs | EKS logging at defaults | enable api/audit/authenticator logs to CloudWatch with retention | S | P2 |

## 3. Reliability and operations

| ID | Item | Current | Proposed | Effort | Pri |
|---|---|---|---|---|---|
| HS-18 | Observability + alerting | metrics-server; ad-hoc `kubectl top` | metrics/logs pipeline (CloudWatch or Prometheus/Grafana) with alerts on ALB 5xx, HPA/CA saturation, Aurora ACU/connections, and pod restarts | L | P1 |
| HS-19 | Backup/restore drill | 7-day backups + PITR configured | perform and document a real restore into a scratch cluster | M | P1 |
| HS-20 | Aurora failover | single writer, no reader | add a reader and test failover, or document why dev does not need it | M | P2 |
| HS-21 | Secret rotation | ESO refresh + pod restart documented as a limitation | automate rotation (Secrets Manager rotation + restart hook) or accept and document | M | P2 |
| HS-22 | Disruption behaviour | PDB + HPA present | verify PDBs during node drain and rolling updates under load; record results | S | P2 |

## 4. Production-like staging and performance

| ID | Item | Current | Proposed | Effort | Pri |
|---|---|---|---|---|---|
| HS-23 | Staging environment | single `dev` | a production-like staging root (independent state, DB, secrets) for load, migration, resilience, and release testing | L | P2 |
| HS-24 | Load and migration testing | none | k6/Locust load test; test schema migrations with rollback and a maintenance window | M | P2 |
| HS-25 | Release verification | smoke test after deploy | expand post-deploy verification and add a documented rollback drill | M | P2 |

## 5. Cost and scale

| ID | Item | Current | Proposed | Effort | Pri |
|---|---|---|---|---|---|
| HS-26 | Karpenter + Spot | managed node group + Cluster Autoscaler | Karpenter with a Spot/On-Demand mix (larger change; interacts with GITOPS) | L | P2 |
| HS-27 | Pod density | `t3.small` caps at ~11 pods | prefix delegation to raise pod density and run fewer nodes | M | P2 |
| HS-28 | Scheduled scaling | on only during a validation window | schedule the stack for known demo windows; revisit Aurora auto-pause | M | P2 |

## Sequencing
1. **P1 quality gates** (HS-01…HS-04, HS-07): cheap, app-side, no AWS apply — do first.
2. **P1 cluster/network** (HS-09…HS-12): one apply per item; verify in `dev`.
3. **P1 operations** (HS-18, HS-19): alerting and a real restore drill.
4. P2 items as requirements justify; staging (HS-23) before making any performance claim.

## Acceptance
- Improvements are split into individually approvable tasks (this document).
- A basic image scan is explicitly **not** treated as a complete security program (see section 1).

# Cost model

Planning estimate for the `dev` and `prod` EKS environments in `us-east-1`.

> **Indicative on-demand rates for planning, not a quote.** Confirm current prices and the selected
> instance/engine versions with the AWS Pricing Calculator and Cost Explorer before apply. Budget
> alerts are not spending caps.

## Assumptions

- Region `us-east-1`, on-demand pricing, no Savings Plans/Reservations.
- Two `t3.small` worker nodes (2 vCPU, 2 GiB), min 1 / max 2 (see ADR-003).
- Single NAT gateway (documented dev compromise).
- Aurora PostgreSQL Serverless v2, one writer, min 0.5 ACU / max 2 ACU.
- Small data volumes and low traffic; 2 GB of ECR images; 1 GB/month of logs.

## Unit rates (indicative, us-east-1)

| Service | Rate | Notes |
|---|---|---|
| EKS control plane | US$0.10/hour | Charged whenever the cluster exists |
| EC2 `t3.small` | US$0.0232/hour | Chosen dev node |
| EC2 `t3.medium` | US$0.0499/hour | Documented fallback |
| EC2 `t4g.small` (ARM) | US$0.0212/hour | Only with an `arm64` image |
| EBS `gp3` | US$0.08/GB-month | Node volume + PVC |
| NAT gateway | US$0.045/hour + US$0.045/GB | Single dev NAT |
| Public IPv4 | US$0.005/hour | NAT and ALB addresses |
| ALB | US$0.0225/hour + LCU | Load balancer hours + capacity units |
| Aurora Serverless v2 | US$0.12/ACU-hour | 0.5 ACU minimum |
| Aurora storage | US$0.10/GB-month | Plus I/O requests |
| ECR storage | US$0.10/GB-month | Persists across teardown |
| CloudWatch Logs | US$0.50/GB ingested | Retention storage is extra |
| Data transfer out | Free to 100 GB/month, then ~US$0.09/GB | |

## Scenario A — ephemeral dev (20 active hours/month)

| Component | Estimate |
|---|---|
| EKS control plane (20 h × 0.10) | US$2.00 |
| EC2 nodes (2 × 20 h × 0.0232) | US$0.93 |
| EBS (60 GB prorated) | US$0.13 |
| NAT (20 h + 5 GB) | US$1.13 |
| Public IPv4 (2 × 20 h) | US$0.20 |
| ALB (20 h + LCU) | US$0.61 |
| Aurora compute (0.5 ACU × 20 h) | US$1.20 |
| Aurora storage + I/O | US$0.05 |
| ECR storage (2 GB) | US$0.20 |
| Logs + data transfer | US$0.60 |
| **Total** | **≈ US$7.0** |

Variable cost is roughly **US$0.33 per active hour**. ECR storage remains between windows.

## Scenario B — always-on dev (730 hours/month)

| Component | Estimate |
|---|---|
| EKS control plane | US$73.00 |
| EC2 nodes (2 × `t3.small`) | US$33.87 |
| EBS | US$4.80 |
| NAT | US$33.75 |
| Public IPv4 | US$7.30 |
| ALB | US$22.27 |
| Aurora compute (0.5 ACU) | US$43.80 |
| Aurora storage + I/O | US$1.50 |
| ECR + logs + transfer | US$2.70 |
| **Total** | **≈ US$223/month** |

An always-on dev stack is about **4.5× the US$50 budget**, and the EKS control plane alone is
~US$73/month. This is why dev is created only for validation/demo windows and destroyed afterward.
Node size is a minor cost factor: `t3.medium` instead of `t3.small` adds only ~US$19/month
always-on, or ~US$0.53 for a 20-hour window.

## Prod (second environment)

Prod mirrors dev's footprint on purpose (ADR-011), so while both exist the variable cost roughly
**doubles** — about **US$0.33 per active hour each** (≈US$14 for a 20-hour window with both running).
Prod adds EKS control-plane logging (CloudWatch ingestion) and 14-day backups. Like dev, prod is
destroyed after the demo window; keeping both always-on would be roughly **US$446/month**.


## Budget

- A monthly cost budget of **US$50** is planned, with alerts at **50% (US$25)**, **80% (US$40)**,
  and **100% (US$50)**, plus a **forecasted** alert. The first two AWS Budgets are free; additional
  budgets cost a small daily amount.
- Keeping usage under roughly **100 active hours/month** (≈US$31 variable) leaves margin for data,
  snapshots, and price changes.
- Scaling nodes to zero does **not** stop control-plane, storage, ALB, NAT, or Aurora charges; the
  stack must be destroyed to stop them.
- VPC endpoints (ECR, S3, CloudWatch Logs) are an option if NAT data charges grow, weighed against
  their own hourly cost.

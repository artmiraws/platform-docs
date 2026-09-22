# Architecture

## Summary

- **AWS `us-east-1`:** one VPC per environment, an EKS cluster per environment, Aurora PostgreSQL
  Serverless v2, ECR, Secrets Manager, Route 53, ACM, and a budget.
- **Cluster add-ons:** External Secrets Operator, AWS Load Balancer Controller, ExternalDNS,
  metrics-server, Cluster Autoscaler, Argo CD, and self-hosted CI runners (ARC).
- **Delivery (GitOps):** GitHub Actions → self-hosted runner (IRSA, in-VPC) → ECR (by digest) →
  commit the digest to Git → Argo CD reconciles.
- **Access:** Route 53 → ALB (ACM TLS) → Ingress → Service → pods → Aurora.
- **Secrets:** Secrets Manager → External Secrets Operator → Kubernetes Secret → pods.

<style>
  .user-access-flow-light {
    display: block;
  }

  .user-access-flow-dark {
    display: none;
  }

  [data-md-color-scheme="slate"] .user-access-flow-light {
    display: none;
  }

  [data-md-color-scheme="slate"] .user-access-flow-dark {
    display: block;
  }
</style>

<img class="user-access-flow-light" src="../../assets/user-access-flow-light.png" alt="User access flow diagram in light mode" width="100%">
<img class="user-access-flow-dark" src="../../assets/user-access-flow-dark.png" alt="User access flow diagram in dark mode" width="100%">

See the [runbook](../operations/runbook.md) for operations and the
[decisions](../decisions/index.md) for rationale.

## Environments

See [Environments](../concepts/environments.md). Ownership is in [Ownership](../concepts/ownership.md).

## Trust boundaries

- CI runners run inside the VPC and use IRSA; there are no long-lived AWS keys.
- EKS API endpoints are private; operators opt in with explicit CIDRs.
- An application reads only its own secrets and the published contract.

## Service mesh

None. A single service does not justify the control plane, per-pod proxies, and operational cost of a
mesh: TLS terminates at the ALB, `NetworkPolicy` gives coarse isolation, and Argo Rollouts covers
canary. The rationale and the conditions that would change it are in
[ADR-018](../decisions/index.md#adr-018-no-service-mesh).

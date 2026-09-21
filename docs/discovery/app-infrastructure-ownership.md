# App infrastructure ownership

**Status:** Open — not decided. This page records the question, the models, and a recommendation so the
team can decide before changing the Terraform. It is the discussion behind ADR-013's open question
("does the platform provision an application's database and secrets, or does the application own
them?").

## The question

Today the platform root instantiates the app-specific resources through
[`modules/app-todolist`](../getting-started/repository-structure.md) — the database, the application
secret, the hostname certificate, and the Argo CD Application all live in the platform repository's
state and are applied by the platform pipeline.

Is that right? Or should an application **own its infrastructure** — its database, queue, bucket,
secret, and certificate — in its own repository, with the platform providing the reusable modules?

## Three things that are usually conflated

1. **The module** — a reusable, versioned building block (`vpc`, `rds`, `sqs`, `iam-role`). This is a
   **platform product**.
2. **The instance** — "the TodoList database", "the orders queue". This belongs to whoever **owns the
   lifecycle**.
3. **The apply** — who runs `tofu apply` and holds the credentials.

The decision is about (2) and (3); (1) is settled: the platform provides the modules.

## Classify by lifecycle, not by technology

| Resource | Lifecycle matches | Owner |
|---|---|---|
| VPC, subnets, cluster, node groups | the platform (many apps) | Platform |
| Ingress controller, ExternalDNS, ESO, Argo CD, ARC | the platform | Platform |
| ECR registry, DNS zone, secrets store, CI roles | the platform | Platform |
| **Aurora database, SQS queue, S3 bucket, app secret, hostname certificate** | **one application** | **Application** |
| The app's Helm chart / `ApplicationSet` | the application | Application |

Rule of thumb: **shared and must-exist-first → platform; app-scoped and dies with the app → the
application.** The platform owns the *interface* (modules, contract, guardrails), not the instances.

## Worked case: an SQS queue

A queue is app-scoped: only one application produces and consumes it, and it should be destroyed with
that application. So:

- The **platform** should provide an `sqs` module (encryption, dead-letter queue, tags, a
  least-privilege policy), the **IRSA role** the app uses, and the contract entry for the queue URL.
- The **application** should own the **queue instance** and the code that uses it.

Creating the queue in the platform repository means every queue tweak becomes a platform pull request
serialized behind the platform pipeline. The platform team becomes the bottleneck, and the
application's repository no longer describes the application.

## Four ways to let an application own its infrastructure

| Model | App declares infra? | Who applies | Credentials | Trade-off |
|---|---|---|---|---|
| **A. Platform root applies the app module** (today) | No — the platform repo has `app-<name>` | Platform pipeline | Platform only | Simple and ordered, but the platform is the bottleneck and owns app config |
| **B. App repo owns infra + its own pipeline** | Yes (`infra/` in the app repo) | App pipeline | App-scoped AWS role | Truly self-contained; needs a scoped role, guardrails, and the contract |
| **C. App declares, platform applies** (Atlantis/Spacelift style) | Yes | Platform pipeline reads the app's `infra/` | Platform only | App authors, platform holds credentials and policy; more machinery |
| **D. Kubernetes-native** (Crossplane/ACK) | Yes — a `Queue`/`Bucket` CR in the chart | Argo CD (no `tofu`) | Controller IRSA | One pipeline for app + infra; the platform runs the controllers and IAM |

Model **D** is the most self-contained answer for a GitOps platform: the app's chart carries its
`Queue`, `Database`, and so on, and the platform's controllers reconcile them. One repository, one
pipeline, no second Terraform state. The cost is operating Crossplane or ACK and being comfortable
with CRDs for cloud resources.

## Recommendation

- **Platform owns**: foundations, the modules, the contract, and the per-application CI role. It should
  **not** instantiate application resources.
- **Application owns**: its database, queue, bucket, secret, and certificate, in its own root, applied
  by **its** pipeline with a **scoped role** (model B) — or declared as CRs (model D).
- Keep the ordering guarantee by having the app root **read the platform contract** (SSM or remote
  state), so the platform is still applied first without owning the app's resources.

For this project the next step would be **model B**: give each application its own root (its own state
key) that reads the platform contract, while the platform grants a scoped IRSA role and publishes the
modules. Model D is the more ambitious rewrite and a candidate for the future.

## What it takes (and the honest risks)

- **Module distribution**: a versioned interface (Git tag, Terraform registry, or OCI) so apps can pin
  `sqs = { source = "platform/sqs", version = "1.2.0" }`.
- **Scoped credentials**: an IRSA/OIDC role per application that can create only the resource types it
  needs. This is the hard part — IAM is coarse.
- **Guardrails**: the modules encode encryption, backups, tags, naming, and least privilege, so
  self-service does not mean every team reinvents the database.
- **Lifecycle safety**: if the application owns its database, its pipeline can destroy it. Safeguards
  (deletion protection, snapshot policies, and platform-owned "protected" resources) are required.
- **Cost and visibility**: app-owned resources must still be tagged and attributable.

## Related

- [ADR-001](../decisions/index.md#adr-001-infrastructure-repository-placement-and-ownership) (repository placement)
- [ADR-013](../decisions/index.md#adr-013-platform-vs-application-separation-one-argo-cd-and-the-platform-contract)
  (platform vs application separation and its open questions)
- [Ownership](../concepts/ownership.md) and
  [Repository structure](../getting-started/repository-structure.md)
- Tasks [`GITOPS-HUB`](../tasks.md) and [`PLATFORM-RENAME`](../tasks.md)

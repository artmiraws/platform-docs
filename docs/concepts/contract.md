# The contract

The platform publishes a per-environment **contract** in AWS SSM Parameter Store. Applications read
the contract; they never read Terraform state or platform internals.

## Why a contract

It decouples the two repositories. The platform can change how a value is produced without changing
the interface an application depends on. The contract is the only coupling point, and it is versioned
and documented here.

## Shape

Split by ownership: **environment facts** are environment-scoped, **application facts** are namespaced
under `apps/<app>`.

```text
# environment facts (shared by every application)
/platform/<env>/cluster_name
/platform/<env>/region
/platform/<env>/ecr_registry
/platform/<env>/ingress_class
/platform/<env>/external_secrets_store

# application facts (namespaced, so applications cannot collide)
/platform/<env>/apps/<app>/image_repository
/platform/<env>/apps/<app>/runner_scale_set
/platform/<env>/apps/<app>/hostname
/platform/<env>/apps/<app>/certificate_arn
/platform/<env>/apps/<app>/db_host
/platform/<env>/apps/<app>/db_port
/platform/<env>/apps/<app>/db_name
/platform/<env>/apps/<app>/db_secret_arn
/platform/<env>/apps/<app>/app_secret_arn
```

A runner's read policy is scoped to the environment facts plus its own application's namespace.

## Worked example (dev)

```text
/platform/dev/cluster_name                        todolist-dev
/platform/dev/region                              us-east-1
/platform/dev/ecr_registry                        <account>.dkr.ecr.us-east-1.amazonaws.com
/platform/dev/ingress_class                       alb
/platform/dev/external_secrets_store              aws-secrets-manager
/platform/dev/apps/todolist/image_repository      <account>.dkr.ecr.us-east-1.amazonaws.com/todolist
/platform/dev/apps/todolist/runner_scale_set      arc-runner-set
/platform/dev/apps/todolist/hostname              dev.todolist.<base_domain>
/platform/dev/apps/todolist/db_host               todolist-dev.cluster-<id>.us-east-1.rds.amazonaws.com
/platform/dev/apps/todolist/db_port               5432
/platform/dev/apps/todolist/db_name               todolist
/platform/dev/apps/platform-docs/hostname         docs.<base_domain>
/platform/dev/apps/platform-docs/runner_scale_set arc-docs-runner
```

See [Worked example: TodoList](../onboarding/worked-example.md) for the full flow.

## How Argo CD consumes it

Argo CD cannot read SSM natively, so applications resolve the contract at **render time with a
config-management plugin** (ADR-015): a CMP in the repo-server reads the contract and feeds it to
Helm. The application owns its `ApplicationSet`; the platform stays application-agnostic, so adding an
application needs no platform change.

The current single application still receives Terraform-injected values as an **interim** — a stopgap,
not the target.

## Rules

- **No secrets in the contract.** Secrets live in Secrets Manager and reach the cluster through the
  External Secrets Operator. SSM holds non-secret wiring only.
- **No account IDs or ARNs in Git.** The contract is injected, not committed.

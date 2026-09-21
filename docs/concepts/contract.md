# The contract

The platform publishes a per-environment **contract** in AWS SSM Parameter Store. Applications read
the contract; they never read Terraform state or platform internals.

## Why a contract

It decouples the two repositories. The platform can change how a value is produced without changing
the interface an application depends on. The contract is the only coupling point, and it is versioned
and documented here.

## Current shape (dev)

Today the parameters are all app-scoped under `/todolist/<env>/`, because the platform provisions the
single application's database and secrets. The keys the TodoList app reads:

```text
/todolist/dev/cluster_name
/todolist/dev/ecr_repository_url
/todolist/dev/db_host
/todolist/dev/db_port
/todolist/dev/db_name
/todolist/dev/db_secret_arn
/todolist/dev/app_secret_arn
/todolist/dev/app_hostname
/todolist/dev/ingress_certificate_arn
/todolist/dev/external_secrets_store_name
/todolist/dev/runner_scale_set_name
```

See [Worked example: TodoList](../onboarding/worked-example.md) for the actual values.

## Shape (proposed)

Split by ownership: **environment facts** are environment-scoped, **application facts** are
namespaced under `apps/<app>`.

```
# environment facts (shared by every application)
/platform/<env>/cluster_name
/platform/<env>/region
/platform/<env>/ecr_registry
/platform/<env>/ingress_class
/platform/<env>/external_secrets_store
/platform/<env>/runner_scale_set

# application facts (namespaced, so applications cannot collide)
/platform/<env>/apps/<app>/hostname
/platform/<env>/apps/<app>/certificate_arn
/platform/<env>/apps/<app>/db_host
/platform/<env>/apps/<app>/db_port
/platform/<env>/apps/<app>/db_name
/platform/<env>/apps/<app>/db_secret_arn
/platform/<env>/apps/<app>/app_secret_arn
```

A runner's read policy is scoped to the environment facts plus its own application's namespace.

!!! warning "Not final"
    Today the parameters are **all** app-scoped at `/todolist/<env>/...`, because the platform
    provisions the application's database and secrets. Moving to the shape above is part of
    `PLATFORM-RENAME` / `GITOPS-HUB` (ADR-013), and it forces a question the platform must answer:
    does the platform provision an application's database and secrets, or does the application own
    them and consume only platform facts?

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

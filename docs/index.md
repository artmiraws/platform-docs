# Platform Handbook

The single place for **platform** documentation: how the platform is planned, built, and operated,
and how to add an application to it.

Application-specific documentation lives with the application (for example, the TodoList app keeps
its local-development and chart docs in its own repository).

!!! info "Status"
    The platform is a work in progress. The design and its open questions are recorded in
    [Decisions](decisions/index.md); the roadmap is tracked in the `GITOPS-HUB`, `PLATFORM-RENAME`,
    `PLATFORM-DOCS`, and `OBSERVABILITY` tasks.

## Start here

| I want to... | Go to |
|---|---|
| Understand what the platform is | [Getting started: overview](getting-started/overview.md) |
| Know what I need before I start | [Getting started: prerequisites](getting-started/prerequisites.md) |
| See how the repositories are laid out | [Getting started: repository structure](getting-started/repository-structure.md) |
| Understand dev vs prod | [Concepts: environments](concepts/environments.md) |
| Know who owns what | [Concepts: ownership](concepts/ownership.md) |
| Consume platform values in my app | [Concepts: the contract](concepts/contract.md) |
| See a full example end to end | [Onboarding: worked example (TodoList)](onboarding/worked-example.md) |
| Deploy my application | [Onboarding: add an application](onboarding/add-an-application.md) |
| Operate or troubleshoot the platform | [Operations: runbook](operations/runbook.md) |
| See why things are the way they are | [Decisions](decisions/index.md) |

## What belongs where

- **Here:** platform concepts, architecture, decisions, runbooks, costs, and the application
  onboarding guide.
- **In the platform repository:** code-adjacent notes (module READMEs).
- **In the application repository:** everything specific to that application.

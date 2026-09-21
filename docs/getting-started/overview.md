# Overview

The platform is the shared AWS foundation that applications deploy onto, so that adding a new
application does not mean rebuilding a cluster, networking, TLS, secrets, and delivery.

## What the platform provides

Per-environment clusters with networking, TLS, secrets, a shared artifact registry, GitOps delivery,
and a contract that applications consume. The components and topology are in
[Architecture](../architecture/overview.md); the environment model is in
[Environments](../concepts/environments.md).

## How an application fits

An application provides a container image and a Helm chart, plus an `ApplicationSet` that describes
its per-environment deployments. Its pipeline builds, scans, and pushes the image, then commits the
desired digest; Argo CD reconciles the cluster. See
[Add an application](../onboarding/add-an-application.md).

## Design principles

- **One owner per object.** The platform owns platform objects, the application owns its own, Argo CD
  owns the application release, and nothing overlaps (ADR-001, ADR-009, ADR-012).
- **Digest, not tags.** Deployments pin an immutable image digest.
- **Pull configuration, don't hard-code it.** Applications read the published contract and never read
  platform internals.
- **Ephemeral by default.** Environments are created for a window and destroyed afterwards.

## Current state and direction

The first increment runs one Argo CD per cluster and names clusters after the application. The
[decisions](../decisions/index.md) record the move to a single Argo CD, platform-scoped naming, and a
platform-owned registry (ADR-013).

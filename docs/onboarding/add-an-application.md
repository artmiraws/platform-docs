# Add an application

The end-to-end guide for deploying an application onto the platform. It assumes the platform is
already provisioned (see [Getting started](../getting-started/overview.md)).

## What you provide

- A container image build (a `Dockerfile`).
- A Helm chart for your Kubernetes objects.
- An `ApplicationSet` that describes your per-environment deployments.
- A pipeline that builds, scans, pushes, and commits the desired digest.

## What the platform provides

- The cluster, ingress, DNS, TLS, and the secrets store.
- The shared ECR registry.
- Argo CD, which reconciles your `ApplicationSet`.
- The published [contract](../concepts/contract.md) your pipeline reads for wiring.

## Steps

### 1. Validate locally first

Before touching the platform, run your chart on a local k3d cluster: one chart, values per
environment, the image imported locally. This catches chart, probe, and configuration errors in
seconds instead of in a cloud apply, and it is how you iterate. See the TodoList app's
[local guide](https://github.com/artmiraws/todolist-app/blob/main/docs/local-kubernetes.md) and the
[worked example](worked-example.md).

### 2. Read the contract

Read non-secret wiring from SSM (`/platform/<env>/...`, see [The contract](../concepts/contract.md)).
Do not hard-code account IDs, ARNs, or hostnames.

### 3. Add your chart

Keep one chart for every environment; differences live only in values. Reference the image by
**digest**, never a mutable tag.

### 4. Write an ApplicationSet

The `ApplicationSet` generates one Argo CD `Application` per environment. See
[ApplicationSet](applicationset.md).

### 5. Wire the pipeline

On merge: build → scan → push → commit the digest → wait for Argo CD → smoke test. Promotion to prod
is a separate, approval-gated step that promotes the dev-validated digest. See [Pipeline](pipeline.md).

### 6. Add your secrets

Store secrets in Secrets Manager and sync them with an `ExternalSecret` referencing the platform's
`ClusterSecretStore`. Never commit secrets.

## Checklist

- [ ] Validated locally before deploying to the platform.
- [ ] Chart pins the image by digest.
- [ ] `ApplicationSet` generates the per-environment Applications.
- [ ] Pipeline reads the contract; no account IDs/ARNs/hostnames in Git.
- [ ] Secrets come from Secrets Manager via ESO.
- [ ] Smoke test runs after reconciliation.
- [ ] Application docs live in your repository; platform docs live here.

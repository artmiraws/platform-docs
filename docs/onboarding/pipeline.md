# Pipeline

Your application's workflows. This page is the concrete version; the model behind it (trunk-based,
two versioned artifacts, promotion by pull request) is in
[Architecture → GitOps](../architecture/gitops.md).

An application has two workflows: a **dev deploy** on merge, and an approval-gated **promotion** to
prod. Neither runs `helm upgrade`; Argo CD reconciles.

!!! warning "Current vs target"
    This page describes the **ADR-014 target**: per-environment `envs/<env>/values.yaml`, an OCI
    chart, and promotion as a pull request. Today's **interim** is simpler — both environments render
    the chart from `main`, the digest lives in `charts/todolist/gitops/<env>.yaml`, and the promotion
    workflow commits the digest directly once the `prod` environment reviewer approves. `GITOPS-HUB`
    closes the gap.

## Runner

Both jobs run on self-hosted ARC runners inside the environment's VPC and use **IRSA** (no
long-lived AWS keys). The runner is created by the platform.

## Dev deploy (on merge to `main`)

1. **Build** the image.
2. **Scan** (for example Trivy); fail on CRITICAL.
3. **Push** to ECR and capture the digest.
4. **Commit** the digest to `envs/dev/values.yaml`.
5. **Wait** for the Argo CD Application to reach `Synced` / `Healthy`.
6. **Smoke test** over HTTPS.

A `concurrency` group serializes deploys. The digest commit does not re-trigger the workflow
(`GITHUB_TOKEN` pushes do not trigger runs, and the workflow ignores the env-config path).

## Release

On a merge to `main`, release-please opens or updates a release PR; merging it publishes `vX.Y.Z`.
The release workflow then packages the chart as `X.Y.Z` and pushes it to the OCI registry.

## Promotion (on a published release)

- The promotion workflow opens a **pull request** updating `envs/prod/values.yaml` with the released
  **chart version** and the **digest dev already validated** — no rebuild.
- Reviewing and merging the PR is the approval; Argo CD then reconciles prod.
- **Rollback:** revert the PR (or open a new one) with the previous chart version and digest.

## Configuration

- Each environment pins two values: the **image digest** and the **chart version**.
- All other wiring is injected by the platform (ADR-012).
- Secrets live in Secrets Manager and are synced by the External Secrets Operator.

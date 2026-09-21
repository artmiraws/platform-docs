# Worked example: TodoList

The TodoList application is the concrete example of everything in this handbook. This page follows it
end to end: what the platform provides, what the platform provisions for it, what it owns itself, and
how a change reaches the browser.

## 1. What the platform provides

From `platform/environments/<env>/`, the platform modules give TodoList:

- a VPC, an EKS cluster, and a managed node group (`modules/vpc`, `modules/eks`);
- the shared image registry `ECR` (`modules/ecr`);
- External Secrets Operator and the `aws-secrets-manager` store (`modules/eso`);
- the AWS Load Balancer Controller and ExternalDNS (`modules/alb`, `modules/dns`);
- Argo CD and the ability to register an Application (`modules/argocd`, `modules/argocd-app`);
- a self-hosted CI runner registered to the app repository (`modules/arc`);
- the published contract in SSM.

None of these name the application.

## 2. What the platform provisions for TodoList

The app-specific resources live in `platform/modules/app-todolist/`, instantiated by the environment
root with the platform's outputs:

| Resource | Module | Detail |
|---|---|---|
| Aurora PostgreSQL Serverless v2 | `modules/rds` | one writer, 0.5–2 ACU, private subnets |
| Application secret | `modules/app-secrets` | `todolist-<env>/app` in Secrets Manager |
| Hostname certificate | `modules/acm` | `dev.todolist.<base_domain>` (prod: `prod.todolist.<base_domain>`) |
| Argo CD Application | `modules/argocd-app` | renders `charts/todolist` from the app repo |

The module then publishes the values the app needs (the contract) and injects the non-secret wiring
into the Argo CD Application.

## 3. What the contract looks like

After an apply, TodoList reads these SSM parameters (see [The contract](../concepts/contract.md)):

```text
/platform/dev/cluster_name                   todolist-dev
/platform/dev/region                         us-east-1
/platform/dev/ecr_registry                   <account>.dkr.ecr.us-east-1.amazonaws.com
/platform/dev/external_secrets_store         aws-secrets-manager
/platform/dev/apps/todolist/image_repository <account>.dkr.ecr.us-east-1.amazonaws.com/todolist
/platform/dev/apps/todolist/runner_scale_set arc-runner-set
/platform/dev/apps/todolist/hostname         dev.todolist.<base_domain>
/platform/dev/apps/todolist/db_host          todolist-dev.cluster-<id>.us-east-1.rds.amazonaws.com
/platform/dev/apps/todolist/db_port          5432
/platform/dev/apps/todolist/db_name          todolist
/platform/dev/apps/todolist/db_secret_arn    arn:aws:secretsmanager:...:secret:rds!cluster-...
/platform/dev/apps/todolist/app_secret_arn   arn:aws:secretsmanager:...:secret:todolist-dev/app-...
/platform/dev/apps/todolist/certificate_arn  arn:aws:acm:...:certificate/...
```

The app pipeline reads the hostname and the runner from here; secrets stay in Secrets Manager.

## 4. What TodoList owns

In `todolist-app/`:

- `app.py`, `Dockerfile`, `requirements.txt` — the image;
- `charts/todolist/` — the single Helm chart (`values.yaml` for cloud, `values-local.yaml` for k3d,
  and `gitops/<env>.yaml` for the desired image digest);
- `.github/workflows/deploy-dev.yml` — build, Trivy scan, ECR push by digest, commit the digest,
  wait for Argo CD, smoke test;
- `.github/workflows/promote-prod.yml` — promote the digest dev already validated;
- `docs/` — the app's own how-to guides.

The chart's objects (Deployment, Service, Ingress, HPA, PDB, CronJob, ExternalSecret) are owned by the
application; the platform does not manage them.

## 5. How a change reaches the browser

1. Merge to `main` in `todolist-app`.
2. The `Deploy dev` workflow builds the image and scans it (fails on CRITICAL).
3. It pushes to ECR and records the **digest**, then commits it to
   `charts/todolist/gitops/dev.yaml`.
4. Argo CD renders `charts/todolist` (chart source on `main`) plus that digest and the wiring injected
   by `modules/app-todolist`, then reconciles the cluster.
5. The workflow waits for `Synced`/`Healthy` and smoke-tests `https://dev.todolist.<base_domain>/healthz`.

## 6. Promotion to prod

1. release-please opens a release PR; merging it publishes `vX.Y.Z`.
2. The chained `Promote prod` job runs on the prod runner behind the `prod` environment approval.
3. It copies the **digest dev already validated** into `charts/todolist/gitops/prod.yaml` — no rebuild.
4. Argo CD reconciles prod.

See [Pipeline](pipeline.md) and [ApplicationSet](applicationset.md) for the target model, and
[Repository structure](../getting-started/repository-structure.md) for where every file lives.

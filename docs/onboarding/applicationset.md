# ApplicationSet

An `ApplicationSet` lives in the **application** repository and generates one Argo CD `Application`
per environment. The application owns its deployment topology; the platform only provides clusters
and the contract.

!!! warning "Current vs target"
    The shape below is the **target** (ADR-014/016): a `list` generator with per-environment chart
    versions in `envs/<env>/values.yaml`. Today's **interim** uses a **clusters** generator and
    `charts/todolist/gitops/<env>.yaml`, with the chart rendered from source for both environments
    (see `todolist-app/deploy/applicationset.yaml`).

## Shape

Each environment pins a **chart version** and an **image digest** in `envs/<env>/values.yaml`. Per
ADR-014, dev tracks the chart **source** on `main`, while prod pins the **released OCI chart
version**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: <app>
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - env: dev
            chartRepo: <application repo>
            chartRevision: main          # dev: chart source on main
          - env: prod
            chartRepo: oci://<registry>/charts
            chartRevision: "0.1.0"        # prod: pinned released chart version
  template:
    metadata:
      name: "<app>-{{ .env }}"
    spec:
      project: default
      source:
        repoURL: "{{ .chartRepo }}"
        targetRevision: "{{ .chartRevision }}"
        # dev renders the chart from source; prod references the OCI chart by name
        path: charts/<app>                # dev
        # chart: <app>                    # prod (OCI)
        helm:
          valueFiles:
            - envs/{{ .env }}/values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: <app>
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Rules

- **One Application per environment**, named `<app>-<env>`.
- **Each environment pins the chart version and the image digest.** All other wiring is injected by
  the platform, so no account IDs, ARNs, or hostnames enter Git (ADR-012).
- **The Helm release name is stable** across renders; the chart derives object names from it, and
  changing it would create a second set of objects.
- **Automated sync** with `prune` and `selfHeal` keeps the cluster matching Git.
- **prod changes only through the promotion PR** (ADR-014), never from a commit to `main`.

## Registering the cluster

When one Argo CD manages several clusters, each target cluster is registered with Argo CD (a cluster
secret). Because the EKS endpoints are private, the Argo CD instance must be able to reach each
cluster's API (ADR-013).

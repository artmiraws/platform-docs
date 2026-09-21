# Vendored Helm charts

The infrastructure installs third-party controllers with Helm. Their charts are vendored as `.tgz`
files under each module's `charts/` directory and referenced by local path, so `tofu plan` and
`tofu apply` never depend on external chart repositories. See ADR-004.

| Chart | Version | Source repository | Vendored path | SHA-256 |
|---|---|---|---|---|
| aws-load-balancer-controller | 3.5.0 | `https://aws.github.io/eks-charts` | `modules/alb/charts/aws-load-balancer-controller-3.5.0.tgz` | `45051f634b33e10baccb3354d0681b7de787c60445e599fa276e0c9aedd4ccd5` |
| external-dns | 1.22.0 | `https://kubernetes-sigs.github.io/external-dns/` | `modules/dns/charts/external-dns-1.22.0.tgz` | `ec26bba67e02f46a55ac33790ad9d9ded724a163af6f6b4a63ce68f883201f4f` |
| external-secrets | 2.10.0 | `https://charts.external-secrets.io` | `modules/eso/charts/external-secrets-2.10.0.tgz` | `b96e948fff3674638b5d3f9e43886f3796e04739c4b4127929aed2ddac7d1418` |
| gha-runner-scale-set-controller | 0.14.2 | `oci://ghcr.io/actions/actions-runner-controller-charts` | `modules/arc/charts/gha-runner-scale-set-controller-0.14.2.tgz` | `222763b7edbe57eabe626cda09bb58040ed9c70471d32aab650c8e6825a3d8e7` |
| gha-runner-scale-set | 0.14.2 | `oci://ghcr.io/actions/actions-runner-controller-charts` | `modules/arc/charts/gha-runner-scale-set-0.14.2.tgz` | `1a2d104e55486cad373a9c33f3cefd0b268cd567743e57ea5da8e1ddf75e0cc0` |
| metrics-server | 3.14.0 | `https://kubernetes-sigs.github.io/metrics-server/` | `modules/metrics-server/charts/metrics-server-3.14.0.tgz` | `c2ca1185c01e6e7f53dd1b7d131f0c9b3fa50e003ed068b784563a1b5a3422a1` |
| cluster-autoscaler | 9.59.0 | `https://kubernetes.github.io/autoscaler` | `modules/cluster-autoscaler/charts/cluster-autoscaler-9.59.0.tgz` | `90276dafe65cf5d4328ef8313baf6cfb9d130683e0c9f3c28a03b4d8a9ed8f6e` |
| argo-cd | 10.9.2 | `https://argoproj.github.io/argo-helm` | `modules/argocd/charts/argo-cd-10.9.2.tgz` | `970ced346a0ddc3e475a7ff780e9b9c2fdebc07d9a367d2edb6ef4f49832c24a` |

## Updating

Re-vendor the tarball and bump the module's `chart_version` (the local chart path is derived from
it), then update the table:

```bash
helm repo add <repo> <url>          # if not already added
helm pull <repo>/<chart> --version <new> -d modules/<module>/charts/
sha256sum modules/<module>/charts/<chart>-<new>.tgz
```

## Provenance

- `external-secrets` publishes a signed provenance file (`.prov`), verifiable with
  `helm verify --keyring <keyring>`; the keyring is not vendored here.
- The other charts publish no provenance file, so the recorded SHA-256 is the integrity reference.

## Future option

Mirror these charts to ECR as OCI artifacts and reference them by digest (`oci://...@sha256:...`).
That matches the common industry pattern and keeps one controlled registry, at the cost of requiring
registry reachability at plan time. Vendoring remains the simplest fully-offline option.

# platform-docs

The **platform handbook**: how the platform is planned, built, and operated, and how to add an
application to it. Built with MkDocs Material and served as a static site.

This repository is also the first application deployed onto the platform by the normal onboarding
path: a Helm chart, a CI pipeline that pushes the image by digest, and Argo CD reconciling it.

## Layout

```text
platform-docs/
├── docs/                      # the handbook content (Markdown)
├── mkdocs.yml                 # site config and navigation
├── requirements.txt           # MkDocs Material
├── Dockerfile                 # multi-stage: mkdocs build -> nginx
├── nginx.conf                 # serves the site and /healthz
├── charts/platform-docs/      # the Helm chart (local + cloud)
│   ├── gitops/dev.yaml        # desired image digest (written by CI)
│   └── templates/
├── .github/workflows/         # dev deploy pipeline
└── Makefile
```

## Run it locally (k3d)

```bash
make up          # build image, ensure the k3d cluster, import, deploy, wait
make health      # GET /healthz through the ingress
```

Open <http://platform-docs.localhost:8080/>.

Authoring with live reload:

```bash
pip install -r requirements.txt
make serve       # http://127.0.0.1:8000
make build-site  # strict build (fails on broken links)
```

## How it deploys

The handbook is a **static site** on S3 + CloudFront (`docs.nexusauto.com.br`), and it owns its own
infrastructure (`infra/`).

1. Push to `main` (or run **Deploy docs** manually).
2. CI applies `infra/` (S3 bucket, CloudFront with an origin access control, ACM certificate, and the
   Route53 record).
3. CI builds the site (`mkdocs build --strict`) and syncs it to S3.
4. CI invalidates the CloudFront cache and smoke-tests `https://docs.nexusauto.com.br/`.

CI runs on the platform's self-hosted runner (in the VPC, IRSA). No AWS keys are stored in this
repository.

# Run the handbook locally

This page is about running **this handbook** on your machine. It is not the platform onboarding
guide — for that, see [Add an application](../onboarding/add-an-application.md).

The handbook is a static site, but it is also an application: it builds to a container image and runs
on Kubernetes. You can run it locally on k3d.

## Authoring (live reload)

```bash
pip install -r requirements.txt
make serve              # live reload at http://127.0.0.1:8000
make build-site         # strict build (fails on broken links)
```

## Run it on the local cluster

```bash
make up
```

That builds the image, ensures the k3d cluster exists, imports the image, applies the manifests, and
waits for the rollout. Then open **<http://platform-docs.localhost:8080/>**.

## Targets

| Target | What it does |
|---|---|
| `make serve` | Run the site with live reload (`mkdocs serve`, <http://127.0.0.1:8000>). |
| `make build-site` | Build the static site with strict link checking. |
| `make up` | Build, ensure the cluster, import, deploy, restart, wait. |
| `make status` | Show pods and ingress. |
| `make logs` | Tail the web logs. |
| `make health` | Check `/healthz`. |
| `make down` | Delete the Kubernetes objects (keeps the cluster). |
| `make clean` | `down` and remove the image. |
| `make destroy` | Delete the k3d cluster. |

## How it works

- `Dockerfile` is a multi-stage build: MkDocs renders the site, then nginx serves the static files.
- `charts/platform-docs` is the single chart for both local and cloud; `values-local.yaml` selects
  the Traefik ingress, one replica, and the locally built image.
- The ingress host is `platform-docs.localhost`; k3d maps host port `8080` to the load balancer.

## Accessing it

`platform-docs.localhost` resolves to loopback, so <http://platform-docs.localhost:8080/> works
directly. If your resolver does not resolve `*.localhost`, use the `Host` header:

```bash
curl -H 'Host: platform-docs.localhost' http://localhost:8080/
```

## Where this is going

Locally the site is built and applied by hand. On the platform it is delivered like any other
application: built in CI, pushed by digest, and reconciled by Argo CD. The same chart is used in both
places, and only the values differ — the onboarding guide in practice.

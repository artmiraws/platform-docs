CLUSTER_NAME     ?= todolist
NAMESPACE        ?= default
RELEASE          ?= platform-docs
IMAGE            ?= platform-docs:local
CHART            ?= charts/platform-docs
VALUES           ?= $(CHART)/values-local.yaml
HOST_PORT        ?= 8080
DOCS_HOSTNAME    ?= platform-docs.localhost
EXPECTED_CONTEXT ?= k3d-$(CLUSTER_NAME)

.DEFAULT_GOAL := help

.PHONY: help serve build-site build cluster import deploy restart wait status logs health up down destroy clean check-context

help:
	@echo "Targets:"
	@echo "  make up          - build the image, ensure the cluster, import, deploy, wait"
	@echo "  make serve       - run the site with live reload (mkdocs serve, 127.0.0.1:8000)"
	@echo "  make build-site  - build the static site with strict link checking"
	@echo "  make build       - build the container image ($(IMAGE))"
	@echo "  make deploy      - helm upgrade --install $(RELEASE) $(CHART) -f $(VALUES)"
	@echo "  make restart     - restart the deployment (pick up a rebuilt image)"
	@echo "  make wait        - wait for the rollout"
	@echo "  make status      - show pods and ingress"
	@echo "  make logs        - tail the web logs"
	@echo "  make health      - check the health endpoint"
	@echo "  make down        - helm uninstall the release (keeps the cluster)"
	@echo "  make clean       - down + remove the image"
	@echo "  make destroy     - delete the k3d cluster"
	@echo ""
	@echo "  URL: http://$(DOCS_HOSTNAME):$(HOST_PORT)/"

serve:
	mkdocs serve

build-site:
	mkdocs build --strict

build:
	docker build -t $(IMAGE) .

check-context:
	@ctx="$$(kubectl config current-context 2>/dev/null)"; \
	if [ "$$ctx" != "$(EXPECTED_CONTEXT)" ]; then \
		echo "kubectl context is '$$ctx', expected '$(EXPECTED_CONTEXT)'."; \
		echo "Switch with: kubectl config use-context $(EXPECTED_CONTEXT)"; \
		exit 1; \
	fi

cluster:
	@if k3d cluster list $(CLUSTER_NAME) >/dev/null 2>&1; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists."; \
	else \
		k3d cluster create $(CLUSTER_NAME) --agents 1 --port "$(HOST_PORT):80@loadbalancer"; \
	fi

import:
	k3d image import $(IMAGE) -c $(CLUSTER_NAME)

deploy: check-context
	helm upgrade --install $(RELEASE) $(CHART) --namespace $(NAMESPACE) -f $(VALUES)

restart: check-context
	kubectl -n $(NAMESPACE) rollout restart deploy/$(RELEASE)

wait: check-context
	kubectl -n $(NAMESPACE) rollout status deploy/$(RELEASE) --timeout=120s

status: check-context
	kubectl -n $(NAMESPACE) get pods -o wide
	@echo "---"
	kubectl -n $(NAMESPACE) get ingress

logs: check-context
	kubectl -n $(NAMESPACE) logs -l app.kubernetes.io/name=$(RELEASE) -f

health: check-context
	@curl -fsS -m 5 -H "Host: $(DOCS_HOSTNAME)" "http://localhost:$(HOST_PORT)/healthz" && echo

up: build cluster import deploy restart wait
	@echo "Ready. Open http://$(DOCS_HOSTNAME):$(HOST_PORT)/"

down: check-context
	helm uninstall $(RELEASE) --namespace $(NAMESPACE) --ignore-not-found

destroy:
	k3d cluster delete $(CLUSTER_NAME)

clean: down
	-docker image rm $(IMAGE)
	@echo "Cleaned up (cluster kept)."

SHELL := /usr/bin/env bash
CONFIG_DIR := .
CLUSTER_NAME := local
KIND_CONFIG := $(CONFIG_DIR)/kind-config.yaml
KIND_CONTEXT := kind-$(CLUSTER_NAME)
SOPS_AGE_KEY := clusters/$(CLUSTER_NAME)/sops.agekey
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)

# Check if required commands are installed
define CHECK_CMD
	if ! command -v $(1) &>/dev/null; then \
		echo "error: missing required command in PATH: $(1)" >&2; \
		exit 1; \
	fi
endef

validate:
	@./scripts/validate.sh

prepare:
	@$(call CHECK_CMD,flux)
	@$(call CHECK_CMD,kubectl)
	@$(call CHECK_CMD,kind)

setup: prepare
	@if kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists."; \
	else \
		echo "Cluster '$(CLUSTER_NAME)' does not exist. It will be created."; \
		kind create cluster --name "$(CLUSTER_NAME)" --config "$(KIND_CONFIG)"; \
		echo "Created kind cluster '$(CLUSTER_NAME)'"; \
	fi

bootstrap: setup
	@echo "Creating a secret with age private key ..."
	@if [[ ! -e "$(SOPS_AGE_KEY)" ]]; then \
		echo "error: Age private key does not exist at $(SOPS_AGE_KEY)." >&2; \
		exit 1; \
	fi
	kubectl --context "$(KIND_CONTEXT)" create namespace flux-system --dry-run=client -o yaml | kubectl --context "$(KIND_CONTEXT)" apply -f -
	kubectl --context "$(KIND_CONTEXT)" create secret generic sops-age \
		--namespace=flux-system \
		--from-file=sops.agekey="$(SOPS_AGE_KEY)" \
		--dry-run=client -o yaml | kubectl --context "$(KIND_CONTEXT)" apply -f -
	@echo "Installing flux ..."
	source .envrc; \
	flux bootstrap github \
		--context=$(KIND_CONTEXT) \
		--owner=$${GITHUB_OWNER} \
		--repository=$${GITHUB_REPO} \
		--personal \
		--private=false \
		--branch=$(GIT_BRANCH) \
		--path=clusters/$(CLUSTER_NAME)
	@echo "Waiting for all flux pods to be ready..."
	kubectl --context "$(KIND_CONTEXT)" -n flux-system wait pod --all \
		--for=condition=Ready \
		--timeout 2m

reconcile:
	@echo "Reconciling Flux source and kustomizations..."
	flux --context "$(KIND_CONTEXT)" -n flux-system reconcile source git flux-system
	flux --context "$(KIND_CONTEXT)" -n flux-system reconcile kustomization flux-system --with-source
	flux --context "$(KIND_CONTEXT)" -n flux-system reconcile kustomization crds --with-source
	flux --context "$(KIND_CONTEXT)" -n flux-system reconcile kustomization bundle --with-source

wait:
	@echo "Waiting for Flux kustomizations to become Ready..."
	kubectl --context "$(KIND_CONTEXT)" -n flux-system wait kustomizations.kustomize.toolkit.fluxcd.io/flux-system --for=condition=Ready=True --timeout=5m
	kubectl --context "$(KIND_CONTEXT)" -n flux-system wait kustomizations.kustomize.toolkit.fluxcd.io/crds --for=condition=Ready=True --timeout=10m
	kubectl --context "$(KIND_CONTEXT)" -n flux-system wait kustomizations.kustomize.toolkit.fluxcd.io/bundle --for=condition=Ready=True --timeout=15m

smoke:
	@echo "Running smoke checks..."
	kubectl --context "$(KIND_CONTEXT)" -n flux-system get kustomizations.kustomize.toolkit.fluxcd.io
	kubectl --context "$(KIND_CONTEXT)" -n homelab wait helmreleases.helm.toolkit.fluxcd.io/podinfo --for=condition=Ready=True --timeout=5m
	kubectl --context "$(KIND_CONTEXT)" -n homelab rollout status deployment/podinfo --timeout=5m
	@echo "Checking podinfo via kind gateway on localhost..."
	curl --fail --silent --show-error \
		--header 'Host: podinfo.local' \
		http://127.0.0.1:8080/healthz >/dev/null

e2e: bootstrap reconcile wait smoke

clean:
	@kind delete cluster --name "$(CLUSTER_NAME)"

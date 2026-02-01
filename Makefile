SHELL := /usr/bin/env bash
CONFIG_DIR := .
CLUSTER_NAME := dev
KIND_CONFIG := $(CONFIG_DIR)/kind-config.yaml

# Check if required commands are installed
define CHECK_CMD
	if ! command -v $(1) &>/dev/null; then \
		echo "error: missing required command in PATH: $(1)" >&2; \
		exit 1; \
	fi
endef

validate:
	@./scripts/validate.sh

prepare: validate
	@$(call CHECK_CMD,flux)
	@$(call CHECK_CMD,kubectl)
	@$(call CHECK_CMD,kind)

setup: prepare
	@if kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists."; \
	else \
		echo "Cluster '$(CLUSTER_NAME)' does not exist. It will be created."; \
		kind create cluster --name "$(CLUSTER_NAME)" --config "$(CONFIG_DIR)/kind-config.yaml"; \
		echo "Created kind cluster '$(CLUSTER_NAME)'"; \
	fi

bootstrap: setup
	@echo "Creating a secret with age private key ..."
	if [[ ! -e clusters/$(CLUSTER_NAME)/sops.agekey ]]; then \
		echo "Age private key does not exist."; \
	fi
	kubectl create namespace flux-system
	cat clusters/$(CLUSTER_NAME)/sops.agekey | \
	kubectl create secret generic sops-age \
		--namespace=flux-system \
		--from-file=sops.agekey=/dev/stdin
	@echo "Installing flux ..."
	source .envrc; \
	flux bootstrap github \
        --context=kind-$(CLUSTER_NAME) \
        --owner=$${GITHUB_OWNER} \
        --repository=$${GITHUB_REPO} \
        --branch=main \
        --personal \
        --path=clusters/$(CLUSTER_NAME)
	@echo "Waiting for all flux pods to be ready..."
	kubectl -n flux-system wait pod --all \
        --for=condition=Ready \
        --timeout 2m

clean:
	@kind delete cluster --name "$(CLUSTER_NAME)"

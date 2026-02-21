# AGENTS.md

This file defines practical guidance for coding agents working in this repository.
It is optimized for safe GitOps changes in a Flux + Kustomize + Kubernetes setup.

## Repository Purpose

- This repo is the source of truth for a homelab Kubernetes platform.
- Flux reconciles manifests from Git into clusters.
- Layout follows a base + cluster-overlay model.

## Current Repository Layout

- `apps/base/` -> reusable base manifests per app (no env overlays here).
- `apps/bundles/` -> deployment composition entrypoints (what each cluster applies) with one patch file per bundle.
- `clusters/<cluster>/apps/` -> cluster-specific overlays and patches.
- `clusters/<cluster>/flux-system/` -> Flux bootstrap and controllers.
- `crds/` -> CRD prerequisites that must reconcile before dependent workloads.
- `scripts/validate.sh` -> manifest and overlay validation pipeline.

## Source-of-Truth Rules

- Keep reusable app defaults in `apps/base/<name>/`.
- Keep cluster-specific values, routes, secrets refs, and patches in `clusters/<cluster>/apps/<name>/`.
- Put composition decisions in `apps/bundles/<name>/kustomization.yaml` and keep bundle patches in a single file (`<bundle>.yaml`).
- Do not re-introduce legacy top-level `applications/` or `infrastructure/` trees.

## Cursor / Copilot Rules

- No `.cursor/rules/` directory exists in this repo.
- No `.cursorrules` file exists in this repo.
- No `.github/copilot-instructions.md` file exists in this repo.
- Therefore, this AGENTS.md is the primary agent guidance document.

## Required Tooling

- `bash`
- `make`
- `flux`
- `kubectl`
- `kind`
- `yq` (v4.34+)
- `kustomize` (v5.3+)
- `kubeconform` (v0.6+)

## Build / Lint / Test Commands

This repo is manifest-centric; "tests" are validation and rendering checks.

- Full validation (primary CI-equivalent command):
  - `make validate`
- Same validation entrypoint directly:
  - `./scripts/validate.sh`
- Render one bundle locally:
  - `kustomize build --load-restrictor LoadRestrictionsNone apps/bundles/dev-flex`
  - `kustomize build --load-restrictor LoadRestrictionsNone apps/bundles/prod-stable`
- Render one cluster entrypoint:
  - `kustomize build --load-restrictor LoadRestrictionsNone clusters/local`
  - `kustomize build --load-restrictor LoadRestrictionsNone clusters/homekube`

## "Single Test" Equivalents (Targeted Validation)

Use these when you changed only one app/overlay and want fast feedback.

- Validate YAML syntax for one file:
  - `yq e 'true' clusters/homekube/apps/n8n/kustomization.yaml > /dev/null`
- Validate one concrete manifest against schemas:
  - `kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas clusters/homekube/apps/n8n/database.yaml`
- Validate one overlay end-to-end:
  - `kustomize build --load-restrictor LoadRestrictionsNone clusters/homekube/apps/n8n | kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas -skip Secret`
- Validate one base app definition:
  - `kustomize build --load-restrictor LoadRestrictionsNone apps/base/n8n | kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas -skip Secret`

## Local Cluster Lifecycle Commands

- Prepare local dependencies and validate manifests:
  - `make prepare`
- Create or reuse kind cluster:
  - `make setup`
- Bootstrap Flux into local cluster:
  - `make bootstrap`
- Delete local kind cluster:
  - `make clean`

## Coding Style Guidelines (YAML / K8s)

- Use 2-space indentation; never tabs.
- Prefer explicit `apiVersion`, `kind`, `metadata.name` in every manifest.
- Add `namespace` explicitly for namespaced resources unless cluster-scoped.
- Keep file names kebab-case, e.g. `helm-release.yaml`, `networkpolicy.yaml`.
- Keep resource names kebab-case and stable (avoid churn in identifiers).
- Group `resources:` in kustomizations deterministically.
- Put reusable objects in `apps/base/<name>/`; put cluster deltas in cluster overlays.
- Use patches for overrides instead of duplicating full manifests.
- Keep comments short, factual, and only when intent is not obvious.

## Flux / HelmRelease Conventions

- Prefer declaring remediation in HelmRelease install/upgrade when applicable.
- Keep reconcile intervals realistic and consistent with neighboring manifests.
- Use `values` for defaults in bases; patch env/cluster specifics in overlays.
- Keep CRDs in dedicated Flux Kustomizations (`clusters/*/crds.yaml`) and make bundles depend on them.
- Do not change Flux bootstrap resources casually under `clusters/*/flux-system/`.

## Types, Naming, and Structure

- Directory names: kebab-case (`external-secrets`, `open-webui`).
- YAML keys: standard Kubernetes casing (`apiVersion`, `matchLabels`, etc.).
- Label keys should follow Kubernetes label conventions.
- Keep one logical resource per file unless tightly coupled by purpose.
- Name kustomization files exactly `kustomization.yaml`.

## Error Handling Guidelines (Scripts / Automation)

- For shell scripts, use strict mode:
  - `set -o errexit`
  - `set -o pipefail`
- Fail fast on validation errors; do not mask non-zero exit codes.
- Keep scripts idempotent where possible (safe to rerun).
- Print concise progress lines (`INFO - ...`) for traceability.

## Secrets and Security Rules

- Never commit plaintext secrets.
- Use SOPS-encrypted files according to `.sops.yaml` path rules.
- Keep secret material in cluster overlays where environment-specific.
- Validation intentionally skips `Secret` schema checks; do not treat that as approval for plaintext values.

## Change Workflow for Agents

1. Make smallest viable change in the correct layer (`apps` vs `clusters`).
2. Run targeted validation for changed files/overlays.
3. Run `make validate` before finalizing substantial changes.
4. Keep docs aligned when structure or workflow changes.
5. Avoid unrelated refactors in the same change.

## PR Hygiene Expectations

- Explain why the change is needed, not only what changed.
- List impacted paths (apps/base, apps/bundles, clusters, crds).
- Mention validation command outputs (`make validate` at minimum).
- Keep commits focused and logically grouped.

## Common Pitfalls to Avoid

- Mixing reusable base logic with cluster-specific overrides.
- Editing bundle composition when only a single overlay patch is needed.
- Adding duplicate namespaces or conflicting resource names.
- Introducing non-deterministic ordering in `resources:` lists.
- Forgetting to update references after moving files.

## Quick Pre-merge Checklist

- Changed files are in the right layer.
- Kustomizations still build.
- `make validate` passes.
- No plaintext credentials introduced.
- Documentation remains accurate.

# Homelab

FluxCD GitOps configuration for my homelab Kubernetes cluster.

## Table of Contents

- [Hardware](#hardware)
- [List of applications](#list-of-applications)
- [Repository structure](#repository-structure)
- [Structure idea](#structure-idea)
- [Flex/Stable bundles and promotion](#flexstable-bundles-and-promotion)
- [Renovate update strategy](#renovate-update-strategy)
- [Flux self-update](#flux-self-update)
- [Secrets management](#secrets-management)
- [Local testing](#local-testing)

## Hardware

I run all virtual machines inside a single physical machine with Proxmox VE:

- CPU: `Intel(R) Xeon(R) CPU E5-2670 v3`
- RAM: `64 GB`
- SSD: `1.5 TB`

Three VMs on Proxmox VE running [Talos Linux](https://www.talos.dev) as the Kubernetes node OS.

## List of Applications

### Networking & Gateway
- [cilium](apps/base/cilium) — eBPF-based CNI, load balancer, and network policy engine
- [envoy-gateway](apps/base/envoy-gateway) — [Kubernetes Gateway API](https://gateway.envoyproxy.io/) implementation based on Envoy
- [cert-manager](apps/base/cert-manager) — [X.509 certificate management](https://cert-manager.io/)
- [external-dns](apps/base/external-dns) — [Synchronizes](https://kubernetes-sigs.github.io/external-dns/) Kubernetes Services and Ingresses with DNS providers
- [istio](apps/base/istio) — [Service mesh](https://istio.io/) for microservices

### Secrets & Security
- [external-secrets](apps/base/external-secrets) — [External Secrets Operator](https://external-secrets.io/) pulls runtime credentials from Vaultwarden into Kubernetes Secrets
- [vaultwarden](apps/base/vaultwarden) — [Bitwarden-compatible server](https://vaultwarden.app/) used as the secret store

### Storage & Databases
- [linstor](apps/base/linstor) — [Software-defined storage](https://linbit.com/linstor/) with DRBD replication (CSI `local` and `replicated` classes)
- [cloudnative-pg](apps/base/cloudnative-pg) — [PostgreSQL operator](https://cloudnative-pg.io/)
- [csi-nfs](apps/base/csi-nfs) — [CSI NFS driver](https://github.com/kubernetes-csi/csi-driver-nfs) for RWX volumes

### Observability
- [victoria-metrics](apps/base/victoria-metrics) — [VictoriaMetrics](https://victoriametrics.com/) k8s stack with Grafana for metrics and alerting
- [victoria-logs](apps/base/victoria-logs) — [VictoriaLogs](https://victoriametrics.com/victorialogs/) for log aggregation
- [blackbox-exporter](apps/base/blackbox-exporter) — [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter) for HTTP/TCP/ICMP endpoint probing
- [metrics-server](apps/base/metrics-server) — Kubernetes resource metrics for HPA/VPA

### Applications
- [immich](apps/base/immich) — [Self-hosted photo management](https://immich.app/)
- [jellyfin](apps/base/jellyfin) — [Media server](https://jellyfin.org/)
- [n8n](apps/base/n8n) — [Workflow and AI automation](https://n8n.io/)
- [open-webui](apps/base/open-webui) — [Web interface for AI models](https://openwebui.com/)
- [mattermost](apps/base/mattermost) — [Self-hosted chat](https://mattermost.com/)
- [qbittorrent](apps/base/qbittorrent) — [BitTorrent client](https://www.qbittorrent.org/)
- [it-tools](apps/base/it-tools) — [Collection of useful IT utilities](https://it-tools.tech/)
- [podinfo](apps/base/podinfo) — [Test workload](https://github.com/stefanprodan/podinfo) for validating deployments

## Repository Structure

```
.
├── apps
│   ├── base                    # Reusable app definitions (HelmRelease, HelmRepository, namespace, …)
│   │   ├── cert-manager
│   │   ├── cilium
│   │   ├── envoy-gateway
│   │   └── …
│   └── bundles                 # Environment aggregations with version-constraint patches
│       ├── dev-flex            # Loose constraints — picks up any new release
│       ├── stage-flex          # Major-pinned — tracks latest within a major version
│       └── prod-stable         # Exact pins — only explicitly approved versions
├── clusters
│   ├── local                   # Local Kind cluster for development and testing
│   │   └── …
│   ├── stage                   # Staging Talos cluster
│   │   ├── apps
│   │   │   ├── kustomization.yaml   # Includes stage-flex bundle + cluster overlays
│   │   │   └── flux-promotion       # Alert + Provider for GitHub dispatch on upgrade success
│   │   ├── bundle.yaml
│   │   └── crds.yaml
│   └── homelab                 # Production Talos cluster
│       ├── apps
│       │   ├── kustomization.yaml   # Includes prod-stable bundle + cluster overlays + patches
│       │   └── …
│       ├── bundle.yaml         # Flux Kustomization → ./clusters/homelab/apps
│       └── crds.yaml           # Flux Kustomization → ./crds/homelab
├── crds                        # Operator CRDs reconciled before app bundles
│   └── homelab
└── .github/workflows
    ├── promotion.yaml          # Promotes stage-flex versions into prod-stable via PR
    ├── flux-update.yaml        # Daily Flux component update via PR
    └── test.yaml
```

## Structure Idea

The basic idea is to define three levels of Kustomize layering:

1. **Base** (`apps/base/<name>`) — common HelmRelease defaults, HelmRepository, and namespace. No environment specifics.
2. **Bundle** (`apps/bundles/<bundle>`) — aggregates base apps and overrides only `spec.chart.spec.version` via a single patch file.
3. **Cluster** (`clusters/<cluster>/apps/`) — entry point that includes a bundle plus cluster-specific resources (storage, routing, secrets refs, network policies) and values patches.

## Flex/Stable Bundles and Promotion

Three bundles cover different stability requirements:

| Bundle | Version constraint style | Example | Purpose |
| --- | --- | --- | --- |
| `dev-flex` | Wildcard / pre-release | `"*"` | Immediately picks up every new release for experimentation |
| `stage-flex` | Major-pinned | `"1.x"`, `"2.x"` | Tracks the latest within a major, absorbs minor/patch automatically |
| `prod-stable` | Exact pin | `"1.19.0"`, `"2.7.0"` | Only explicitly approved versions reach production |

All three bundles reference the same `apps/base/<name>` manifests; only the version constraint differs.

**Promotion flow:**

When a HelmRelease upgrade succeeds on the **stage** cluster, Flux sends a `repository_dispatch` event to GitHub via the [notification controller](https://fluxcd.io/flux/use-cases/gh-actions-helm-promotion/). The [promotion workflow](.github/workflows/promotion.yaml) receives the event, extracts the new chart version, patches the pinned version in `apps/bundles/prod-stable/prod-stable.yaml`, and opens a PR. After review and merge, Flux in the **homelab** cluster reconciles and applies the upgrade.

```
stage-flex upgrade succeeds → Flux Alert → GitHub dispatch → promotion workflow → PR → merge → Flux reconciles homelab
```

The workflow also supports manual triggers via `workflow_dispatch` for ad-hoc promotions.

## Renovate Update Strategy

[Renovate](https://docs.renovatebot.com/) uses its built-in [Flux manager](https://docs.renovatebot.com/modules/manager/flux/) to understand FluxCD resources (`HelmRelease`, `HelmRepository`, `OCIRepository`, etc.) and opens PRs to bump versions across `apps/base/**`, `apps/bundles/**`, and `clusters/**`.

A custom regex manager additionally handles `*-values.yaml` files annotated with `# renovate: datasource=… depName=…` comments for container image tags embedded in Helm values.

## Flux Self-Update

The [flux-update](.github/workflows/flux-update.yaml) workflow runs daily on a cron schedule. It re-exports `gotk-components.yaml` using the latest Flux CLI and opens a PR if there are changes.

## Secrets Management

- **local / stage** — secrets are encrypted in Git with [SOPS](https://github.com/getsops/sops) (age keys) and decrypted by Flux at reconcile time using the `sops-age` secret in `flux-system`.
- **homelab** (production) — [External Secrets Operator](https://external-secrets.io/) pulls runtime credentials from Vaultwarden (via the in-cluster bitwarden-cli webhook) into Kubernetes Secrets. SOPS is only used to solve the chicken-and-egg problem during initial cluster bootstrap.

## Local Testing

Requirements:

- `flux`, `kubectl`, and `kind` available in PATH
- `clusters/local/sops.agekey` present for `make bootstrap`
- `GITHUB_OWNER` and `GITHUB_REPO` exported in the environment

```bash
make bootstrap  # create Kind cluster and bootstrap Flux
make clean      # delete the local Kind cluster
```

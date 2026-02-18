# Homelab

FluxCD configuration for my homelab Kubernetes cluster.

## Summary

Flux CD bootstraps the cluster and reconciles Kustomize overlays and Helm releases.

- `apps/base/` stores reusable app bases (`apps/base/<name>`).
- `apps/bundles/` defines deployable sets (for example `dev-flex`, `prod-stable`) composed from cluster overlays.
- `clusters/` contains cluster overlays (`clusters/<cluster>/apps/<name>`) plus Flux bootstrap.
- `crds/` holds operator CRDs and is reconciled as a separate Flux dependency before bundles.

## Hardware

Single physical machine running Proxmox VE:

- CPU: `Intel(R) Xeon(R) CPU E5-2670 v3`
- RAM: `64 GB`
- SSD: `1.5 TB`

## Kubernetes

Three VMs on Proxmox VE running [Talos Linux](https://www.talos.dev) as the Kubernetes node OS.

## Secrets Management

Secrets are encrypted in Git with SOPS (age) and decrypted by Flux using the `sops-age` secret in `flux-system`. External Secrets Operator pulls runtime credentials from Vaultwarden (via the in-cluster bitwarden-cli webhook) into Kubernetes Secrets.

## Storage

- Linstor provides CSI-backed StorageClasses:
  - `local` (default, local volumes) for databases (CloudNativePG)
  - `replicated` (3-way DRBD replication)
- CSI NFS driver exposes an `nfs-csi` StorageClass for RWX media/app data.

## Local Testing

Requirements:

- `flux`, `kubectl`, and `kind` available in PATH.
- `clusters/dev/sops.agekey` present for `make bootstrap`.
- `GITHUB_OWNER` and `GITHUB_REPO` exported in the environment.

Use Kind targets from the Makefile:

```bash
make e2e
make bootstrap
make clean
```

## Tech Stack

| Name                                                                 | Description                                                                       |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [cert-manager](https://cert-manager.io/)                             | Cloud native certificate management                                               |
| [cilium](https://cilium.io/)                                         | eBPF-based Networking, Observability and Security (CNI, LB, Network Policy, etc.) |
| [cloudnativepg](https://cloudnative-pg.io/)                          | Kubernetes operator for PostgreSQL                                                |
| [external-secrets operator](https://external-secrets.io/)            | Manages secrets from external sources                                             |
| [external-dns](https://kubernetes-sigs.github.io/external-dns/)      | Synchronizes exposed Kubernetes Services and Ingresses with DNS providers         |
| [envoy gateway](https://gateway.envoyproxy.io/)                      | Kubernetes Gateway API implementation based on Envoy                              |
| [fluxcd](https://fluxcd.io/)                                         | GitOps continuous delivery tool                                                   |
| [grafana](https://grafana.com/)                                      | Observability platform                                                            |
| [helm](https://helm.sh/)                                             | The package manager for Kubernetes                                                |
| [istio](https://istio.io/)                                           | Service mesh for microservices                                                    |
| [kubernetes](https://kubernetes.io/)                                 | Container-orchestration system, the backbone of this project                      |
| [linstor](https://linbit.com/linstor/)                               | Software-defined storage for Kubernetes                                           |
| [kustomize](https://kustomize.io/)                                   | Kubernetes configuration customization                                            |
| [sops](https://github.com/getsops/sops)                              | Secrets encryption using age keys                                                 |
| [victoria metrics](https://victoriametrics.com/)                     | Fast, cost-effective monitoring solution                                          |
| [victoria logs](https://victoriametrics.com/victorialogs/)           | Log aggregation system                                                            |
| [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs)   | CSI driver for NFS                                                                |
| [blackbox-exporter](https://github.com/prometheus/blackbox_exporter) | Probes endpoints over HTTP, HTTPS, DNS, TCP, ICMP                                 |
| [vaultwarden](https://vaultwarden.app/)                              | Unofficial Bitwarden-compatible server                                            |
| [qbittorrent](https://www.qbittorrent.org/)                          | BitTorrent client                                                                 |
| [podinfo](https://github.com/stefanprodan/podinfo)                   | Web application to test Kubernetes deployments                                    |
| [open-webui](https://openwebui.com/)                                 | Web interface for AI models                                                       |
| [n8n](https://n8n.io/)                                               | Workflow automation tool                                                          |
| [mattermost](https://mattermost.com/)                                | Self-hosted chat service                                                          |
| [jellyfin](https://jellyfin.org/)                                    | Media server                                                                      |
| [it-tools](https://it-tools.tech/)                                   | Collection of useful IT utilities                                                 |
| [immich](https://immich.app/)                                        | Self-hosted photo management                                                      |
| [immich](https://immich.app/)                                        | Self-hosted photo management                                                      |

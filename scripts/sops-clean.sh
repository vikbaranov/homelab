#!/usr/bin/env bash
# Git clean filter for SOPS.
# Encrypts plaintext files on `git add`; passes already-encrypted files through unchanged.
# Skips ExternalSecrets, ClusterSecretStores, and SecretStores (external-secrets.io resources).
# Usage (set via `make git-sops-setup`):
#   git config filter.sops.clean "scripts/sops-clean.sh %f"
set -euo pipefail

FILENAME="${1:?filename argument required}"
input=$(cat)

if printf '%s\n' "$input" | grep -q '^sops:'; then
    # File already carries SOPS metadata — pass through as-is
    printf '%s\n' "$input"
elif printf '%s\n' "$input" | grep -qE '^kind: (ExternalSecret|ClusterSecretStore|SecretStore)$'; then
    # ExternalSecret resources don't contain sensitive data, just references — pass through as-is
    printf '%s\n' "$input"
else
    printf '%s\n' "$input" | sops --encrypt --filename-override="$FILENAME" /dev/stdin
fi

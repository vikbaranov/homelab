#!/usr/bin/env bash
# Git clean filter for SOPS.
# Encrypts plaintext files on `git add`; passes already-encrypted files through unchanged.
# Usage (set via `make git-sops-setup`):
#   git config filter.sops.clean "scripts/sops-clean.sh %f"
set -euo pipefail

FILENAME="${1:?filename argument required}"
input=$(cat)

if printf '%s\n' "$input" | grep -q '^sops:'; then
    # File already carries SOPS metadata — pass through as-is
    printf '%s\n' "$input"
else
    printf '%s\n' "$input" | sops --encrypt --filename-override="$FILENAME" /dev/stdin
fi

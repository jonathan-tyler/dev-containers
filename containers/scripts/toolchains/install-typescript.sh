#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-developer}"

pnpm add --global typescript tsx
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local/share/pnpm
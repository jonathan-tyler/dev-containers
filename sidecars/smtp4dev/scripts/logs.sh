#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
asset_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"

if [ -f "$asset_dir/.env" ]; then
	set -a
	. "$asset_dir/.env"
	set +a
fi

: "${SMTP_CONTAINER_NAME:=smtp4dev}"

podman logs -f "$SMTP_CONTAINER_NAME"
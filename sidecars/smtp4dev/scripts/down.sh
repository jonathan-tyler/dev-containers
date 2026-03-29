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
: "${SMTP_VOLUME_NAME:=smtp4dev-data}"

podman rm -f "$SMTP_CONTAINER_NAME" >/dev/null 2>&1 || true
echo "Removed container $SMTP_CONTAINER_NAME"

if [ "${SMTP_PURGE_DATA:-0}" = "1" ]; then
	podman volume rm -f "$SMTP_VOLUME_NAME" >/dev/null 2>&1 || true
	echo "Removed volume $SMTP_VOLUME_NAME"
fi
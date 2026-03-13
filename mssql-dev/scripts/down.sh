#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
asset_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"

if [ -f "$asset_dir/.env" ]; then
	set -a
	. "$asset_dir/.env"
	set +a
fi

: "${MSSQL_CONTAINER_NAME:=mssql-dev}"
: "${MSSQL_VOLUME_NAME:=mssql-dev-data}"

podman rm -f "$MSSQL_CONTAINER_NAME" >/dev/null 2>&1 || true
echo "Removed container $MSSQL_CONTAINER_NAME"

if [ "${MSSQL_PURGE_DATA:-0}" = "1" ]; then
	podman volume rm -f "$MSSQL_VOLUME_NAME" >/dev/null 2>&1 || true
	echo "Removed volume $MSSQL_VOLUME_NAME"
fi
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

podman ps -a --filter "name=$MSSQL_CONTAINER_NAME"
echo
podman port "$MSSQL_CONTAINER_NAME" 2>/dev/null || true
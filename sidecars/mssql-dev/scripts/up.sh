#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
asset_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"

if [ -f "$asset_dir/.env" ]; then
	set -a
	. "$asset_dir/.env"
	set +a
fi

: "${MSSQL_IMAGE:=mcr.microsoft.com/mssql/server:2022-latest}"
: "${MSSQL_CONTAINER_NAME:=mssql-dev}"
: "${MSSQL_VOLUME_NAME:=mssql-dev-data}"
: "${MSSQL_HOST_PORT:=14333}"
: "${MSSQL_PID:=Developer}"

if [ -z "${MSSQL_SA_PASSWORD:-}" ]; then
	echo "MSSQL_SA_PASSWORD is required. Set it in the environment or in $asset_dir/.env" >&2
	exit 1
fi

if ! podman volume inspect "$MSSQL_VOLUME_NAME" >/dev/null 2>&1; then
	podman volume create "$MSSQL_VOLUME_NAME" >/dev/null
fi

podman rm -f "$MSSQL_CONTAINER_NAME" >/dev/null 2>&1 || true

podman run -d \
	--name "$MSSQL_CONTAINER_NAME" \
	--replace \
	-e ACCEPT_EULA=Y \
	-e MSSQL_SA_PASSWORD="$MSSQL_SA_PASSWORD" \
	-e MSSQL_PID="$MSSQL_PID" \
	-p "$MSSQL_HOST_PORT:1433" \
	-v "$MSSQL_VOLUME_NAME:/var/opt/mssql:Z" \
	"$MSSQL_IMAGE"

echo "Started $MSSQL_CONTAINER_NAME on localhost,$MSSQL_HOST_PORT"
echo "Use ./scripts/logs.sh to watch startup logs until SQL Server is ready."
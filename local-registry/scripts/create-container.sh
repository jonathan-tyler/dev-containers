#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$script_dir/common.sh"

require_command podman

if container_exists "$REGISTRY_CONTAINER_NAME"; then
	if container_has_expected_port_binding "$REGISTRY_CONTAINER_NAME"; then
		exit 0
	fi

	if container_running "$REGISTRY_CONTAINER_NAME"; then
		podman stop "$REGISTRY_CONTAINER_NAME" >/dev/null
	fi

	podman rm "$REGISTRY_CONTAINER_NAME" >/dev/null
	log "Recreated registry container '$REGISTRY_CONTAINER_NAME' to apply loopback-only bind ${REGISTRY_BIND_HOST}:${REGISTRY_PORT}"
fi

podman create \
	--name "$REGISTRY_CONTAINER_NAME" \
	-p "${REGISTRY_BIND_HOST}:${REGISTRY_PORT}:5000" \
	"$REGISTRY_IMAGE" >/dev/null

log "Created registry container '$REGISTRY_CONTAINER_NAME' on ${REGISTRY_BIND_HOST}:${REGISTRY_PORT} -> 5000"
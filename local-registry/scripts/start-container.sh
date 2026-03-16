#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$script_dir/common.sh"

require_command podman

"$script_dir/create-container.sh"

if ! container_running "$REGISTRY_CONTAINER_NAME"; then
	podman start "$REGISTRY_CONTAINER_NAME" >/dev/null
	log "Started registry container '$REGISTRY_CONTAINER_NAME'"
	else
	log "Registry container '$REGISTRY_CONTAINER_NAME' is already running"
fi

log "Local registry running at $REGISTRY_ADDRESS (container: $REGISTRY_CONTAINER_NAME)"
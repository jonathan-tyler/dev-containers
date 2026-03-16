#!/usr/bin/env bash
set -euo pipefail

LOCAL_REGISTRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY_CONTAINER_NAME="${REGISTRY_CONTAINER_NAME:-local-registry}"
REGISTRY_ADDRESS="${REGISTRY_ADDRESS:-127.0.0.1:5000}"
REGISTRY_BIND_HOST="${REGISTRY_BIND_HOST:-127.0.0.1}"
REGISTRY_PORT="${REGISTRY_ADDRESS##*:}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-docker.io/library/registry:2}"

log() {
	printf '%s\n' "$*"
}

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "Required command not found on PATH: $1"
}

container_exists() {
	podman container exists "$1"
}

container_running() {
	podman ps --format '{{.Names}}' | grep -qx "$1"
}

expected_port_binding() {
	printf '%s:%s' "$REGISTRY_BIND_HOST" "$REGISTRY_PORT"
}

container_has_expected_port_binding() {
	local port_json
	local expected_json_fragment

	port_json="$(podman inspect --format '{{json .NetworkSettings.Ports}}' "$1")"
	expected_json_fragment="\"HostIp\":\"${REGISTRY_BIND_HOST}\",\"HostPort\":\"${REGISTRY_PORT}\""
	[[ "$port_json" == *'"5000/tcp"'* ]] || return 1
	[[ "$port_json" == *"$expected_json_fragment"* ]]
}
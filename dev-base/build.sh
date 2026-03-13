#!/usr/bin/env sh
set -eu
build_context="$(cd "$(dirname "$0")" && pwd)"
registry_setup_script="$build_context/setup-local-registry.sh"
version_tag="${1:-}"
local_image="dev-base:latest"
registry_address="localhost:5000"
registry_image="${registry_address}/dev-base:latest"

if [ -x "$registry_setup_script" ]; then
	"$registry_setup_script"
else
	echo "Registry setup script not found or not executable: $registry_setup_script" >&2
	exit 1
fi

# Copy personal starship config to build context
[ -f "${HOME}/.config/starship.toml" ] && cp -f "${HOME}/.config/starship.toml" "${build_context}/.starship.toml"

podman build -f "$build_context/Containerfile" -t "$local_image" "$build_context"
podman tag "$local_image" "$registry_image"
podman push --tls-verify=false "$registry_image"

if [ -n "$version_tag" ]; then
	registry_version_image="${registry_address}/dev-base:${version_tag}"
	podman tag "$local_image" "$registry_version_image"
	podman push --tls-verify=false "$registry_version_image"
fi

# curl -s "http://localhost:5000/v2/_catalog" | jq

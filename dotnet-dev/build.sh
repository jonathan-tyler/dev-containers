#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_BUILD_SCRIPT="$HOME/.agents/skills-common/dev-containers/assets/dev-base/build.sh"
REGISTRY_SETUP_SCRIPT="$HOME/.agents/skills-common/dev-containers/assets/dev-base/setup-local-registry.sh"

if [ -x "$REGISTRY_SETUP_SCRIPT" ]; then
	"$REGISTRY_SETUP_SCRIPT"
else
	echo "Registry setup script not found or not executable: $REGISTRY_SETUP_SCRIPT" >&2
	exit 1
fi

version_tag="${1:-}"

if [ -x "$BASE_BUILD_SCRIPT" ]; then
	echo "Building and pushing base image using $BASE_BUILD_SCRIPT"
	if [ -n "$version_tag" ]; then
		"$BASE_BUILD_SCRIPT" "$version_tag"
	else
		"$BASE_BUILD_SCRIPT"
	fi
else
	echo "Base build script not found or not executable: $BASE_BUILD_SCRIPT" >&2
	exit 1
fi

build_context="$SCRIPT_DIR"
image_name="dotnet-dev"
local_latest_image="${image_name}:latest"
registry_address="localhost:5000"
registry_latest_image="${registry_address}/${image_name}:latest"

echo "Building image: $local_latest_image from context: $build_context"
podman build -f "$build_context/Containerfile" -t "$local_latest_image" "$build_context"

echo "Tagging image as: $registry_latest_image"
podman tag "$local_latest_image" "$registry_latest_image"

echo "Pushing image to registry: $registry_latest_image"
podman push --tls-verify=false "$registry_latest_image"

if [ -n "$version_tag" ]; then
	registry_version_image="${registry_address}/${image_name}:${version_tag}"
	echo "Tagging image as: $registry_version_image"
	podman tag "$local_latest_image" "$registry_version_image"
	echo "Pushing image to registry: $registry_version_image"
	podman push --tls-verify=false "$registry_version_image"
fi

#!/usr/bin/env sh
set -eu
registry_name="local"
registry_address="localhost:5000"

# Ensure a local registry is running for pushes to registry_address.
if ! podman ps -a --format '{{.Names}}' | grep -qx "$registry_name"; then
    podman run -d --name "$registry_name" -p 5000:5000 docker.io/library/registry:2
elif ! podman ps --format '{{.Names}}' | grep -qx "$registry_name"; then
    podman start "$registry_name" >/dev/null
fi

echo "Local registry running at $registry_address (container: $registry_name)"

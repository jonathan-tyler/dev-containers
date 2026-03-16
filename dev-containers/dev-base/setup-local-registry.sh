#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
registry_script="$script_dir/../../local-registry/scripts/start-container.sh"

if [[ ! -x "$registry_script" ]]; then
	echo "Registry start script not found or not executable: $registry_script" >&2
	exit 1
fi

exec "$registry_script"

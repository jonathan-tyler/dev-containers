#!/usr/bin/env bash

set -euo pipefail

if ! command -v devcontainer-apply-customizations >/dev/null 2>&1; then
	echo "devcontainer-apply-customizations is not installed in the image" >&2
	exit 1
fi

exec devcontainer-apply-customizations
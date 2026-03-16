#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/scripts/create-container.sh"
"$script_dir/scripts/start-container.sh"
"$script_dir/scripts/install-systemd-user-service.sh"

printf 'Local registry is installed, running, and enabled via systemd user service.\n'
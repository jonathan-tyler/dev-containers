#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$script_dir/common.sh"

require_command podman
require_command systemctl

"$script_dir/create-container.sh"

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
unit_path="$unit_dir/${REGISTRY_CONTAINER_NAME}.service"
unit_template="$LOCAL_REGISTRY_DIR/systemd/local-registry.service"
podman_bin="$(command -v podman)"

mkdir -p "$unit_dir"

[[ -f "$unit_template" ]] || fail "Systemd unit template not found: $unit_template"

sed \
	-e "s|__PODMAN_BIN__|$podman_bin|g" \
	-e "s|__REGISTRY_CONTAINER_NAME__|$REGISTRY_CONTAINER_NAME|g" \
	"$unit_template" > "$unit_path"

if command -v loginctl >/dev/null 2>&1; then
	linger_state="$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null || true)"
	if [[ "$linger_state" != "yes" ]]; then
		if command -v sudo >/dev/null 2>&1; then
			sudo loginctl enable-linger "$USER"
		else
			fail "User lingering is disabled and sudo is unavailable. Run 'sudo loginctl enable-linger $USER' and rerun this installer."
		fi
	fi
fi

systemctl --user daemon-reload
systemctl --user enable --now "${REGISTRY_CONTAINER_NAME}.service"

log "Installed and enabled systemd user service '${REGISTRY_CONTAINER_NAME}.service'"
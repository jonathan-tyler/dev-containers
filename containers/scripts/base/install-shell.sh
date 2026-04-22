#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-developer}"

apt-get update
apt-get install -y --no-install-recommends \
	starship \
	zsh \
	zsh-autosuggestions

usermod --shell /usr/bin/zsh "${USERNAME}"
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "/home/${USERNAME}/.oh-my-zsh"

install -d -m 0755 /usr/local/share/dev-container

cat <<'EOF' > /usr/local/share/dev-container/default-zshrc
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# VS Code shell integration (zsh)
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  _vscode_zsh_integration_path="$(code --locate-shell-integration-path zsh 2>/dev/null || true)"
  if [[ -n "$_vscode_zsh_integration_path" ]] && [[ -f "$_vscode_zsh_integration_path" ]]; then
    source "$_vscode_zsh_integration_path"
  fi
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
EOF

cat <<'EOF' > /usr/local/bin/devcontainer-apply-customizations
#!/usr/bin/env bash
set -euo pipefail

is_true() {
	case "${1:-}" in
		1|true|TRUE|yes|YES|on|ON)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

source_root="${CHEZMOI_SOURCE_DIR:-${HOME}/.local/share/chezmoi}"
override_data="${CHEZMOI_APPLY_OVERRIDE_DATA:-}"
default_zshrc="/usr/local/share/dev-container/default-zshrc"
target_zshrc="${HOME}/.zshrc"

if [[ -n "${CHEZMOI_SOURCE_DIR:-}" ]] || [[ -d "${source_root}" ]]; then
	if [[ ! -d "${source_root}" ]]; then
		if is_true "${DEVCONTAINER_CHEZMOI_REQUIRED:-false}"; then
			echo "Missing mounted chezmoi source at ${source_root}" >&2
			exit 1
		fi
	elif ! command -v chezmoi >/dev/null 2>&1; then
		if is_true "${DEVCONTAINER_CHEZMOI_REQUIRED:-false}"; then
			echo "chezmoi is not installed in the devcontainer image" >&2
			exit 1
		fi
	else
		chezmoi_args=(
			apply
			--force
			--no-tty
			--destination "${HOME}"
			--source "${source_root}"
			--refresh-externals=always
		)

		if [[ -n "${override_data}" ]]; then
			chezmoi_args+=(--override-data "${override_data}")
		fi

		chezmoi "${chezmoi_args[@]}"
		echo "Applied chezmoi source from ${source_root}"
		exit 0
	fi
fi

if is_true "${DEVCONTAINER_CHEZMOI_REQUIRED:-false}"; then
	echo "chezmoi customization was required but could not be applied" >&2
	exit 1
fi

if is_true "${DEVCONTAINER_BOOTSTRAP_DEFAULT_SHELL:-true}" \
	&& [[ ! -e "${target_zshrc}" ]] \
	&& [[ -f "${default_zshrc}" ]]; then
	install -D -m 0644 "${default_zshrc}" "${target_zshrc}"
	echo "Installed default zsh configuration at ${target_zshrc}"
fi
EOF

chmod 0755 /usr/local/bin/devcontainer-apply-customizations
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.oh-my-zsh"

rm -rf /var/lib/apt/lists/*
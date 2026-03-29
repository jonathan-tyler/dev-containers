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

printf '%s\n' \
	'export ZSH="$HOME/.oh-my-zsh"' \
	'ZSH_THEME="robbyrussell"' \
	'plugins=(git)' \
	'source "$ZSH/oh-my-zsh.sh"' \
	'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' \
	'# VS Code shell integration (zsh)' \
	'if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then' \
	'  _vscode_zsh_integration_path="$(code --locate-shell-integration-path zsh 2>/dev/null || true)"' \
	'  if [[ -n "$_vscode_zsh_integration_path" ]] && [[ -f "$_vscode_zsh_integration_path" ]]; then' \
	'    source "$_vscode_zsh_integration_path"' \
	'  fi' \
	'fi' \
	'if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init zsh)"; fi' \
	'if [ -f "$HOME/.config/starship.toml" ]; then export STARSHIP_CONFIG="$HOME/.config/starship.toml"; fi' \
	'if command -v starship >/dev/null 2>&1; then eval "$(starship init zsh)"; fi' \
	> "/home/${USERNAME}/.zshrc"

chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.zshrc"
if [[ -f "/home/${USERNAME}/.zsh_history" ]]; then
	chmod 600 "/home/${USERNAME}/.zsh_history"
	chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.zsh_history"
fi
if [[ -f "/home/${USERNAME}/.config/starship.toml" ]]; then
	chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config/starship.toml"
fi
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.oh-my-zsh"

rm -rf /var/lib/apt/lists/*
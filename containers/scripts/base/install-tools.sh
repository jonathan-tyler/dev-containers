#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-developer}"

apt-get update
apt-get install -y --no-install-recommends \
	gh \
	git \
	jq \
	less \
	lsof \
	openssh-client \
	poppler-utils \
	procps \
	ripgrep \
	sqlite3 \
	tesseract-ocr \
	tree \
	unzip \
	vim \
	zip

curl -fsSL https://gh.io/copilot-install | bash

git config --system core.editor vim

install -d -m 0755 /workspaces
install -d -m 0755 /workspaces/repos
install -d -m 0755 "/home/${USERNAME}/.cache"
install -d -m 0755 "/home/${USERNAME}/.config"
install -d -m 0755 "/home/${USERNAME}/.local"
install -d -m 0755 "/home/${USERNAME}/.local/share"
install -d -m 0755 "/home/${USERNAME}/.vscode-server/data/Machine"

chown -R "${USERNAME}:${USERNAME}" /workspaces
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.cache"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.local"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.vscode-server"

rm -rf /var/lib/apt/lists/*
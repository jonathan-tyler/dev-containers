#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="24.14.0"
PNPM_VERSION="10.32.1"
PNPM_HOME="${PNPM_HOME:-/home/developer/.local/share/pnpm}"
USERNAME="${USERNAME:-developer}"

apt-get update
apt-get install -y --no-install-recommends xz-utils

arch="$(dpkg --print-architecture)"
case "$arch" in
	amd64) node_arch='x64' ;;
	arm64) node_arch='arm64' ;;
	*)
		echo "Unsupported architecture: $arch" >&2
		exit 1
		;;
esac

curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz
rm -rf /usr/local/node
install -d -m 0755 /usr/local/bin
mkdir -p /usr/local/node
install -d -m 0755 "$PNPM_HOME"
install -d -m 0755 /home/${USERNAME}/.local/share/pnpm/store
tar -xJf /tmp/node.tar.xz --strip-components=1 -C /usr/local/node
rm -f /tmp/node.tar.xz
ln -sf /usr/local/node/bin/node /usr/local/bin/node
ln -sf /usr/local/node/bin/npm /usr/local/bin/npm
ln -sf /usr/local/node/bin/npx /usr/local/bin/npx
ln -sf /usr/local/node/bin/corepack /usr/local/bin/corepack
npm install --global "pnpm@${PNPM_VERSION}"
node --version
npm --version
pnpm --version
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local/share/pnpm
rm -rf /var/lib/apt/lists/*
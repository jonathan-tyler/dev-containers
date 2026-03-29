#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-developer}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

apt-get update
apt-get install -y --no-install-recommends \
	adduser \
	build-essential \
	ca-certificates \
	curl \
	passwd \
	pkg-config

ldconfig
test -f /etc/ld.so.cache || touch /etc/ld.so.cache

if ! id -u "${USERNAME}" >/dev/null 2>&1; then
	groupadd --gid "${USER_GID}" "${USERNAME}"
	useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}"
fi

install -d -m 0755 "/home/${USERNAME}/.cache"
install -d -m 0755 "/home/${USERNAME}/.config"
install -d -m 0755 "/home/${USERNAME}/.local"
install -d -m 0755 "/home/${USERNAME}/.local/share"

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.cache"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.local"

rm -rf /var/lib/apt/lists/*
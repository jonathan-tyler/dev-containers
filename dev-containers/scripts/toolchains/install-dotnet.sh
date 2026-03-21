#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-developer}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

apt-get update
apt-get install -y --no-install-recommends curl
rm -rf /var/lib/apt/lists/*

mkdir -p /usr/local/bin /usr/share/dotnet /tmp/dotnet-install
install -d -m 0755 /home/${USERNAME}/.local
install -d -m 0755 /home/${USERNAME}/.local/share
install -d -m 0755 /home/${USERNAME}/.local/share/NuGet
install -d -m 0755 /home/${USERNAME}/.nuget
install -d -m 0755 /home/${USERNAME}/.nuget/NuGet
install -d -m 0755 /home/${USERNAME}/.nuget/packages
install -d -m 0755 /home/${USERNAME}/.nuget/http-cache
install -d -m 0755 /home/${USERNAME}/.nuget/plugins-cache
install -d -m 0755 /home/${USERNAME}/.microsoft
install -d -m 0755 /home/${USERNAME}/.microsoft/usersecrets

curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install/dotnet-install.sh
chmod +x /tmp/dotnet-install/dotnet-install.sh

/tmp/dotnet-install/dotnet-install.sh --channel 8.0 --quality ga --install-dir /usr/share/dotnet
/tmp/dotnet-install/dotnet-install.sh --channel 9.0 --quality ga --install-dir /usr/share/dotnet
/tmp/dotnet-install/dotnet-install.sh --channel 10.0 --quality ga --install-dir /usr/share/dotnet

ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
dotnet --list-sdks

cd /home/${USERNAME}
mkdir -p ./.config
if [ ! -f ./.config/dotnet-tools.json ]; then
	dotnet new tool-manifest --output ./.config
fi

if ! dotnet tool list --local | awk 'NR>2 { print $1 }' | grep -qx "csharpier"; then
	dotnet tool install csharpier --local
fi

dotnet tool list --local
chown -R ${USER_UID}:${USER_GID} /home/${USERNAME}/.local /home/${USERNAME}/.nuget /home/${USERNAME}/.microsoft
rm -rf /tmp/dotnet-install
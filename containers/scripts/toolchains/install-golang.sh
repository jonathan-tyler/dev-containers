#!/usr/bin/env bash
set -euo pipefail

GO_VERSION="1.26.1"
GOPLS_VERSION="v0.21.1"
GOLANG_X_TOOLS_VERSION="v0.42.0"
DELVE_VERSION="v1.26.1"
STATICCHECK_VERSION="v0.7.0"

arch="$(dpkg --print-architecture)"
case "$arch" in
	amd64) go_arch='amd64' ;;
	arm64) go_arch='arm64' ;;
	*)
		echo "Unsupported architecture: $arch" >&2
		exit 1
		;;
esac

curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tgz
rm -f /tmp/go.tgz
go version

mkdir -p /tmp/go-tools-mod
cd /tmp/go-tools-mod
go mod init go-tools-mod
cat <<EOF > go.mod
module go-tools-mod

go 1.22

require (
	github.com/go-delve/delve ${DELVE_VERSION}
	golang.org/x/tools/gopls ${GOPLS_VERSION}
	golang.org/x/tools ${GOLANG_X_TOOLS_VERSION}
	honnef.co/go/tools ${STATICCHECK_VERSION}
)
EOF

go mod download
go install golang.org/x/tools/gopls@${GOPLS_VERSION}
go install golang.org/x/tools/cmd/goimports@${GOLANG_X_TOOLS_VERSION}
go install github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}
go install honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION}

rm -rf /tmp/go-tools-mod
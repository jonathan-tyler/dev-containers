#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINERFILE="$SCRIPT_DIR/Containerfile"

for cmd in curl jq awk mktemp; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Missing required command: $cmd" >&2
		exit 1
	fi
done

fetch_version() {
	url="$1"
	curl -fsSL "$url" | jq -r '.Version'
}

GOPLS_VERSION="$(fetch_version "https://proxy.golang.org/golang.org/x/tools/gopls/@latest")"
GOLANG_X_TOOLS_VERSION="$(fetch_version "https://proxy.golang.org/golang.org/x/tools/@latest")"
DELVE_VERSION="$(fetch_version "https://proxy.golang.org/github.com/go-delve/delve/@latest")"
STATICCHECK_VERSION="$(fetch_version "https://proxy.golang.org/honnef.co/go/tools/@latest")"

for version in "$GOPLS_VERSION" "$GOLANG_X_TOOLS_VERSION" "$DELVE_VERSION" "$STATICCHECK_VERSION"; do
	case "$version" in
		v*) ;;
		*)
			echo "Unexpected version value: $version" >&2
			exit 1
			;;
	esac
done

tmp_file="$(mktemp)"
awk \
	-v gopls="$GOPLS_VERSION" \
	-v xtools="$GOLANG_X_TOOLS_VERSION" \
	-v delve="$DELVE_VERSION" \
	-v staticcheck="$STATICCHECK_VERSION" \
	'
	$1 == "ENV" && $2 ~ /^GOPLS_VERSION=/ { print "ENV GOPLS_VERSION=" gopls; next }
	$1 == "ENV" && $2 ~ /^GOLANG_X_TOOLS_VERSION=/ { print "ENV GOLANG_X_TOOLS_VERSION=" xtools; next }
	$1 == "ENV" && $2 ~ /^DELVE_VERSION=/ { print "ENV DELVE_VERSION=" delve; next }
	$1 == "ENV" && $2 ~ /^STATICCHECK_VERSION=/ { print "ENV STATICCHECK_VERSION=" staticcheck; next }
	{ print }
	' "$CONTAINERFILE" > "$tmp_file"

mv "$tmp_file" "$CONTAINERFILE"

echo "Updated $CONTAINERFILE"
echo "  GOPLS_VERSION=$GOPLS_VERSION"
echo "  GOLANG_X_TOOLS_VERSION=$GOLANG_X_TOOLS_VERSION"
echo "  DELVE_VERSION=$DELVE_VERSION"
echo "  STATICCHECK_VERSION=$STATICCHECK_VERSION"

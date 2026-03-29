#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
asset_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"

if [ -f "$asset_dir/.env" ]; then
	set -a
	. "$asset_dir/.env"
	set +a
fi

: "${SMTP_IMAGE:=rnwood/smtp4dev:latest}"
: "${SMTP_CONTAINER_NAME:=smtp4dev}"
: "${SMTP_VOLUME_NAME:=smtp4dev-data}"
: "${SMTP_HOST_PORT:=1025}"
: "${SMTP_WEB_PORT:=8025}"

if ! podman volume inspect "$SMTP_VOLUME_NAME" >/dev/null 2>&1; then
	podman volume create "$SMTP_VOLUME_NAME" >/dev/null
fi

podman rm -f "$SMTP_CONTAINER_NAME" >/dev/null 2>&1 || true

podman run -d \
	--name "$SMTP_CONTAINER_NAME" \
	--replace \
	-p "$SMTP_HOST_PORT:25" \
	-p "$SMTP_WEB_PORT:80" \
	-v "$SMTP_VOLUME_NAME:/smtp4dev:Z" \
	"$SMTP_IMAGE"

echo "Started $SMTP_CONTAINER_NAME"
echo "SMTP endpoint: localhost:$SMTP_HOST_PORT"
echo "Inbox UI: http://localhost:$SMTP_WEB_PORT"
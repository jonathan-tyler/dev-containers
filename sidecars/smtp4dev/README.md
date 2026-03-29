# smtp4dev Asset

Host-managed smtp4dev container for local email testing.

This asset is intentionally separate from any `devcontainer.json` lifecycle. Run it on the host with Podman, then point local apps at the SMTP endpoint. Open the web UI on the host to inspect captured messages. From inside a devcontainer, use `host.containers.internal` instead of `localhost`.

## Files

- `smtp4dev.env.example`: example environment variables.
- `scripts/up.sh`: start or replace the smtp4dev container.
- `scripts/down.sh`: stop and remove the container.
- `scripts/status.sh`: show container and port status.
- `scripts/logs.sh`: follow container logs.

## Quick Start

From this directory:

```sh
cp smtp4dev.env.example .env
./scripts/up.sh
./scripts/status.sh
```

Default connection details:

- SMTP host from the host: `localhost`
- SMTP port: `1025`
- Inbox UI: `http://localhost:8025`

From inside another devcontainer, use:

- SMTP host: `host.containers.internal`
- SMTP port: `1025`
- Inbox UI: `http://host.containers.internal:8025`

## Notes

- Image: `rnwood/smtp4dev:latest`
- Persistent storage: Podman volume `smtp4dev-data` by default
- Container name: `smtp4dev` by default
- smtp4dev stores its database and generated TLS assets under `/smtp4dev` in the container

## Tear Down

```sh
./scripts/down.sh
```

To remove persisted messages too:

```sh
SMTP_PURGE_DATA=1 ./scripts/down.sh
```
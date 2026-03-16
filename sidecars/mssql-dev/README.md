# MSSQL Dev Asset

Host-managed Microsoft SQL Server container for local query testing and fixture-driven SQL work.

This asset is intentionally separate from any `devcontainer.json` lifecycle. Run it on the host with Podman, then connect from tools on the host using `localhost,<port>` or from inside a devcontainer using `host.containers.internal,<port>`.

## Files

- `mssql.env.example`: example environment variables.
- `scripts/up.sh`: start or replace the SQL Server container.
- `scripts/down.sh`: stop and remove the container.
- `scripts/status.sh`: show container and port status.
- `scripts/logs.sh`: follow container logs.

## Quick Start

From this directory:

```sh
cp mssql.env.example .env
vi .env
set -a
. ./.env
set +a
./scripts/up.sh
./scripts/status.sh
```

Required variable:

- `MSSQL_SA_PASSWORD`: SQL Server `sa` password. For the current local setup, set this in `.env` to the agreed local dev password.

Default connection details:

- Host: `localhost,14333`
- Username: `sa`
- Password: value from `MSSQL_SA_PASSWORD` in your local `.env`
- Encryption: enabled
- Trust server certificate: `true`

From inside another devcontainer, use:

- Host: `host.containers.internal,14333`

## Example VS Code MSSQL Connection

- Server: `localhost,14333`
- Authentication: SQL Login
- User name: `sa`
- Password: value from your local `.env`
- Database: leave blank initially
- Encrypt: `true`
- Trust server certificate: `true`

## Notes

- Image: `mcr.microsoft.com/mssql/server:2022-latest`
- Edition: `Developer`
- Persistent storage: Podman volume `mssql-dev-data` by default
- Container name: `mssql-dev` by default

## Direct Run Alternative

If you do not want to source `.env`, you can run:

```sh
MSSQL_SA_PASSWORD='ReplaceMeWithAStrongPassword!' ./scripts/up.sh
```

## Tear Down

```sh
./scripts/down.sh
```

To remove persisted data too:

```sh
MSSQL_PURGE_DATA=1 ./scripts/down.sh
```

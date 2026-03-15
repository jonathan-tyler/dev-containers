# Dev Containers

Reusable Podman-based development container assets and one host-run SQL Server asset.

## Resources

- 🧱 [dev-base](./dev-base): base image and local registry bootstrap.
- 🐹 [golang-dev](./golang-dev): Go devcontainer image.
- 🐍 [python-dev](./python-dev): Python devcontainer image.
- 🔷 [dotnet-dev](./dotnet-dev): .NET devcontainer image.
- 🗄️ [mssql-dev](./mssql-dev): host-managed SQL Server container.

## Usage

Each image build script ensures a local registry is running at `localhost:5000`, builds the image, tags it, and pushes it there.

```sh
./dev-base/build.sh [tag]
./golang-dev/build.sh [tag]
./python-dev/build.sh [tag]
./dotnet-dev/build.sh [tag]
```

Use the matching `devcontainer.json` from a consuming repository.

For work on this repository itself, use the root [`.devcontainer/devcontainer.json`](./.devcontainer/devcontainer.json). Its build assets live under [`.devcontainer/base`](./.devcontainer/base), and the container includes the VS Code Markdown lint extension plus the `markdownlint-cli2` command.

`mssql-dev` is separate from the devcontainer flow. See [mssql-dev/README.md](./mssql-dev/README.md).
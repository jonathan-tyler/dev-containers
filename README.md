# Dev Containers

Reusable Podman-based development container assets and one host-run SQL Server asset.

## Resources

- 🧱 [dev-base](./dev-base): base image and local registry bootstrap.
- 🐹 [golang-dev](./golang-dev): Go devcontainer image.
- 🐍 [python-dev](./python-dev): Python devcontainer image.
- 🔷 [dotnet-dev](./dotnet-dev): .NET devcontainer image.
- 🗄️ [mssql-dev](./mssql-dev): host-managed SQL Server container.

## Usage

Image builds are orchestrated by a single Podman-native build graph in `images.manifest`, driven by `./build-images.sh`. It will inspect git changes, rebuild the affected images, rebuild dependent children automatically, push both `latest` and a semver tag, and update any tracked `devcontainer.json` image references.

The script requires the `podman` CLI to be available on `PATH`.

```sh
./build-images.sh --version 1.0.4
```

Manifest dependencies use `image-name:BUILD_ARG_NAME` entries, so child `Containerfile` images can inherit parent version tags without hard-coded script logic.

Default change detection maps git changes back to image contexts. A change inside an image directory selects that image, then the graph expands to required ancestors and dependent children. Changes to shared graph files like `images.manifest` or `build-images.sh` select all images. If there are no image-affecting changes, the script exits cleanly without building anything.

Use the matching `devcontainer.json` from a consuming repository.

For work on this repository itself, use the root [`.devcontainer/devcontainer.json`](./.devcontainer/devcontainer.json). It now pulls the locally published [dev-base](./dev-base) image from the local registry, and `./build-images.sh` syncs that devcontainer reference to the current semver tag.

`mssql-dev` is separate from the devcontainer flow. See [mssql-dev/README.md](./mssql-dev/README.md).
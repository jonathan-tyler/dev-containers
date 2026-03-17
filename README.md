# Dev Containers

Reusable Podman-based development container assets and one host-run SQL Server asset.

## Resources
- 📦 [local-registry](./local-registry): local registry install and systemd bootstrap.
- 🧱 [dev-containers/dev-base](./dev-containers/dev-base): base image and local registry bootstrap.
- 🐹 [dev-containers/golang-dev](./dev-containers/golang-dev): Go devcontainer image.
- 🐍 [dev-containers/python-dev](./dev-containers/python-dev): Python devcontainer image.
- 🔷 [dev-containers/dotnet-dev](./dev-containers/dotnet-dev): .NET devcontainer image.
- 🗄️ [sidecars/mssql-dev](./sidecars/mssql-dev): host-managed SQL Server container.

## Usage

- To set up the local registry, run `./local-registry/install.sh`. It creates or starts the registry container and enables a lingering systemd user service so it comes back automatically.
- To build and publish images, run `./local-registry/build-images.sh --version X.Y.Z`.
- To reference a published image from a consuming repository, see the `devcontainer.json` examples in `./.devcontainer/devcontainer.json`, `./dev-containers/golang-dev/devcontainer.json`, and `./dev-containers/python-dev/devcontainer.json`.

`mssql-dev` is separate from the devcontainer flow. See [sidecars/mssql-dev/README.md](./sidecars/mssql-dev/README.md).

## Notes

- The workspace dev container mounts the host Podman socket so image build and container registry tasks can run inside a more isolated tooling environment, with the understanding that this weakens the isolation a devcontainer would normally provide. This is a repo-specific convenience, not a recommended general pattern.

## Troubleshooting

### VS Code rewrites `localhost:5000` image references

If a `devcontainer.json` uses `localhost:5000/...` with `updateRemoteUserUID` enabled, Dev Containers can rewrite that image name to `localhost/localhost:5000/...` during the temporary UID-adjustment build. Podman then rejects the rewritten reference.

Use `127.0.0.1:5000/...` instead.
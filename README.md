# Dev Containers

Reusable Podman-based development container assets and one host-run SQL Server asset.

## Resources
- 📦 [local-registry](./local-registry): local registry install and systemd bootstrap.
- 🧱 [dev-base](./containers/images/dev-base): base image and local registry bootstrap.
- 🛠️ [monolith-dev](./containers/images/monolith-dev): polyglot devcontainer image for mixed workspace development.
- 🐹 [golang-dev](./containers/images/golang-dev): Go devcontainer image.
- 🟢 [javascript-dev](./containers/images/javascript-dev): JavaScript devcontainer image.
- 🐍 [python-dev](./containers/images/python-dev): Python devcontainer image.
- 🔷 [typescript-dev](./containers/images/typescript-dev): TypeScript devcontainer image layered on the JavaScript dev image.
- 🔷 [dotnet-dev](./containers/images/dotnet-dev): .NET devcontainer image.
- 🗄️ [sidecars/mssql-dev](./sidecars/mssql-dev): host-managed SQL Server container.
- 📨 [sidecars/smtp4dev](./sidecars/smtp4dev): host-managed smtp4dev container.

## Usage

- To set up the local registry, run `./local-registry/install.sh`. It creates or starts the registry container and enables a lingering systemd user service so it comes back automatically.
- To build and publish images, run `./local-registry/build-images.sh --version X.Y.Z`.

## Shared Toolchains

- Focused images and `monolith-dev` both consume these scripts so version pins and install behavior stay aligned.
- Keep image-specific policy in the image `Containerfile`; keep toolchain installation details in the shared scripts.
- Keep shared images generic: install tools and shell capability there, but apply personal dotfiles and prompt config at devcontainer runtime instead of baking host-specific files into image builds.

`mssql-dev` and `smtp4dev` are separate from the devcontainer flow. See [sidecars/mssql-dev/README.md](./sidecars/mssql-dev/README.md) and [sidecars/smtp4dev/README.md](./sidecars/smtp4dev/README.md).

## Notes

- The workspace dev container mounts the host Podman socket so image build and container registry tasks can run inside a more isolated tooling environment, with the understanding that this weakens the isolation a devcontainer would normally provide. This is a repo-specific convenience, not a recommended general pattern.

## Troubleshooting

### VS Code rewrites `localhost:5000` image references

If a `devcontainer.json` uses `localhost:5000/...` with `updateRemoteUserUID` enabled, Dev Containers can rewrite that image name to `localhost/localhost:5000/...` during the temporary UID-adjustment build. Podman then rejects the rewritten reference.

Use `127.0.0.1:5000/...` instead.
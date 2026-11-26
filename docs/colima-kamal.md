# Trying Colima with Kamal on macOS

Colima was installed through Homebrew and started on demand on an Apple Silicon
Mac after Docker Desktop's registry login failed during a local Kamal deploy.
Use the same VM settings to compare Colima with Docker Desktop on another
Apple Silicon Mac.

Colima runs Docker Engine inside a Lima-managed Linux VM. The Docker CLI uses a
context to select the engine. Each engine has its own containers, images, and
named volumes. Keep Docker Desktop installed for the trial and rebuild or pull
any images you need in Colima. Export and restore data explicitly if a test
needs a volume from Docker Desktop. [Colima Docker runtime](https://colima.run/docs/runtimes/#docker) ·
[Docker Desktop data](https://docs.docker.com/desktop/settings-and-maintenance/backup-and-restore/)

## Start Colima alongside Docker Desktop

These settings match the existing VM's Docker runtime, Apple Virtualization
framework (`vz`), VirtioFS mounts, 4 CPUs, 8 GiB RAM, and 60 GiB disk. Kubernetes
and Rosetta are off. The trial disables automatic Docker context selection and
the generated SSH config entry. Use the Docker CLI that comes with Docker
Desktop for the trial. [Colima installation](https://colima.run/docs/installation/) ·
[Colima start options](https://colima.run/docs/commands/#colima-start)

```sh
docker context show
brew install colima
colima start --runtime docker --vm-type vz --mount-type virtiofs \
  --cpus 4 --memory 8 --disk 60 --activate=false --ssh-config=false --save-config
```

On the first start, Colima provisions the VM and adds the `colima` Docker
context. `docker context show` should still report the context you saw before
installing. Use `--context colima` for individual commands. The default profile
is stored at `~/.colima/default/colima.yaml`.
[Colima configuration](https://colima.run/docs/configuration/) ·
[Docker contexts](https://docs.docker.com/engine/manage-resources/contexts/)

```sh
colima status
docker context show
docker --context colima info
docker --context colima compose version
docker --context colima buildx version
```

For a standalone Homebrew setup, install `docker`, `docker-compose`, and
`docker-buildx`. If the Docker CLI cannot find the plugins, add the Homebrew
plugin directory to `cliPluginsExtraDirs` in `~/.docker/config.json`, or in
`$DOCKER_CONFIG/config.json` if you set `DOCKER_CONFIG`. Use the absolute output
of `brew --prefix` followed by `/lib/docker/cli-plugins`. Preserve the other
Docker settings, including the credential helper. [Compose formula](https://formulae.brew.sh/formula/docker-compose) ·
[Buildx formula](https://formulae.brew.sh/formula/docker-buildx)

## Check the build path Kamal uses

From the app checkout, use the Kamal version pinned in the project's Gemfile
if it has one. Compare `build details` with and without the command-scoped
Docker context. The command lists the build setup without deploying the app.
[Kamal build commands](https://kamal-deploy.org/docs/commands/build/) ·
[Docker context selection](https://docs.docker.com/engine/manage-resources/contexts/)

```sh
bundle exec kamal build details
DOCKER_CONTEXT=colima bundle exec kamal build details
```

Kamal can use a named Buildx builder tied to a specific Docker endpoint. For
example, Kamal 2.12 creates a named builder for the `docker-container` driver
and passes its name to `docker buildx build`. Check where the builder's nodes
point. An existing Desktop-backed builder can keep building there even when
`DOCKER_CONTEXT=colima` selects Colima for regular Docker commands. A project
with `builder.remote` or a cloud builder can send some or all builds elsewhere.
[Kamal builder configuration](https://kamal-deploy.org/docs/configuration/builders/) ·
[Kamal Buildx invocation](https://github.com/basecamp/kamal/blob/v2.12.0/lib/kamal/commands/builder/base.rb) ·
[Docker builders](https://docs.docker.com/build/builders/)

To test the Colima daemon and its default builder independently of the app and
its registry, build a small image from public Alpine. Use the platform
configured under the project's `builder.arch`. The example uses `linux/amd64`
to exercise cross-architecture execution on Apple Silicon. The build's `RUN`
step should print `x86_64` for that platform. Repeat with your Docker Desktop
context to compare the same build on both engines. [Docker multi-platform builds](https://docs.docker.com/build/building/multi-platform/)

```sh
env -u BUILDX_BUILDER docker --context colima build \
  --platform linux/amd64 --progress=plain \
  --tag colima-kamal-smoke:local - <<'DOCKERFILE'
FROM alpine:3
RUN uname -m
DOCKERFILE
```

If the original issue recurs, record the failing command, error, Docker context,
Buildx builder endpoint, and target architecture. Check which step failed before
retrying a deploy. `kamal build push` publishes to the configured registry by
default, and `kamal deploy` also updates the configured servers.
[Kamal build commands](https://kamal-deploy.org/docs/commands/build/) ·
[Kamal deploy](https://kamal-deploy.org/docs/commands/deploy/)

## Check registry login if the failure returns

The Kamal failure that prompted the switch to Colima was
`error: cannot perform an interactive login from a non-TTY device` during
`docker login` in the build-and-push phase. The local run failed while CI worked.
At the time, Docker was configured to use Docker Desktop's credential store
(`credsStore: desktop`). The exact cause of the login failure remains unverified.

Run these checks from the same shell that runs Kamal. The first command reports
only helper names. The second checks whether the Desktop helper is on `PATH`
when `desktop` is configured. Docker can use a registry-specific `credHelpers`
entry ahead of `credsStore`. The selected Docker context and credential helper
are separate settings. [Docker credential stores and helpers](https://docs.docker.com/reference/cli/docker/login/#credential-stores)

```sh
jq '{credsStore, registryHelpers: ((.credHelpers // {}) | [.[]] | unique)}' \
  "${DOCKER_CONFIG:-$HOME/.docker}/config.json"
command -v docker-credential-desktop
```

If `docker login` fails, check that Kamal resolves both the registry username
and its password or token to non-empty values in that shell. Docker may fall
back to an interactive prompt when an input is missing. Keep the values out of
the diagnostic output. [Kamal registry configuration](https://kamal-deploy.org/docs/configuration/docker-registry/) ·
[Non-interactive Docker login](https://docs.docker.com/reference/cli/docker/login/#provide-a-password-using-stdin-password-stdin)

## End the trial

Run `colima stop` to shut down the VM and keep its data. Start it again with
`colima start --activate=false` to continue the comparison. If you changed the
global Docker context manually, use `docker context use` with the original name
you recorded. [Colima stop](https://colima.run/docs/commands/#colima-stop) ·
[Docker contexts](https://docs.docker.com/engine/manage-resources/contexts/)

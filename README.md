# virtualinstall

Small Docker-based builder for creating virtual Debian packages that only carry dependencies.

Example output name:
- `default-a1b2c3-virtual.deb`

That package can depend on any list you provide, for example:
- `git ncdu lsd curl wget duf`

## Files

- `Dockerfile`: container image for package building.
- `build.sh`: host command wrapper that runs Docker and writes output to host.
- `docker-build.sh`: in-container builder that validates packages and builds the dependency-only `.deb`.

## Build The Image

```bash
docker build -t virtualinstall:latest .
```

## Build A Virtual Package (As Command)

```bash
chmod +x ./build.sh
./build.sh create default -- git ncdu lsd curl wget duf
```

This writes a file like:
- `./out/default-xxxxxx-virtual.deb`

Build and install immediately:

```bash
./build.sh install default -- git ncdu lsd curl wget duf
```

Optional custom output directory:

```bash
./build.sh create default --output-dir ./packages -- git ncdu lsd curl wget duf
```

Remove installed virtual package by tag:

```bash
./build.sh remove default
```

Optional command install to PATH:

```bash
sudo install -m 0755 ./build.sh /usr/local/bin/apt-tag-build
apt-tag-build install default -- git ncdu lsd curl wget duf
```

## Install The Generated Package

```bash
sudo apt install -y ./out/default-xxxxxx-virtual.deb
```

## Project Ideas

- Add helper shell alias for `build.sh create|install|remove`.
- Add lockfile support so tags are reproducible and auditable.
- Add optional signing of generated `.deb` files for trusted internal repos.
- Add CI pipeline to publish generated virtual packages to an apt repository.
- Add JSON output mode for tooling integration.

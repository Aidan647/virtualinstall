# virtualinstall

`virtualinstall` creates small virtual Debian packages (`.deb`) that only carry dependency metadata.

Generated package format:
- `<name>-<hash6>-virtual.deb`

Example:
- `default-07ad2c-virtual.deb`

## Install

One-liner installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Aidan647/virtualinstall/refs/heads/master/install.sh | bash
```

Non-interactive installer examples:

```bash
INSTALL_SHELL_CHOICE=1 curl -fsSL https://raw.githubusercontent.com/Aidan647/virtualinstall/refs/heads/master/install.sh | bash
INSTALL_SHELL_CHOICE=3 INSTALL_CUSTOM_RC=~/.config/fish/config.fish curl -fsSL https://raw.githubusercontent.com/Aidan647/virtualinstall/refs/heads/master/install.sh | bash
```

`INSTALL_SHELL_CHOICE` values:
- `1`: bash (`~/.bashrc`)
- `2`: zsh (`~/.zshrc`)
- `3`: other custom rc file (requires `INSTALL_CUSTOM_RC`)
- `4`: bash + zsh

Installer behavior:
- Clones or updates the repo at `~/.local/share/virtualinstall`
- Installs launcher at `~/.local/bin/virtualinstall`
- Prompts which rc file(s) to update (`bash`, `zsh`, `other`, or `all`)
- Appends a managed rc block for PATH + launcher alias

## Commands

Use `virtualinstall --help` for full help.

Create package only:

```bash
virtualinstall create default -- git ncdu lsd curl wget duf
```

Create and install package:

```bash
virtualinstall install default -- git ncdu lsd curl wget duf
```

Remove installed package by tag name:

```bash
virtualinstall remove default
```

If multiple packages exist for the same name, `remove` will show a selection menu with:
- package name
- dependencies

List installed virtual tags:

```bash
virtualinstall list
virtualinstall list default
```

Clean generated `.deb` files from output directory:

```bash
virtualinstall clean
virtualinstall clean --output-dir ./out
```

## Options

- `--output-dir <dir>`: output directory for generated `.deb` files
- `--apt-cmd <cmd>`: override package manager command used by `install`/`remove`

APT command selection default order:
1. `apt-fast`
2. `apt`
3. `apt-get`

## Notes

- Command entrypoint: `build.sh`
- Requirements: `dpkg-deb`, `apt-cache`, `sha256sum`, `sed`, `tr`, `mktemp` (found in dpkg, apt, coreutils)
- Tag files are installed in `/var/lib/virtualinstall/tags/`
- Repeated `create`/`install` with same input reuses existing artifact when available

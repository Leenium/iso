# Leenium ISO

The Leenium ISO streamlines [the installation of Leenium](https://leenium.drunkleen.com). It includes the Leenium Configurator as a front-end to archinstall and automatically launches the [Leenium Installer](https://github.com/leenium/installer.git) after base arch has been setup.

## Downloading the latest ISO

See the ISO link on [leenium.drunkleen.com](https://leenium.drunkleen.com).

## Creating the ISO

Build from the `iso/` directory:

```bash
cd iso
./bin/leenium-iso-make
```

What this does:

- Initializes the required git submodules
- Builds the ISO inside Docker
- Writes the finished ISO into `iso/release/`
- Renames the file to include the installer ref, such as `leenium-<date>-x86_64-master.iso`
- Offers to boot the ISO when the build finishes

Requirements:

- `docker`
- `git`
- `gum` (used for the post-build boot prompt)

Useful options:

- `--no-cache` disables the daily build cache
- `--no-boot-offer` skips the interactive boot prompt after the build
- `--local-source` uses a local installer checkout instead of cloning from Git

Example:

```bash
cd iso
./bin/leenium-iso-make --no-boot-offer
```

To build from a local installer checkout:

```bash
cd iso
LEENIUM_PATH=/path/to/installer ./bin/leenium-iso-make --local-source
```

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `LEENIUM_INSTALLER_REPO` - Git URL for the installer (default: `https://github.com/leenium/installer.git`)
- `LEENIUM_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)
- `LEENIUM_STABLE_MIRROR_URL` - Arch package mirror used for `core`, `extra`, and `multilib`
- `LEENIUM_PACKAGE_REPO_URL` - Leenium package repository URL

Example usage:
```bash
LEENIUM_INSTALLER_REPO="https://github.com/myuser/installer.git" LEENIUM_INSTALLER_REF="some-feature" ./bin/leenium-iso-make
```

If the default Leenium package hosts are unavailable, you can point the build at different mirrors:

```bash
LEENIUM_STABLE_MIRROR_URL="https://your-mirror.example/\$repo/os/\$arch" \
LEENIUM_PACKAGE_REPO_URL="https://your-packages.example/stable/\$arch" \
./bin/leenium-iso-make
```

## Testing the ISO

Run `./bin/leenium-iso-boot [release/leenium.iso]`.

## Signing the ISO

Run `./bin/leenium-iso-sign [gpg-user] [release/leenium.iso]`.

## Uploading the ISO

Run `./bin/leenium-iso-upload [release/leenium.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/leenium-iso-release` to create, test, sign, and upload the ISO in one flow.

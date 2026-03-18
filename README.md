# Leenium ISO

This repo builds the bootable Leenium ISO.

Its job is to produce the install image, not to define the full desktop payload. The actual system layer lives in the companion installer repo at [github.com/leenium/installer](https://github.com/leeniumos/leenium), which this repo fetches or mounts during the build.

Leenium is a fork of [Omarchy](https://github.com/basecamp/omarchy).

## What The ISO Does

The Leenium ISO packages:

- the ArchISO build configuration
- Leenium boot and installer assets
- the logic to pull in a specific installer repo/ref
- release helpers for booting, signing, and uploading finished ISOs

The resulting ISO is intended to streamline installation of Leenium by combining an Arch-based base install flow with the Leenium installer payload.

## Main Commands

All primary workflows live under [`bin/`](./bin):

- `leenium-iso-make`: build an ISO
- `leenium-iso-boot`: boot a built ISO locally
- `leenium-iso-sign`: sign a finished ISO
- `leenium-iso-upload`: upload a release artifact
- `leenium-iso-release`: make, sign, and upload in one flow
- `leenium-vm`: local VM helper

## Building An ISO

Run from the `iso/` repo root:

```bash
./bin/leenium-iso-make
```

What it does:

1. Initializes git submodules.
2. Prepares a local `release/` directory.
3. Runs the ArchISO build inside Docker.
4. Pulls in the Leenium installer repo at the requested ref.
5. Writes the finished ISO into `release/`.
6. Renames the artifact to include the installer ref.
7. Optionally offers to boot the result.

Typical output looks like:

```text
release/leenium-YYYY-MM-DD-x86_64-<installer-ref>.iso
```

## Requirements

To build locally you need:

- `docker`
- `git`
- `gum` for the interactive post-build boot prompt

If Docker cannot run privileged containers on the host, the build will fail.

## Useful Options

`leenium-iso-make` supports:

- `--no-cache`: disable the daily package cache
- `--no-boot-offer`: skip the interactive boot prompt after build
- `--local-source`: use a local installer checkout instead of cloning from Git

Example:

```bash
./bin/leenium-iso-make --no-boot-offer
```

## Building Against A Local Installer Checkout

To test ISO changes together with local installer changes:

```bash
LEENIUM_PATH=/path/to/installer ./bin/leenium-iso-make --local-source
```

This mounts your local installer repo into the build container instead of cloning from the default upstream source.

## Environment Variables

The build can be pointed at different installer repos, refs, and package mirrors.

- `LEENIUM_INSTALLER_REPO`: installer Git URL
- `LEENIUM_INSTALLER_REF`: installer branch or tag
- `LEENIUM_STABLE_MIRROR_URL`: Arch mirror for `core`, `extra`, and `multilib`
- `LEENIUM_PACKAGE_REPO_URL`: Leenium package repo URL

Example:

```bash
LEENIUM_INSTALLER_REPO="https://github.com/leeniumos/leenium.git" \
LEENIUM_INSTALLER_REF="some-feature" \
./bin/leenium-iso-make
```

If you need alternate package hosting:

```bash
LEENIUM_STABLE_MIRROR_URL="https://your-mirror.example/\$repo/os/\$arch" \
LEENIUM_PACKAGE_REPO_URL="https://your-packages.example/stable/\$arch" \
./bin/leenium-iso-make
```

## Testing, Signing, And Releasing

Boot a built ISO:

```bash
./bin/leenium-iso-boot release/<iso-name>.iso
```

Sign a built ISO:

```bash
./bin/leenium-iso-sign [gpg-user] release/<iso-name>.iso
```

Upload a built ISO:

```bash
./bin/leenium-iso-upload release/<iso-name>.iso
```

This requires `rclone` to be configured first.

Run the release flow:

```bash
./bin/leenium-iso-release <version>
```

That flow rebuilds the master ISO, signs it, computes the SHA256, renames it for release, and uploads it.

## Repo Layout

- `archiso/`: ArchISO sources
- `configs/`: bootloader and airootfs configuration
- `builder/`: containerized build scripts
- `bin/`: developer and release commands
- `plans/`: install/release planning notes

## Relationship to the Installer Repo

This repo builds the image.

The installer repo at [github.com/leenium/installer](https://github.com/leeniumos/leenium) defines what Leenium actually becomes once installation runs. In practice:

- `iso/` is the delivery mechanism
- `installer/` is the system payload

## Downloading A Release

For published ISO downloads, use the links from [leenium.drunkleen.com](https://leenium.drunkleen.com).

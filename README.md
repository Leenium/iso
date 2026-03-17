# Leenium ISO

The Leenium ISO streamlines [the installation of Leenium](https://leenium.drunkleen.com). It includes the Leenium Configurator as a front-end to archinstall and automatically launches the [Leenium Installer](https://github.com/Leenium/installer.git) after base arch has been setup.

## Downloading the latest ISO

See the ISO link on [leenium.drunkleen.com](https://leenium.drunkleen.com).

## Creating the ISO

Run `./bin/leenium-iso-make` and the output goes into `./release`. Use `--local-source` to build from your current local installer checkout instead of cloning the installer repo.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `LEENIUM_INSTALLER_REPO` - Git URL for the installer (default: `https://github.com/Leenium/installer.git`)
- `LEENIUM_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)

Example usage:
```bash
LEENIUM_INSTALLER_REPO="https://github.com/myuser/installer.git" LEENIUM_INSTALLER_REF="some-feature" ./bin/leenium-iso-make
```

## Testing the ISO

Run `./bin/leenium-iso-boot [release/leenium.iso]`.

## Signing the ISO

Run `./bin/leenium-iso-sign [gpg-user] [release/leenium.iso]`.

## Uploading the ISO

Run `./bin/leenium-iso-upload [release/leenium.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/leenium-iso-release` to create, test, sign, and upload the ISO in one flow.

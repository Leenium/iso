#!/bin/bash

set -euo pipefail

LEENIUM_STABLE_MIRROR_URL="${LEENIUM_STABLE_MIRROR_URL:-https://geo.mirror.pkgbuild.com/\$repo/os/\$arch}"
LEENIUM_PACKAGE_REPO_URL="${LEENIUM_PACKAGE_REPO_URL:-https://pkg.drunkleen.com/stable/\$arch}"
PACMAN_ONLINE_CONFIG="/tmp/pacman-online-stable.conf"
PACMAN_BOOTSTRAP_CONFIG="/tmp/pacman-bootstrap-local.conf"
LOG_DIR="${LEENIUM_ISO_LOG_DIR:-/tmp/leenium-iso-logs}"
mkdir -p "$LOG_DIR"

if [[ -t 1 || "${FORCE_COLOR:-0}" == "1" ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_BLUE=$'\033[38;5;39m'
  C_CYAN=$'\033[38;5;45m'
  C_GREEN=$'\033[38;5;42m'
  C_AMBER=$'\033[38;5;214m'
  C_RED=$'\033[38;5;196m'
else
  C_RESET=''
  C_DIM=''
  C_BOLD=''
  C_BLUE=''
  C_CYAN=''
  C_GREEN=''
  C_AMBER=''
  C_RED=''
fi

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

section() {
  printf '\n%s%s== %s ==%s\n' "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"
}

info() {
  printf '%s[%s] INFO%s %s\n' "$C_CYAN" "$(timestamp)" "$C_RESET" "$1"
}

ok() {
  printf '%s[%s] OK%s %s\n' "$C_GREEN" "$(timestamp)" "$C_RESET" "$1"
}

warn() {
  printf '%s[%s] WARN%s %s\n' "$C_AMBER" "$(timestamp)" "$C_RESET" "$1"
}

fail() {
  printf '%s[%s] ERROR%s %s\n' "$C_RED" "$(timestamp)" "$C_RESET" "$1" >&2
}

run_logged() {
  local label="$1"
  shift

  local logfile="$LOG_DIR/${label//[^a-zA-Z0-9_.-]/_}.log"
  info "$label"
  if "$@" >"$logfile" 2>&1; then
    ok "$label"
  else
    fail "$label"
    printf '%sLog:%s %s\n' "$C_DIM" "$C_RESET" "$logfile" >&2
    sed -n '1,220p' "$logfile" >&2
    exit 1
  fi
}

replace_in_file() {
  local file="$1"
  local from="$2"
  local to="$3"

  local from_escaped
  local to_escaped

  from_escaped=$(printf '%s' "$from" | sed 's/[][\\/.*^$+?|(){}-]/\\&/g')
  to_escaped=$(printf '%s' "$to" | sed 's/[\\/&]/\\&/g')

  sed -i "s/${from_escaped}/${to_escaped}/g" "$file"
}

first_value_after_marker() {
  local marker="$1"
  local file="$2"

  awk -v marker="$marker" '
    $0 == marker { getline; print; exit }
  ' "$file"
}

cp /configs/pacman-online-stable.conf "$PACMAN_ONLINE_CONFIG"
cp /configs/pacman-online-stable.conf "$PACMAN_BOOTSTRAP_CONFIG"
replace_in_file \
  "$PACMAN_ONLINE_CONFIG" \
  'https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"
replace_in_file \
  "$PACMAN_ONLINE_CONFIG" \
  'https://pkg.drunkleen.com/stable/$arch' \
  "$LEENIUM_PACKAGE_REPO_URL"
replace_in_file \
  "$PACMAN_BOOTSTRAP_CONFIG" \
  'https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"
replace_in_file \
  "$PACMAN_BOOTSTRAP_CONFIG" \
  'https://pkg.drunkleen.com/stable/$arch' \
  "$LEENIUM_PACKAGE_REPO_URL"
replace_in_file \
  "$PACMAN_BOOTSTRAP_CONFIG" \
  'LocalFileSigLevel = Optional' \
  'LocalFileSigLevel = Never'

section "Prepare Build Environment"
info "Detailed step logs: $LOG_DIR"
info "Stable mirror: ${LEENIUM_STABLE_MIRROR_URL//\$repo\/os\/\$arch/<repo>}"
info "Leenium repo: ${LEENIUM_PACKAGE_REPO_URL//\$arch/$(uname -m)}"

# Note that these are packages installed to the Arch container used to build the ISO.
run_logged "Initialize pacman keyring" pacman-key --init
run_logged "Install archlinux-keyring" pacman --noconfirm --noprogressbar -Sy archlinux-keyring
run_logged "Install ISO build dependencies" pacman --noconfirm --noprogressbar -Sy archiso git sudo base-devel jq grub

# Bootstrap leenium-keyring from a local package file before using the repo normally.
# This avoids the chicken-and-egg problem of requiring the Leenium public key
# before the keyring package that installs that key can be trusted.
isolated_pacman_cache="/tmp/pacman-pkg-cache"
mkdir -p "$isolated_pacman_cache"
rm -f "$isolated_pacman_cache"/leenium-keyring-*.pkg.tar.*

repo_arch="$(uname -m)"
leenium_repo_bootstrap_url="${LEENIUM_PACKAGE_REPO_URL//\$arch/$repo_arch}"
leenium_db_url="${leenium_repo_bootstrap_url%/}/leenium.db.tar.gz"
leenium_db_extract_dir="$(mktemp -d /tmp/leenium-db.XXXXXX)"

section "Bootstrap Leenium Keyring"
info "Fetching repo database"
run_logged "Download leenium.db.tar.gz" curl -fsSL "$leenium_db_url" -o "$leenium_db_extract_dir/leenium.db.tar.gz"
run_logged "Extract leenium.db.tar.gz" tar -xzf "$leenium_db_extract_dir/leenium.db.tar.gz" -C "$leenium_db_extract_dir"

leenium_keyring_desc="$(find "$leenium_db_extract_dir" -path '*/leenium-keyring-*/desc' | head -n1)"
if [[ -z "$leenium_keyring_desc" ]]; then
  fail "Could not find leenium-keyring metadata in $leenium_db_url"
  exit 1
fi

leenium_keyring_filename="$(first_value_after_marker '%FILENAME%' "$leenium_keyring_desc")"
leenium_keyring_sha256="$(first_value_after_marker '%SHA256SUM%' "$leenium_keyring_desc")"
leenium_keyring_package="$isolated_pacman_cache/$leenium_keyring_filename"

if [[ -z "$leenium_keyring_filename" || -z "$leenium_keyring_sha256" ]]; then
  fail "Could not parse leenium-keyring filename or SHA256 from repo database"
  exit 1
fi

info "Resolved keyring package: $leenium_keyring_filename"
run_logged "Download leenium-keyring package" curl -fsSL "${leenium_repo_bootstrap_url%/}/$leenium_keyring_filename" -o "$leenium_keyring_package"
run_logged "Verify leenium-keyring checksum" bash -lc "echo '$leenium_keyring_sha256  $leenium_keyring_package' | sha256sum -c -"
run_logged "Install leenium-keyring locally" pacman --config "$PACMAN_BOOTSTRAP_CONFIG" --cachedir "$isolated_pacman_cache" --noconfirm --noprogressbar -U "$leenium_keyring_package"
run_logged "Populate leenium pacman keys" pacman-key --populate leenium

# Setup build locations
build_cache_dir="/var/cache"
offline_mirror_dir="$build_cache_dir/airootfs/var/cache/leenium/mirror/offline"
mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/

section "Prepare Archiso Workspace"

# We base our ISO on the official arch ISO (releng) config
cp -r /archiso/configs/releng/* $build_cache_dir/
rm "$build_cache_dir/airootfs/etc/motd"

# Avoid using reflector for mirror identification as we are relying on the global CDN
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"

# Bring in our configs
cp -r /configs/* $build_cache_dir/

# Setup Leenium itself
if [[ -d /leenium ]]; then
  info "Using local Leenium source from mounted workspace"
  cp -rp /leenium "$build_cache_dir/airootfs/root/leenium"
else
  leenium_repo="$LEENIUM_INSTALLER_REPO"
  if [[ $leenium_repo != http://* && $leenium_repo != https://* && $leenium_repo != git@* ]]; then
    leenium_repo="https://github.com/${leenium_repo}.git"
  fi
  info "Cloning installer repo: $leenium_repo ($LEENIUM_INSTALLER_REF)"
  run_logged "Clone Leenium installer" git clone --quiet -b "$LEENIUM_INSTALLER_REF" "$leenium_repo" "$build_cache_dir/airootfs/root/leenium"
fi

# Allow package and mirror endpoints to be overridden at build time.
replace_in_file \
  "$build_cache_dir/pacman-online-stable.conf" \
  'https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"
replace_in_file \
  "$build_cache_dir/pacman-online-stable.conf" \
  'https://pkg.drunkleen.com/stable/$arch' \
  "$LEENIUM_PACKAGE_REPO_URL"
replace_in_file \
  "$build_cache_dir/airootfs/root/configurator" \
  'https://geo.mirror.pkgbuild.com/\$repo/os/\$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"
replace_in_file \
  "$build_cache_dir/airootfs/root/leenium/default/pacman/mirrorlist-stable" \
  'https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"
replace_in_file \
  "$build_cache_dir/airootfs/root/leenium/default/pacman/pacman-stable.conf" \
  'https://pkg.drunkleen.com/stable/$arch' \
  "$LEENIUM_PACKAGE_REPO_URL"
replace_in_file \
  "$build_cache_dir/airootfs/root/leenium/boot.sh" \
  'https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  "$LEENIUM_STABLE_MIRROR_URL"

# Make log uploader available in the ISO too
mkdir -p "$build_cache_dir/airootfs/usr/local/bin/"
cp "$build_cache_dir/airootfs/root/leenium/bin/leenium-upload-log" "$build_cache_dir/airootfs/usr/local/bin/leenium-upload-log"

# Copy the Leenium Plymouth theme to the ISO
mkdir -p "$build_cache_dir/airootfs/usr/share/plymouth/themes/leenium"
cp -r "$build_cache_dir/airootfs/root/leenium/default/plymouth/"* "$build_cache_dir/airootfs/usr/share/plymouth/themes/leenium/"

# Download and verify Node.js binary for offline installation
NODE_DIST_URL="https://nodejs.org/dist/latest"

section "Stage Offline Assets"

# Get checksums and parse filename and SHA
NODE_SHASUMS=$(curl -fsSL "$NODE_DIST_URL/SHASUMS256.txt")
NODE_FILENAME=$(echo "$NODE_SHASUMS" | grep "linux-x64.tar.gz" | awk '{print $2}')
NODE_SHA=$(echo "$NODE_SHASUMS" | grep "linux-x64.tar.gz" | awk '{print $1}')
info "Resolved Node.js asset: $NODE_FILENAME"

# Download the tarball
run_logged "Download Node.js tarball" curl -fsSL "$NODE_DIST_URL/$NODE_FILENAME" -o "/tmp/$NODE_FILENAME"

# Verify SHA256 checksum
run_logged "Verify Node.js checksum" bash -lc "echo '$NODE_SHA /tmp/$NODE_FILENAME' | sha256sum -c -"

# Copy to ISO
mkdir -p "$build_cache_dir/airootfs/opt/packages/"
cp "/tmp/$NODE_FILENAME" "$build_cache_dir/airootfs/opt/packages/"

# Add our additional packages to packages.x86_64
arch_packages=(linux-t2 git gum jq openssl plymouth tzupdate leenium-keyring)
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

# Build list of all the packages needed for the offline mirror
all_packages=($(cat "$build_cache_dir/packages.x86_64"))
all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/leenium/install/leenium-base.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/leenium/install/leenium-other.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' /builder/archinstall.packages | grep -v '^$'))
package_count="${#all_packages[@]}"
info "Preparing offline mirror for $package_count package entries"

# Download all the packages to the offline mirror inside the ISO
mkdir -p /tmp/offlinedb
run_logged "Download offline mirror packages" pacman --config "$PACMAN_ONLINE_CONFIG" --noconfirm --noprogressbar -Syw "${all_packages[@]}" --cachedir "$offline_mirror_dir/" --dbpath /tmp/offlinedb
run_logged "Build offline mirror database" repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

# Create a symlink to the offline mirror instead of duplicating it.
# mkarchiso needs packages at /var/cache/leenium/mirror/offline in the container,
# but they're actually in $build_cache_dir/airootfs/var/cache/leenium/mirror/offline
mkdir -p /var/cache/leenium/mirror
ln -s "$offline_mirror_dir" "/var/cache/leenium/mirror/offline"

# Copy the offline pacman.conf to the ISO's /etc directory so the live environment uses our
# same config when booted. 
cp $build_cache_dir/pacman-offline.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# Finally, we assemble the entire ISO
section "Build ISO"
run_logged "Assemble ISO image" mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"

# Fix ownership of output files to match host user
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    chown -R "$HOST_UID:$HOST_GID" /out/
fi

latest_iso=$(ls -t /out/*.iso 2>/dev/null | head -n1 || true)
if [[ -n "$latest_iso" ]]; then
  section "Done"
  ok "ISO created: $latest_iso"
else
  warn "Build finished, but no ISO was found in /out"
fi

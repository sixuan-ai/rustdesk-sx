#!/usr/bin/env bash
# Isolate the GTK 3.24.52 AT-SPI listener lifetime fix to the dev client.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dev_root="${RUSTDESK_DEV_ROOT:-$HOME/.local/share/rustdesk-dev}"
version=3.24.52
prefix="$dev_root/gtk-$version-a11y-e6372d29"
work="$dev_root/gtk-build-$version-a11y"
archive="${XDG_CACHE_HOME:-$HOME/.cache}/rustdesk-dev/gtk-$version.tar.xz"
jobs="${RUSTDESK_BUILD_JOBS:-4}"
[[ "$jobs" =~ ^[1-6]$ ]] || { echo 'RUSTDESK_BUILD_JOBS must be 1..6' >&2; exit 1; }
mkdir -p "$(dirname "$archive")" "$work"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 --output "$archive.part" \
    "https://download.gnome.org/sources/gtk/3.24/gtk-$version.tar.xz"
  mv "$archive.part" "$archive"
fi
printf '%s  %s\n' 80931fa472a77b9a164f6740e3c0b444fac6770054632d35a7ff9d679e5e7b9f "$archive" | sha256sum --check -
source_dir="$work/gtk-$version"
if [[ ! -d "$source_dir" ]]; then
  tar -xf "$archive" -C "$work"
  patch --directory="$source_dir" --strip=1 \
    < "$repo/res/dev/patches/gtk3-a11y-listener-lifetime.patch"
fi
meson setup "$work/build" "$source_dir" --prefix="$prefix" --libdir=lib \
  --buildtype=release -Dintrospection=false -Dgtk_doc=false -Dman=false \
  -Ddemos=false -Dexamples=false -Dtests=false -Dinstalled_tests=false \
  -Dprint_backends=file
meson compile -C "$work/build" -j "$jobs"
meson install -C "$work/build" --no-rebuild
printf 'GTK 3.24.52 + upstream e6372d2923d04bb2bdc88fa526ca57704ca2664a\n' > "$prefix/RUSTDESK-GTK-FIX"
printf 'Isolated GTK installed at %s\n' "$prefix"

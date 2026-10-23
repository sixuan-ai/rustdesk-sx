#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mode="${RUSTDESK_DEV_BUILD_MODE:-debug}"
case "$mode" in
  debug|release) ;;
  *) echo 'RUSTDESK_DEV_BUILD_MODE must be debug or release' >&2; exit 1 ;;
esac
bundle="$PWD/flutter/build/linux/x64/$mode/bundle/rustdesk"
[[ -x "$bundle" ]] || { echo 'Run res/dev/build_linux.sh first' >&2; exit 1; }

# Prefer the native session backend. An explicit override remains useful for
# diagnosing XWayland regressions without changing the desktop session.
backend="${RUSTDESK_GDK_BACKEND:-}"
if [[ -z "$backend" ]]; then
  if [[ -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == wayland ]]; then
    backend=wayland
  else
    backend=x11
  fi
fi
case "$backend" in
  wayland|x11) export GDK_BACKEND="$backend" ;;
  *) echo 'RUSTDESK_GDK_BACKEND must be wayland or x11' >&2; exit 1 ;;
esac
if [[ "$backend" == wayland && "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
  # GNOME lacks data-control; retain the existing native data-control backend
  # on other compositors rather than reducing their background-sync capability.
  export RUSTDESK_WAYLAND_CLIPBOARD="${RUSTDESK_WAYLAND_CLIPBOARD:-1}"
fi
# Let native Wayland negotiate per-monitor scaling. Keep the old scale override
# on the X11 compatibility path, where it was needed on the development host.
if [[ -n "${RUSTDESK_GDK_SCALE:-}" ]]; then
  export GDK_SCALE="$RUSTDESK_GDK_SCALE"
elif [[ "$backend" == x11 ]]; then
  export GDK_SCALE=1 GDK_DPI_SCALE=1
fi
# Ubuntu's GTK 3.24.52 can crash when the last AT-SPI client disconnects
# during a key event. Use the locally built upstream fix only for that ABI;
# a newer distro GTK automatically returns to the normal system library.
gtk_prefix="${RUSTDESK_DEV_GTK_PREFIX:-}"
if [[ "$gtk_prefix" == system ]]; then
  gtk_prefix=
elif [[ -z "$gtk_prefix" ]] && [[ "$(pkg-config --modversion gtk+-3.0 2>/dev/null || true)" == 3.24.52 ]]; then
  candidate="${RUSTDESK_DEV_ROOT:-$HOME/.local/share/rustdesk-dev}/gtk-3.24.52-a11y-e6372d29"
  [[ ! -f "$candidate/RUSTDESK-GTK-FIX" ]] || gtk_prefix="$candidate"
fi
if [[ -n "$gtk_prefix" ]]; then
  [[ -f "$gtk_prefix/lib/libgtk-3.so.0" ]] || { echo 'GTK override library not found' >&2; exit 1; }
  export LD_LIBRARY_PATH="$gtk_prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  # The isolated GTK build has no distro IBus/Fcitx modules. Reuse the ABI-
  # compatible system module cache instead of silently losing CJK input.
  gtk_libdir="$(pkg-config --variable=libdir gtk+-3.0)"
  gtk_abi="$(pkg-config --variable=gtk_binary_version gtk+-3.0)"
  im_cache="$gtk_libdir/gtk-3.0/$gtk_abi/immodules.cache"
  if [[ -f "$im_cache" ]]; then
    export GTK_IM_MODULE_FILE="${GTK_IM_MODULE_FILE:-$im_cache}"
  fi
  if [[ "$backend" == wayland && -z "${GTK_IM_MODULE:-}" &&
        "${XDG_CURRENT_DESKTOP:-}" == *GNOME* &&
        -f "$gtk_libdir/gtk-3.0/$gtk_abi/immodules/im-ibus.so" ]] &&
      pgrep -u "$(id -u)" -x ibus-daemon >/dev/null; then
    export GTK_IM_MODULE=ibus
  fi
fi
renderer="${RUSTDESK_DEV_RENDERER:-skia}"
case "$renderer" in
  skia) switch='enable-impeller=false' ;;
  impeller) switch='enable-impeller=true' ;;
  *) echo 'RUSTDESK_DEV_RENDERER must be skia or impeller' >&2; exit 1 ;;
esac
# Keep this local to the dev process. The latest SDK's default renderer showed
# black windows on this NVIDIA/Wayland host; keep Skia independently of backend.
count="${FLUTTER_ENGINE_SWITCHES:-0}"
[[ "$count" =~ ^[0-9]+$ ]] || exit 1
count=$((count + 1))
export "FLUTTER_ENGINE_SWITCH_$count=$switch"
export FLUTTER_ENGINE_SWITCHES="$count"
exec "$bundle" --no-server "$@"

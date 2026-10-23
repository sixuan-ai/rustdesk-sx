#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
bundle="$PWD/flutter/build/linux/x64/debug/bundle/rustdesk"
[[ -x "$bundle" ]] || { echo 'Run res/dev/build_linux.sh first' >&2; exit 1; }

export GDK_BACKEND="${RUSTDESK_GDK_BACKEND:-x11}"
export GDK_SCALE="${RUSTDESK_GDK_SCALE:-1}" GDK_DPI_SCALE=1
renderer="${RUSTDESK_DEV_RENDERER:-skia}"
case "$renderer" in
  skia) switch='enable-impeller=false' ;;
  impeller) switch='enable-impeller=true' ;;
  *) echo 'RUSTDESK_DEV_RENDERER must be skia or impeller' >&2; exit 1 ;;
esac
# Keep this local to the dev process. The latest SDK's default renderer showed
# black native windows on this NVIDIA/Wayland host; the Skia launch worked.
count="${FLUTTER_ENGINE_SWITCHES:-0}"
[[ "$count" =~ ^[0-9]+$ ]] || exit 1
count=$((count + 1))
export "FLUTTER_ENGINE_SWITCH_$count=$switch"
export FLUTTER_ENGINE_SWITCHES="$count"
exec "$bundle" --no-server "$@"

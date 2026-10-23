# Native Wayland development client — 2026-10-23

## Result and scope

The development launcher now selects native GTK Wayland in a Wayland session.
Both the main window and remote desktop window report `GdkWaylandDisplay`.
The existing Skia renderer remains the default on this NVIDIA host.
The changes stay on `codex/stable-1.5.0-dev`; publication was not requested.

Observed environment: Ubuntu 26.04.1, GNOME 50.1, Flutter 3.47.7 / Dart 3.13.5,
Rust 1.99.1, NVIDIA RTX 5060 Ti / driver 595.99.02. OMEN also ran Ubuntu
26.04.1 with a Wayland session. These are dated observations, not requirements.

## Run and rollback

```bash
res/dev/build_linux.sh
res/dev/build_gtk3_a11y_fix.sh  # needed for the observed GTK 3.24.52 crash
res/dev/run_linux.sh
```

The GTK helper needs Meson, Ninja, GTK build dependencies and network access to
GNOME's release archive. It verifies the archive SHA-256 and builds with four
jobs by default (`RUSTDESK_BUILD_JOBS=1..6`). It installs only below
`~/.local/share/rustdesk-dev/gtk-3.24.52-a11y-e6372d29`.
This host additionally installed `meson` and `python3-evdev` for the build and
manual input verification respectively; existing development dependencies were
already present.

Compatibility and diagnostic overrides:

```bash
RUSTDESK_GDK_BACKEND=x11 res/dev/run_linux.sh
RUSTDESK_DEV_GTK_PREFIX=system res/dev/run_linux.sh
```

The first restores the old XWayland UI and scale defaults. The second bypasses
the isolated GTK library (and can reintroduce the crash on the affected host).
An explicit `RUSTDESK_DEV_GTK_PREFIX=/absolute/prefix` is also supported.
Automatic GTK selection applies only when pkg-config reports 3.24.52 and the
local fix marker exists. A newer system version uses the system library.
System GTK, GNOME settings and OMEN's RustDesk service were not replaced.
Remove the isolated prefix after stopping this development client if desired.

## Crash investigation

During keyboard verification with short-lived AT-SPI clients, the unpatched
client crashed twice in system GTK 3.24.52-0ubuntu1. Both kernel fault addresses
mapped to libgtk's offset `0x215738`, while dereferencing a null list node.
Inspection of GTK's key-snooper source and the corresponding machine code
identified the accessibility listener iteration. A callback can remove the
current listener while the loop still needs its next pointer.

The app-local GTK build applies the small official upstream fix
[e6372d2923d04bb2bdc88fa526ca57704ca2664a](https://github.com/GNOME/gtk/commit/e6372d2923d04bb2bdc88fa526ca57704ca2664a),
which advances the iterator before invoking the callback. The patch preserves
upstream attribution and LGPL licensing. It does not disable accessibility.
`/proc/<client-pid>/maps` confirmed the running client loaded this isolated GTK.
This addresses the observed GTK fault; it is not a general NVIDIA crash fix.

## Verification

Commands run successfully:

```bash
res/dev/build_linux.sh
res/dev/build_gtk3_a11y_fix.sh
cd flutter
flutter test --no-pub --concurrency 2 test/companion_ui_test.dart test/quality_monitor_transport_test.dart test/server_settings_dialog_test.dart test/input_modifier_utils_test.dart test/cursor_replay_test.dart
```

The Flutter run passed all 74 tests. Shell syntax, Python parsing and
`git diff --check` were checked separately. Build/test logs and rendered frame
captures remain in `~/.cache/rustdesk-dev/`; debug logs may contain VM service
credentials and screen captures may contain private desktop content, so neither
belongs in Git or the knowledge base.

End-to-end verification used the native client over a Tailscale TCP connection
to OMEN port 21118. SSH only prepared/read temporary GTK probe windows;
test typing and clicks went through RustDesk using native uinput events.
The remote probe applications themselves used XWayland within OMEN's Wayland
desktop; this does not certify every remote native application.

| Remote display (live observation) | Keyboard readback | Mouse readback |
| --- | --- | --- |
| AOC HDMI-1, 5120×2880 at 4096,0 | `wayland-aoc-final` | 1 click, then 2 after returning |
| Internal eDP-1, 4096×2304 at 0,0 | `wayland-internal-final` | 1 click |

Rendered Flutter frames showed the probe's clock/frame marker advancing on
both displays. Switching AOC → internal → AOC succeeded through the actual
monitor selector, including continued input after returning. The patched client
remained alive for more than ten minutes during this bounded verification.
Ten additional AT-SPI helper connect/disconnect cycles interleaved with
synthetic key events also completed without a crash. This is a stability smoke
check, not a deterministic reproducer or a key-delivery stress certification.
The temporary probes and idle inhibitor were scoped to this check and removed
afterward; unrelated applications were left running. The session was left
connected to AOC.

`native_wayland_pointer.py` is a manual helper restricted to a single local
monitor and an already maximized client. It checks the target PID, title and
active state before input. Its geometry lookup reads XWayland's workarea;
pointer events use uinput rather than XTest. GNOME did not always accept
automatic focus switching, so the user manually foregrounded the client once.
Never bypass the focus guard or type after a failed helper command.

## Regression surface and remaining limits

| Existing file/path | Necessary change |
| --- | --- |
| `res/dev/run_linux.sh` | Native backend/session selection, native scaling and app-local GTK fix; explicit X11 compatibility path retained. |
| `flutter/linux/my_application.cc` | One backend diagnostic per main/subwindow; window construction/rendering unchanged. |
| `res/dev/remote_probe.py` | Opt-in keep-above/focus for test overlays obscured by an existing fullscreen app; default unchanged. |

The remaining files are additive development helpers, the attributed GTK patch
and this record. No Rust networking/capture/input protocol, Dart application
logic or submodule was changed. The final diff was inspected for unrelated work.

Native UI does not yet mean the entire application is independent of X11:
unsetting DISPLAY exposed an existing XCB clipboard dependency. The normal
launcher retains DISPLAY for that compatibility code. Clipboard, IME, drag/drop,
mixed-DPI local monitors, unattended login/lock-screen control and Ubuntu 24.04
have not been certified here. The existing X11 override was preserved, but a
fresh end-to-end X11 regression run was not part of this native Wayland check.
Long-duration stability and an independent deterministic GTK crash reproducer
remain useful follow-ups; this bounded run does not prove all crashes absent.

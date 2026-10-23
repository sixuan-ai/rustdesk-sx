# Wayland clipboard and Chinese input — 2026-10-23

## Scope

This is the next incremental step after native Wayland window rendering.
Changes remain on `codex/stable-1.5.0-dev`. The tested client is Linux Debug,
Ubuntu 26.04.1 / GNOME 50.1, Flutter 3.47.7, Rust 1.99.1, using the isolated
GTK 3.24.52 accessibility fix documented in the previous Wayland record.
OMEN remains on its existing installed RustDesk; no server deployment is made.

The development launcher enables a GTK **plain-text CLIPBOARD** backend on
GNOME with `GDK_BACKEND=wayland`. Other compositors retain the existing
data-control path by default; explicit RUSTDESK_WAYLAND_CLIPBOARD=1 opts in.
It does not require DISPLAY or the compositor's privileged
data-control protocol. All GTK requests are dispatched to the embedder main
loop, asynchronous selection requests keep the UI responsive, and workers wait
at most two seconds. The existing RustDesk owner MIME marker is offered with
received text to preserve the existing echo-suppression mechanism.
GTK 3's Wayland backend does not emit GDK_OWNER_CHANGE, so its clipboard
owner-change signal cannot drive synchronization here. The native listener
checks the focused application's text/owner-marker snapshot every 333 ms and
notifies existing subscribers only when that snapshot changes. It skips reads
while the application has no active GTK window; unchanged content is not
repeatedly transmitted. This is bounded UI clipboard monitoring, not a global
clipboard manager.

GNOME's standard Wayland clipboard is focus scoped. This implementation does
not promise clipboard monitoring while another application is focused. It
does not implement images, HTML, file URLs, PRIMARY or background clipboard
management. Unsupported writes without plain text fail without clearing the
local clipboard. File transfer and other remaining X11 integrations are outside
this step. A Wayland UI alone cannot bypass compositor permission rules.

## Confirmed causes

`wayland-info` on this host advertised `wl_data_device_manager` and
`zwp_text_input_manager_v3`, but neither ext-data-control nor wlr-data-control.
The pinned arboard and clipboard-master code probes data-control and falls back
to X11 when it is unavailable, explaining the earlier XcbConnect/DisplayNotSet
error. Merely compiling their Wayland feature does not remove this dependency.

The isolated GTK prefix also had its own input module cache, without the
distribution's IBus/Fcitx modules. The user confirmed that the new editable
field initially produced only Latin letters. The launcher now reuses the
system GTK ABI's module cache. On GNOME with a running IBus daemon and the
installed IBus module, it selects IBus unless GTK_IM_MODULE is already set.
Explicit user module/cache settings remain authoritative. Other desktop input
frameworks are not automatically switched to IBus.

The corrected client's process maps confirmed the isolated libgtk and system
`im-ibus.so` were both loaded. Its environment had GDK_BACKEND=wayland,
GTK_IM_MODULE=ibus, RUSTDESK_WAYLAND_CLIPBOARD=1 and **no DISPLAY**.

## Chinese input behavior

The remote canvas previously forwarded raw keyboard events without attaching
an editable text client for local IME composition. The new bottom-right
“中文输入” panel uses a real Flutter TextField, outside the canvas raw-key focus
scope. Select candidates locally, then click “发送到远端”. Preedit is not sent;
the send button is disabled until composition finishes. Drafts survive collapse
and failed dispatch. Keyboard permission and view-only restrictions are checked
again before dispatch. The existing sessionInputString protocol is reused.

This is explicit composed-text entry, not transparent IME forwarding over the
entire remote canvas. The remote server's existing text injection may itself
use its own clipboard/X11 compatibility mechanisms; those were not replaced.
The dispatch Future does not acknowledge that a remote application accepted
the text. Actual delivery must be checked at the target.

## Verification

- `res/dev/build_linux.sh`: passed (native core and Flutter Linux bundle).
- In `flutter/`, `flutter test --no-pub --concurrency 2
  test/wayland_text_input_test.dart test/companion_ui_test.dart
  test/quality_monitor_transport_test.dart test/server_settings_dialog_test.dart
  test/input_modifier_utils_test.dart test/cursor_replay_test.dart`: 77 passed.
- `dart analyze lib/desktop/widgets/wayland_text_input.dart
  lib/desktop/pages/remote_page.dart`: no new warnings/errors; two pre-existing
  deprecation infos for background and WillPopScope.
- `bash -n res/dev/run_linux.sh`, Python AST and `git diff --check`: passed.
- User-confirmed real IBus Chinese input and sending after the module-cache fix.
  OMEN's temporary probe JSON contained `你好\n`, verifying actual delivery over
  the Tailscale connection from the client without DISPLAY.
- Final bidirectional clipboard test used different content for each direction:
  OMEN's prepared `远端剪贴板→本机 Wayland ✅` was copied through RustDesk and
  pasted into the local TextField. VM inspection confirmed the controller's
  value matched exactly, without logging other field values. The local field
  was then changed to `2026102315123456`, copied locally and pasted into OMEN's
  probe; SSH JSON readback matched exactly. This distinguishes actual sync
  from pasting stale clipboard contents. Both operations used native uinput
  keyboard/mouse events through the GUI; SSH only prepared/read the probe.
- The foreground native Rust regression test passed (one test) including
  Chinese/multiline/owner-marker read/write, change notification and no duplicate
  notification for unchanged text. The old signal-only implementation lacked
  the notification on Wayland; the focused snapshot listener resolves it.
- Final client remained connected on AOC without DISPLAY; temporary probes and
  the regression window were removed after verification.

The opt-in Rust clipboard regression test requires a live Wayland session and
an actual click in its test window. A hidden/background test cannot stand in
for the compositor's focus/serial permission. Run with the same build env as
the development build (pkg-config, CXXFLAGS, two jobs) and the isolated GTK:

```bash
env -u DISPLAY GDK_BACKEND=wayland RUSTDESK_WAYLAND_CLIPBOARD=1 \
  cargo test --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste \
  platform::linux::wayland_clipboard::tests::native_text_and_owner_marker_without_x11 \
  -- --ignored --test-threads=1
```

Click the center button in “RustDesk native clipboard regression”. The test
checks Chinese, multiline text and owner marker round trips, notification
delivery and suppression of duplicate notifications. Full logs and
screen captures remain private under `~/.cache/rustdesk-dev/`; do not commit
them or upload VM service URLs, clipboard contents or desktop screenshots.
This foreground test passed: one test, zero failures. The earlier hidden-window
attempt failed because it had no input serial; the corrected test requires a
real button click rather than treating a background read as successful access.

## Regression surface / rollback

| Existing path | Necessary change |
| --- | --- |
| `src/clipboard.rs` | Optional arboard context plus early GTK read/write hooks and listener shutdown variant. Existing backend retains its retry, formats and PRIMARY behavior when GTK mode is disabled. |
| `src/platform/linux.rs` | One module declaration for the isolated native implementation. |
| `res/dev/run_linux.sh` | Enable native text clipboard for Wayland; restore distro IM modules to the isolated GTK process. |
| `flutter/lib/desktop/pages/remote_page.dart` | Add the native-Wayland-only text panel and existing input-permission/focus hooks. X11 UI does not show it. |
| `res/dev/native_wayland_pointer.py` | Add --require-active to reject focus-switch shortcuts during IME tests. |
| `res/dev/remote_probe.py` | Opt-in initial text to prepare a distinct remote clipboard source; empty default preserved. |

No submodule, dependency version, wire protocol or remote service changed.
Final diff minimization preserves all unrelated existing work.

Start with `RUSTDESK_WAYLAND_CLIPBOARD=0 res/dev/run_linux.sh` to restore the
old arboard/clipboard-master path (which requires XWayland on this GNOME host).
`RUSTDESK_GDK_BACKEND=x11` restores the former UI path. IM overrides only affect
the launched process; no global GNOME or IBus settings were changed.

Remaining validation: clipboard behavior across other independent applications,
arbitrary candidate-window placement, mixed-DPI monitors,
Ubuntu 24, Fcitx, Release and unattended sessions. The helper still reads local
XWayland workarea geometry for test positioning; this is test tooling, not the
new client text clipboard transport.

API references: [GTK Clipboard](https://docs.gtk.org/gtk3/class.Clipboard.html),
[GTK module environment](https://docs.gtk.org/gtk3/running.html),
[Flutter EditableText](https://api.flutter.dev/flutter/widgets/EditableText-class.html).

# 2026-10-26 OMEN Wayland screen wake and locked capture

## Summary

Branch `codex/stable-1.5.0-dev`, based on `ae643f69e`. Screen-sharing restoration
and screen wake are separate requirements. The previous persistent Portal build
was verified only in an unlocked session. The unattended test build enables the
existing DRM capture and uinput wake features, plus a connection-time wake for
GNOME's blank lock-screen shield. No automatic unlock or lock-policy changes.

## Environment

Observed 2026-10-26: OMEN Ubuntu26.04.1, GNOME50.1, NVIDIA RTX4060 Laptop,
native Wayland, session3. DRM card1 exposes HDMI-A-1 (AOC3840x2160@144) and
eDP-1 (2560x1440@60). These are observed modes, not remote stream FPS.
ScreenCast v5 / RemoteDesktop v2; original Portal persistence remains available.

## Symptoms / investigation

The existing idle inhibitor prevents future blanking but does not guarantee
waking an already dark screen. Mutter DisplayConfig.PowerSaveMode was writable:
setting3 then0 successfully changed reported power state without unlocking.

Pinned libdrmtap0.5.8 (`build.py` pin
`95d4d74549631aa5c39461300acfd2e106583cc9`) was built with EGL enabled and
the separate privileged helper disabled. OMEN enumeration and actual NVIDIA
EGL pixel conversion succeeded. The screenshot example auto-selected the
internal CRTC even though it printed the first enumerated external connector;
its actual captured dimensions were2560x1440. Do not infer the captured monitor
from that example's introductory connector message.

With the first DRM build, locked+powered-off reconnect changed power3 to0 and
received frames, but the rendered remote view and independent pixel capture
were black. A zero-net-displacement uinput mouse movement displayed the GNOME
lock clock while LockedHint remainedyes. Therefore frame receipt, active CRTC
and PowerSaveMode0 alone are insufficient validation of visible lock content.

## Root cause / fix

The existing DRM wake enumerator only injected activity when a connected output
had no active CRTC. GNOME can keep scanout active while its locked shield is
blank, so that condition missed the reproduced case.

- `src/ipc/drm.rs`: the authorized capture worker also requests the existing
  bounded uinput wake before enumeration. Preserve the existing20-second minimum
  gap, compile gate `drm-wake`, runtime option `enable-drm-display-wake=N`, and
  local IPC authorization. Use accurate throttled wake logging.
- `src/platform/linux.rs`: a small GNOME display-power helper for the ordinary
  Wayland path. It only sets positive PowerSaveMode to0, never calls unlock.
  Unsupported compositor errors remain trace diagnostics; X11 returns early.
- `src/server/connection.rs`: call that helper only when creating the existing
  incoming-session wakelock with an authenticated remote-desktop connection.
  Honor the existing keep-awake option; file-only connections do not call it.
- `res/dev/build_linux.sh`: opt-in `RUSTDESK_DEV_DRM=1` adds `drm,drm-wake`,
  matching build.py's unattended variant. Default builds retain Portal capture.

The DRM worker is used by trusted local capture consumers, including availability
probes. Thus this wake can occur during service/client initialization; it is not
strictly an event after the remote user's password was accepted. It does not
authenticate or unlock a desktop. No new privilege helper, setuid/setcap file,
global device permissions or input event loop is introduced.

## Build / verification

Two-job local Debug and Release builds:

```bash
RUSTDESK_DEV_DRM=1 RUSTDESK_DEV_HWCODEC=1 RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
RUSTDESK_DEV_DRM=1 RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
bash -n res/dev/build_linux.sh
git diff --check
```

Before enabling DRM, the modified ordinary build compiled successfully too.
Pinned library: `meson setup build -Degl=enabled -Dhelper=disabled`,
`meson compile -C build -j2`, `meson test -C build --no-rebuild --print-errorlogs`:
12 passed locally. These are upstream library tests, not an end-to-end software
suite. OMEN `test_enumerate` passed and `screenshot /dev/dri/card1 >/dev/null`
confirmed actual pixel conversion. Private screenshots were inspected only for
the lock clock/blank regression; they must not be committed or published.

Debug target cases: unlocked reconnect and screen-off reconnect each produced
three valid3840x2160 decoded/submitted metric windows, decode_errors0.
After the connection-time activity fix, service restart then locked+screen-off
reconnect rendered the GNOME lock clock automatically, PowerSaveMode0,
LockedHint=yes, with a valid3840x2160 metric window and decode_errors0.
Static lock scenes may stop producing changed frames; the earlier three-window
criterion is not a reliable assertion of visible lock content. Render inspection
is required. Locked sessions can change display topology/resolution.

The owner reported that Debug still showed “connecting”, despite VM render
inspection showing the password dialog. That discrepancy was not isolated;
do not claim a Debug presentation fix. The Debug GUI was closed, both ends
switched to Release, and the connection reopened. A real local compositor
screenshot through the standard Screenshot portal then showed the Release
remote window displaying OMEN's OS password dialog. Unlike a Flutter VM render,
this check verifies the compositor-visible view. Private screenshots are deleted.
Local and deployed Release core SHA256:
`1c6c618ef342bf77466e18f053d38322baea8bacd356fd42341d5d9a3ceed7d2`.
The owner then confirmed Release displayed the dialog and accepted input.
Subsequent target queries reported LockedHint=no and ScreenSaver.GetActive=false,
confirming OS authentication completed through the remote session. No unlock
command was used during these tests.
Finally, the Release client was disconnected, the persistent target service
restarted, and a fresh Release GUI connected via its own D-Bus unique owner.
It created a remote texture again without any sharing action; service active,
LockedHint=no. This last check establishes session recovery and texture creation,
not a new high-FPS benchmark or an exhaustive application-input test.

## Deployment / remaining scope

Test bundles reside in `/opt/rustdesk-wake-debug` and
`/opt/rustdesk-wake-release`, root-owned, no group/other writes. The pinned
library is `/usr/lib/rustdesk/libdrmtap.so.0`, root-owned0644. No ldconfig change
or separate capture helper is required; existing root-service DRM IPC exports
scanout and the desktop process converts it with EGL.

The optional unit template is `res/dev/systemd/rustdesk-sx-unattended.conf`.
OMEN's installed override is
`/etc/systemd/system/rustdesk.service.d/91-sx-unattended.conf`; the temporary
`/run` test override was removed and daemon-reload completed. Service active
and enabled; desktop child maps the matching Release core and pinned library.
Original `/usr/bin/rustdesk` and `/opt/rustdesk-portal-persistence-release` remain
available. General post-login application operation is not covered by password
entry and lock-state checks. Logged-out
GDM, reboot recovery, suspend/resume and other GPUs/distributions are unverified.
This work does not establish4K60 or performance parity with Portal capture.

Rollback: remove `/etc/systemd/system/rustdesk.service.d/91-sx-unattended.conf`
and any temporary
`/run/systemd/system/rustdesk.service.d/99-sx-wake-test.conf`, then
`sudo systemctl daemon-reload && sudo systemctl restart rustdesk`. Keep the
previous `90-sx-wayland-portal.conf` to restore the tested Portal Release bundle.
The standalone libdrmtap can then be removed if unused. Preserve current Portal
restore tokens; do not restore old consumed tokens. Lock and idle policies and
passwords remain unchanged.

# 2026-10-26 Wayland persistent authorization on OMEN

## Summary

Based on `10f5587aa`, branch `codex/stable-1.5.0-dev`. After one normal Portal
screen-sharing grant with “remember” selected, OMEN recovered automatically
through two client disconnects, a Debug service restart, a switch to Release,
and another Release service restart. No sharing action was performed after
the initial grant. Each accepted connection delivered new 3840x2160 decoded
frames with zero decoding errors.

**Scope: the existing logged-in, unlocked GNOME session.** This does not certify
access to a locked session, a logged-out greeter, or a new login after reboot.
No automatic screen-unlock behavior was added to RustDesk.

## Environment / support

Observed on OMEN, 2026-10-26: Ubuntu26.04.1, GNOME Shell50.1-0ubuntu1.4,
xdg-desktop-portal1.21.1+ds-1ubuntu3.1, GNOME backend50.0-0ubuntu1.
Actual D-Bus properties reported ScreenCast v5 and RemoteDesktop v2, with
monitor/window/virtual sources and keyboard/pointer/touch capabilities.
The original installed RustDesk was1.5.0; its root service was running and the
desktop child used the graphical user's HOME and session bus.

The desktop was initially locked. At the owner's explicit request, existing
administrator access ran `loginctl unlock-session 3`. After asynchronous
processing, both LockedHint=no and GNOME ScreenSaver.GetActive=false confirmed
unlocking. No password or persistent lock-screen setting was changed.

## Implementation / regression surface

Only `libs/scrap/src/wayland/pipewire.rs` changes application behavior:

- Check persistence against the interface actually selected: ScreenCast>=4,
  RemoteDesktop>=2. Unsupported versions retain the original interactive path.
- Keep the existing ScreenCast token key. The new RemoteDesktop v2 path requests
  persist_mode2 via SelectDevices and uses its own
  wayland-remote-desktop-restore-token key. Combined sessions do not put these
  options in ScreenCast.SelectSources.
- Read the latest token from disk when creating a request, rather than relying
  on the process-start LocalConfig cache.
- Save the Start result for either portal; when a persistence-capable response
  supplies no token, clear the previously consumed token. A request for persistent
  access alone is not a granted persistent permission.
- Emit throttled authorization metadata: portal kind, token presence and whether
  disk storage matches. Never log bearer values. Replace the existing full
  D-Bus response/message debug dump with trace-level result **keys** only.

Existing capture, encoder, input, clipboard, queue and network policies remain
unchanged. ScreenCast continues to use the installed-service/uinput route.
RemoteDesktop v2 support is covered by version/options unit tests; the live OMEN
tests exercised the service/ScreenCast route, not service-free input injection.

The optional `res/dev/systemd/rustdesk-sx-wayland.conf` selects a complete tested
Release bundle while inheriting the installed unit's user, stop command and
restart policy. It does not modify default packaging or other hosts' services.

## First authorization

The owner was away from OMEN and delegated setup. After unlocking, the regular
GNOME sharing selector was inspected through accessibility. “记住该选择” was
checked; the known internal display and AOC27-inch display were selected, then
the normal Share button was activated once. No permission database entries
were fabricated or changed directly.

The server reported persistent=true and storage_matches=true. A final read-only
PermissionStore query confirmed a matching persistent screencast entry, and the
desktop user's RustDesk_local.toml remained UID1000/mode0600. Neither token
values nor the complete configuration were copied into these records.

An existing token alone is not sufficient proof of an effective grant. Also,
do not diagnose a missing PermissionStore entry in isolation: the portal consumes
restore data during restoration and can save it again during session lifecycle
transitions. The exact historical cause of earlier prompts was not isolated.

## Verification

Local builds, with two jobs:

```bash
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
```

Both complete Rust+Flutter bundles built. Using the same isolated hwcodec/system
FFmpeg environment as build_linux.sh, the following passed27 tests (including
the two new persistence tests):

```bash
cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland wayland::
```

The tests cover selected-portal version gates, no persistence options on legacy
backends, first persistent request without a token, and token-bearing restoration.
No global user configuration is modified by those tests. `git diff --check` passes.

| Case | Server | Subsequent Share actions | Fresh decoded metric windows | Decode errors |
| --- | --- | ---: | ---: | ---: |
| disconnect-1 | Debug, same service |0|3|0|
| disconnect-2 | Debug, same service |0|3|0|
| debug-service-restart | Debug, restarted |0|3|0|
| release-service-start | matching Release bundle |0|3|0|
| release-service-restart | Release, restarted |0|3|0|

Each window reported3840x2160 and received/submitted FPS>0. Confirmation took
7..9s after the connection invocation to collect three valid metric windows;
this is **not** an exact first-frame latency measurement. Client initialization
was separate. Rendered Flutter snapshots showed the controlled probe marker
advancing from74 after the Debug restart to279 after the Release restart.
Snapshots were deleted after inspection; background desktop content was not
included in repository or knowledge-base evidence.

Connection commands initially reached a pre-existing installed GUI through the
shared D-Bus name. The test therefore addressed the development GUI's own unique
D-Bus owner, selected by process ID, using the existing /dbus NewConnection method.
The old GUI had only the OMEN session and was exited; local background server
and tray processes were preserved. This avoids attributing another client's
video to the validation client. It required no application routing changes.

The existing bounded remote_probe.py supplied a changing frame marker. Other
applications were not stopped. A temporary, bounded idle inhibitor prevented
automatic locking during setup; it is no longer running. After testing, the
normal native Wayland Debug client was relaunched without DISPLAY or metrics,
reconnected and received a remote texture event. Final Portal dialog count was0.

## Deployment / rollback

OMEN now uses `/opt/rustdesk-portal-persistence-release`, a complete Release
bundle. Both the directory and executable are root:root0755, and group/other
write permissions were removed recursively. The effective desktop child maps
the new core from this bundle and has no display-metrics flag.

Core SHA256 on local build and OMEN both:
`6ca68749b194b65df8ea3e477992407a2a18b8b9231c15e7ae7c3e5fb22fff51`.

The checked-in override was installed as
`/etc/systemd/system/rustdesk.service.d/90-sx-wayland-portal.conf`.
The temporary /run verification override was removed. The installed executable
and original /usr/lib unit were not overwritten. rustdesk.service is active.
Transmit unit content through stdin or copy the file before restarting: the
installed ExecStop pkill pattern can match a long SSH command that embeds the
literal executable/argument pair.

To return to the original installed service:

```bash
sudo rm /etc/systemd/system/rustdesk.service.d/90-sx-wayland-portal.conf
sudo systemctl daemon-reload
sudo systemctl restart rustdesk
```

Retain the newly issued ScreenCast token; do not restore a consumed old token.
The original ScreenCast key is compatible with the installed version. The new
RemoteDesktop key is ignored by older code. Reverting this task's source commit
and rebuilding rolls back the implementation. Source changes were retained
locally on the development branch; no Git push was requested.

## Remaining limits / evidence

System reboot, logout, lock-screen capture and service-free RemoteDesktop input
were not certified. Monitor removal, permission withdrawal, backend changes or
a decision not to remember can require fresh consent, as allowed by the Portal.
No OS-authentication bypass or automatic unlock was implemented. Permanent
RustDesk credentials and global lock/idle policy were not changed.

Private, sanitized per-case results and build/test logs are under
~/.cache/rustdesk-dev/portal-persistence. The temporary source was stopped; no
test window or idle inhibitor remains. No bearer token, password, VM service
authentication URL, full environment or desktop screenshot is included here.

Protocol references:
[RemoteDesktop persistence](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html),
[ScreenCast persistence](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html),
[Portal1.21.1 session persistence implementation](https://github.com/flatpak/xdg-desktop-portal/blob/1.21.1/src/xdp-session-persistence.c).

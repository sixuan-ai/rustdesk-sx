# 2026-10-26 Released Debian package installed on the client and OMEN

## Summary

Installed `rustdesk-sx 1.5.0+sx.20261026.1` on local host x-26 and OMEN using
the published Ubuntu26.04 amd64 package. The local client now runs from the
installed package; OMEN's enabled root service and desktop server also run from
the installed package. Screen-off wake, visible locked capture, owner-entered
OS login, service restart, and post-login reconnect passed.

This extends the previous publication-only checks to actual Debian installation
and the requested remote session tests. It is not an uninstall/reboot/4K60 test.
No runtime source changes or new binaries were needed.

## Environment / artifact

Observed 2026-10-26: local x-26 and OMEN Ubuntu26.04.1, native GNOME Wayland.
OMEN uses session3 and NVIDIA RTX4060 Laptop. Tailscale direct IP connection.
Release/tag source `55a282d110902e5141a8e40d7bb817ea666ed134`:
https://github.com/sixuan-ai/rustdesk-sx/releases/tag/v1.5.0-sx.20261026.1

- Package `rustdesk-sx_1.5.0+sx.20261026.1_amd64.deb`, SHA256
  `b9ac785db9cb6e6683b56930b0e5af78d7f998fa6310c2878a9f3ba569b99922`.
- Installed core `/usr/lib/rustdesk-sx/lib/librustdesk.so`, SHA256
  `1c6c618ef342bf77466e18f053d38322baea8bacd356fd42341d5d9a3ceed7d2`.
- Fixed capture library `/usr/lib/rustdesk/libdrmtap.so.0`, SHA256
  `06c9f4623ea7df865e466114b5038762125b774776e7cd60cbf60522cac1c248`.

Both hosts report the exact Debian version and matching installed hashes.
Installed payloads have no group/other-write entries; the library is root-owned.
The application's internal base version remains1.5.0; use dpkg/BUILD-INFO for
the SX release version.

## Preservation and installation

Before installation, root-only rollback material was saved on **both** hosts at
`/var/backups/rustdesk-sx/20261026-release-install/`: directory0700,
`before-install.tar.gz` and `state.json`0600. The archive contains only existing
RustDesk unit/drop-ins, the prior fixed library if present, and relevant RustDesk
configuration. It contains private configuration and must not be published.
No archive contents, passwords, tokens or complete configuration are recorded
here. Original `rustdesk1.5.0` remains installed for rollback.

Local installation used the existing authenticated localhost SSH administration
session with sudo. OMEN used the existing omen SSH connection:

```bash
# Local host, inside its administration session:
sudo apt-get install -y --no-install-recommends /home/x/.cache/rustdesk-dev/releases/v1.5.0-sx.20261026.1/rustdesk-sx_1.5.0+sx.20261026.1_amd64.deb
# OMEN:
sudo apt-get install -y --no-remove --no-install-recommends /home/x/.cache/rustdesk-sx-release-install/rustdesk-sx_1.5.0+sx.20261026.1_amd64.deb
```

Both installations passed. The package has no automatic service-maintenance
hooks. OMEN explicitly opted into the existing root service:

```bash
sudo install -D -m 644 /usr/lib/rustdesk-sx/systemd/rustdesk-sx-package.conf /etc/systemd/system/rustdesk.service.d/99-rustdesk-sx-package.conf
sudo systemctl daemon-reload
sudo systemctl enable rustdesk.service
sudo systemctl restart rustdesk.service
```

The old90/91 overrides and `/opt` test bundles remain intact, but99 now selects
`/usr/lib/rustdesk-sx/rustdesk --service`. Root service and user desktop server
maps confirm the installed core and fixed library, not the old `/opt` binaries.
Service is active/enabled. No base unit replacement was needed.

The local source-bundle GUI was closed by its verified PID/executable only;
the unrelated local background controlled-host service/tray were preserved.
The new GUI runs `/usr/bin/rustdesk-sx --no-server` with GDK_BACKEND=wayland,
DISPLAY absent and the packaged library path. The launcher respects an explicit
GDK_BACKEND: inheriting x11 while removing DISPLAY initially prevented startup;
setting the requested Wayland backend in this process resolved it. No global
desktop variables were changed. Stock GTK is used, not the private development
GTK override. A source-bundle process may show `(deleted)` after a rebuild;
normalize that suffix only when verifying that same known GUI before closing it.

## Session verification

Connections were directed to the installed GUI's own D-Bus unique owner
(`org.rustdesk.rustdesk`, `/dbus`, `NewConnection`), selected by PID. This avoids
the installed tray or another GUI receiving a generic connect request.

A bounded temporary GTK verification window on OMEN displayed an advancing clock
and frame marker. Standard Screenshot portal captures of the **actual local
compositor** showed the remote content; mere texture creation was not used as
the sole success criterion. All private screenshots were deleted afterward.

| Case | Observed result |
| --- | --- |
| Initial installed client/server | Real remote probe visible, frame marker31 |
| Disconnect, PowerSaveMode3, reconnect | Power returned0; real marker90; LockedHint=no |
| Root service restart and fresh client | Real marker116; no Share action; LockedHint=no |
| Locked session, PowerSaveMode3, reconnect | Power returned0; visible GNOME lock clock; LockedHint=yes |
| Owner-entered system password | Owner confirmed desktop; LockedHint=no and ScreenSaver.GetActive=false |
| Post-login disconnect/reconnect | Real marker249; desktop still unlocked; no Share action |

Power checks used `org.freedesktop.DBus.Properties.Get/Set` on
`org.gnome.Mutter.DisplayConfig.PowerSaveMode`. Locking used
`loginctl lock-session 3`; this task never called unlock-session. The owner
typed the system password in the remote window, never in chat or a command.
The existing wake limiter was left intact; tests allowed its minimum interval
instead of modifying it.

Metadata checks:

```bash
dpkg-query -W -f='${Package} ${Version}\n' rustdesk-sx
sha256sum /usr/lib/rustdesk-sx/lib/librustdesk.so /usr/lib/rustdesk/libdrmtap.so.0
systemctl is-active rustdesk
systemctl is-enabled rustdesk
loginctl show-session 3 -p LockedHint
```

After testing, only the known timeout/probe process was stopped. The installed
Release client remains normally connected, diagnostics disabled; no permanent
test inhibitor, new debug service override or synthetic input loop remains.
Other OMEN applications were preserved.

## Remaining limits / rollback

This validates the currently logged-in GNOME session, screen power, its lock
screen and reconnect. Logged-out GDM, whole-machine reboot, suspend/resume,
other hardware, exhaustive input/clipboard/multi-screen tests and sustained4K60
are outside this installation verification. Debug's earlier presentation issue
was not changed; this task uses the published Release package.

To revert OMEN's service while keeping the SX package installed: remove only
`/etc/systemd/system/rustdesk.service.d/99-rustdesk-sx-package.conf`, then
daemon-reload and restart rustdesk. The retained91 override selects the previous
tested `/opt/rustdesk-wake-release` bundle. Expect remote disconnection.

Before **uninstalling** the package, switch the service away from its installed
path. Removing the package also removes the fixed libdrmtap which the old `/opt`
DRM bundle needs: restore only that old library from the protected backup after
removal, preserving root ownership and no group/other writes, before restarting
the old DRM service. Do not restore the complete archive blindly or replace
current Portal restore tokens with consumed backup tokens. The backup's unit
files can recover prior service configuration if needed.

Local client rollback: close only the installed SX GUI, remove the SX package
if desired, and relaunch the retained tested source Release via
`RUSTDESK_DEV_BUILD_MODE=release res/dev/run_linux.sh`. The original local
controlled-host service was never changed. User data and passwords are preserved.

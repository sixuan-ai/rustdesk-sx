# 2026-10-26 Linux Release: unattended capture and screen wake

Release tag `v1.5.0-sx.20261026.1`, Debian version `1.5.0+sx.20261026.1`.
Ubuntu26.04 x86_64 only; development preview, not Ubuntu24.04 compatible.

## Contents and runtime evidence

Includes `ae643f69e` (persistent Portal authorization) and `f32f141a6` (screen
wake), plus additive packaging changes. The application core is unchanged by
packaging; its SHA256 must match the verified OMEN Release:
`1c6c618ef342bf77466e18f053d38322baea8bacd356fd42341d5d9a3ceed7d2`.
The pinned libdrmtap0.5.8 SHA256 is
`06c9f4623ea7df865e466114b5038762125b774776e7cd60cbf60522cac1c248`.

OMEN GNOME50.1/Wayland/NVIDIA RTX4060 verified screen-off wake, visible lock
screen, manual OS-password login, and service-restart reconnect without another
Share action. See [runtime validation](../incidents/2026-10-26-wayland-screen-wake.md)
and [Portal persistence](../incidents/2026-10-26-wayland-persistent-authorization.md).
The owner confirmed reaching the desktop. No automatic unlock/password changes.
DRM capture requires the privileged system service; it is separate from Portal
authorization, which remains the fallback on unsupported builds/hosts.

## Build and package

With the previously generated matching FRB bridge, system FFmpeg8/hwcodec,
Flutter3.47.7, Rust1.99.1, and maximum two compiler jobs:

```bash
RUSTDESK_DEV_DRM=1 RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
```

Build libdrmtap from the exact `LIBDRMTAP_SHA_PINNED` in `build.py`, currently
`95d4d74549631aa5c39461300acfd2e106583cc9`, using its registered repository.
Inside that clean checkout:

```bash
meson setup build -Degl=enabled -Dhelper=disabled
meson compile -C build -j2
```

Commit packaging sources and ensure a clean worktree before packaging:

```bash
python3 res/dev/package_linux_release.py \
  --version 1.5.0+sx.20261026.1 \
  --output /home/x/.cache/rustdesk-dev/releases/v1.5.0-sx.20261026.1 \
  --flutter-root /home/x/flutter --unattended \
  --drmtap-source /home/x/.cache/rustdesk-dev/libdrmtap-wake \
  --drmtap-library /home/x/.cache/rustdesk-dev/libdrmtap-wake/build/libdrmtap.so.0.5.8
```

The source pin, clean tracked source, artifact location, EGL support, removed
helper path, and compiled DRM/wake markers are checked before staging. Package
metadata records exact source/core/library hashes. All shipped ELF dependencies
are resolved, including versioned `.so.0`; dynamically loaded EGL/GLES are
explicit Debian dependencies. License and source attribution for libdrmtap are
included alongside existing AGPL/MiSans/Flutter notices. No configuration, tokens,
passwords, user logs or private screenshots are copied.

Artifacts: `.deb`, `.tar.gz`, `BUILD-INFO.json`, `README.zh-CN.txt`, `SHA256SUMS`.
The `.deb` includes the root-only loader's fixed library location
`/usr/lib/rustdesk/libdrmtap.so.0`. The portable archive includes its own library,
but is recommended as a client; use the Debian installation for the root service.

## Opt-in service activation

Installing the package does not enable/restart/replace an existing service.
Application installation path is `/usr/lib/rustdesk-sx`, command `rustdesk-sx`.
It continues to use the existing RustDesk user-configuration location.

For a controlled host, after `sudo apt install ./rustdesk-sx_1.5.0+sx.20261026.1_amd64.deb`,
preserve an existing `rustdesk.service`. Only if no such service exists, install:

```bash
sudo install -m 644 /usr/lib/rustdesk-sx/systemd/rustdesk-sx-package.service /etc/systemd/system/rustdesk.service
```

Then opt in (this restarts RustDesk and disconnects remote sessions):

```bash
sudo install -D -m 644 /usr/lib/rustdesk-sx/systemd/rustdesk-sx-package.conf /etc/systemd/system/rustdesk.service.d/99-rustdesk-sx-package.conf
sudo systemctl daemon-reload
sudo systemctl enable rustdesk.service
sudo systemctl restart rustdesk.service
```

The root-owned library and bundle do not need a setcap/setuid capture helper or
world-writable device permissions. Configure access credentials and direct-IP
access through normal RustDesk settings; this package carries none of them.
Do not run a second controlled-host service on the same listening port.

## Validation / scope

The Release core rebuilt successfully and matches the OMEN-verified hash above.
Pinned library artifact checks pass and a non-DRM core is rejected. Python syntax
and `git diff --check` pass. Packaging additionally checks ELF dependencies and
the portable version entry. Final archive extraction, Debian metadata, apt
simulation, core/library digests and GitHub asset digests must be checked before
handoff. This does not claim a real dpkg install/removal or exhaustive regression
on another machine; the publication task leaves OMEN's tested service running.

Not certified: Ubuntu24.04/other distributions/architectures, logged-out GDM,
whole-machine reboot, suspend/resume, or sustained4K60. Debug's reported
“connecting” discrepancy was not isolated. Public packages use system GTK,
without the development host's private GTK3.24.52 AT-SPI fix. `main` or tag
source updates do not update already downloaded binaries.

## Regression surface / rollback

Only the SX packaging script changes artifact behavior. The original client-only
packaging mode remains; an unattended core requires explicit packaging opt-in so
it cannot accidentally ship without its required library. Two optional service
templates are inert until installed by the operator. Runtime source is unchanged.

Before uninstalling, remove the added `99-rustdesk-sx-package.conf`, reload
systemd, and restart the preserved original service. If this installation created
the base service, first `systemctl disable --now rustdesk.service`, remove that
new base unit and override, then daemon-reload. Only then remove `rustdesk-sx`.
Preserve old overrides and current Portal tokens; do not restore consumed tokens.
The older release and its assets remain available on GitHub for rollback.

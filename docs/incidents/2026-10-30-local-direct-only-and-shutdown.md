# 2026-10-30 Direct-only mode and Linux shutdown callback guard

## Summary / environment

RustDesk SX 2.1.0, Ubuntu 26.04 GNOME native Wayland. A deployment using an
external account/mesh coordinator and Tailscale/IP remote connections needs no
RustDesk ID or relay service. This patch makes that choice explicit and guards
a background event callback during main-engine shutdown.

## Confirmed symptoms and investigation

Loopback placeholder ID/relay addresses caused repeated `register_pk` attempts.
Clearing the custom address alone would fall back to public ID infrastructure;
`stop-service` would also disable the required direct incoming listener.

An apport report modified on October 30 actually recorded an October 29 14:08:07
SIGABRT. File modification time must not be treated as crash occurrence time.
Launch stderr contained `Start closing RustDesk...`, the Flutter implicit-view
removal warning and Dart `mmap failed: 22 (Invalid argument)`.

The old stripped stack and a sanitized core inspection identified a pending
`callback_query_onlines` event posted to the `main` Dart channel during shutdown.
Matching executable instruction patterns against a symbol-bearing build located
`allo_isolate::Isolate::post` and `flutter::async_tasks::handle_query_onlines`.
For this ELF, executable LOAD virtual addresses are file offsets plus 0x1000;
account for segment mappings before calling addr2line. Core dumps and full event
payloads are private diagnostic material and are excluded from the repository.
There is no evidence here of GPU exhaustion, OOM or a network-induced abort.

## Fix / regression surface

- `libs/base/src/config/{keys.rs,mod.rs}` defines an explicit opt-in
  `direct-only = 'Y'`; default behavior is unchanged.
- `src/rendezvous_mediator.rs` skips ID-host registration in this mode while
  leaving the direct listener and account HTTP startup paths in place.
- `src/common.rs` skips ID/NAT discovery, server resolution and ID latency tests.
- `src/client.rs` and `src/client/peer_online/direct.rs` preserve IP/host:port
  connections/probes and reject numeric-ID connections or leave their presence
  unconfirmed without a server request.
- `flutter/lib/common.dart` awaits the existing main global-event-stream stop
  API on Linux before GTK closes the main engine. Rust sink removal takes the
  write lock after any already-running global post finishes.

Change the mode while stopped and restart; enabling it live does not promise
cancellation of registration workers already running. See the README for usage.
No new dependencies, authentication scheme, video path or shared trait changes.

## Verification

On the original installed application, applying the same Rust/shared-UI fixes
preserved identity/password, local/account settings and both saved peer records.
Only direct-only/obsolete ID addresses were changed; encrypted address-book
caches refreshed normally. Native GdkWaylandDisplay startup, the local direct
listener and the known remote Tailscale port were confirmed. After startup,
there were no ID registration/UDP mediator log entries and an ID/relay-port
metadata capture reported 0 captured / 0 received / 0 dropped packets.

One user-performed normal close/reopen cycle produced no mmap abort and no new
apport report. Flutter still logged implicit-view removal and messenger-without-
engine warnings. The installed runner, engine, plugins and service files were
retained. This does not establish a universal shutdown-race fix.

Publication validation, 2026-10-30:

- Local and build-host Flutter SDKs updated to stable 3.47.9, Dart 3.13.7,
  framework c197ca5199e9ee5661e865596c9c07294dfab51c.
- `cargo test --locked --jobs 2 -p base --test direct_only_config`: 1 passed.
  The test isolates XDG_CONFIG_HOME and checks opt-in/out plus retained options.
- In `flutter/`, `flutter test --no-pub --concurrency 2 test/direct_peer_status_test.dart test/autocomplete_peer_merge_test.dart test/companion_device_ui_test.dart test/verification_code_input_test.dart test/server_settings_dialog_test.dart`: 16 passed.
- `flutter build linux --release --no-pub`, with Ninja limited to four jobs:
  passed.
- `git diff --check`: passed. No unrelated formatting/submodule changes.
- Local `flutter doctor` reports no issues. The build host reports unaccepted
  Android licenses and optional missing eglinfo; Linux builds pass. This task
  did not accept Android licenses or perform Android/hardware validation.

The publication source's Rust tree, Cargo manifests/lock and build script match
the already-built hardware-codec/DRM fix exactly. The unrelated account-backend
work remains on its existing development branch. This SDK update does not
replace installed RustDesk binaries, publish release assets or test a new remote
screen/input/multi-monitor session.

## Remaining risk / rollback

One normal exit passed; active-session shutdown and repeated race stress are
unverified. Native Flutter teardown warnings remain. The SDK's newer Release
bundle needs separate interactive/session acceptance before deployment.

Keep exact installation/config backups before changing runtime files. Reverting
to a binary without direct-only support also requires restoring the previous
RustDesk2.toml so the old client cannot silently use a public fallback. Preserve
any newer account/peer changes when restoring. Source rollback is the scoped
publication commit; reverting direct-only does not change mesh/coordinator policy.

SDK rollback, if needed, uses the previous stable 3.47.7 source revision
abaf9c523780a608bd46686fd5e53740a07077f8 and matching cached SDK artifacts.

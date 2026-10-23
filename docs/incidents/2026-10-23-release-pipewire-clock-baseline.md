# 2026-10-23 Release and PipeWire clock baseline

## Environment / scope

Based on `51b005760`, branch `codex/stable-1.5.0-dev`. Observed on
2026-10-23: Ubuntu 26.04.1 / GNOME Wayland, Flutter 3.47.7, Rust 1.99.1;
local NVIDIA RTX 5060 Ti 8 GB, OMEN RTX 4060. Other GPU applications retained.
Tailscale direct connection, H.265 NVENC / CUDA RAM decode, native Wayland/Skia
client without DISPLAY. No display mode, driver or network settings changed.

Debug and Release are complete matching Rust+Flutter bundles on both hosts,
not a Release Rust library loaded by a Debug Flutter engine. The Release Rust
profile retains opt-level=3, LTO, one codegen unit and stripped symbols;
Flutter uses its Release engine and libapp.so AOT artifact. Builds use two jobs.

## Changes and reproduction

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release res/dev/build_linux.sh
RUSTDESK_DEV_BUILD_MODE=release res/dev/run_linux.sh
```

`RUSTDESK_DEV_BUILD_MODE` defaults to debug and accepts only debug/release.
The runner still applies the established local GTK/IBus, Skia and Wayland
settings. Building may prepend an analyzer exclusion block to
flutter/analysis_options.yaml; that generated-only change was restored.

`RUSTDESK_PIPEWIRE_UNPACED=1` is a separate opt-in experiment. It changes only
appsink sync=false and processing-deadline=0 when that property exists.
The current GStreamer defaults from gst-inspect-1.0 appsink are sync=true and
processing-deadline=20000000 ns. max-buffers=1, drop=true, pipewiresrc
always-copy=true, formats, converter and timestamp semantics are retained.
The existing explicit service-to-desktop environment helper forwards only
literal 1. Unset retains the original clock behavior. Activation emits one
message per recorder, rather than per frame.

For temporary OMEN runs, stage the complete matching bundle in a separate
`/opt/rustdesk-clock-debug-skia` or `/opt/rustdesk-clock-release-skia` directory and use
only `/run/systemd/system/rustdesk.service.d/90-development-verification.conf`:

```ini
[Service]
ExecStart=
ExecStart=/opt/rustdesk-clock-release-skia/rustdesk --service
Environment=RUSTDESK_DISPLAY_METRICS=1 RUST_LOG=info
```

For the unpaced case append RUSTDESK_PIPEWIRE_UNPACED=1 to Environment. Reload
and restart only rustdesk.service. Check actual executable/core paths and
whitelisted flags in the desktop --server process, not only the root service.
Do not pass a command string containing the literal service ExecStop match
through a long-lived SSH shell; write the override through stdin before the
separate restart call. Installed binaries are not replaced.

Temporarily use custom quality 33 and custom-fps 60; restore only those quality
keys afterward, preserving credentials. Keep RUSTDESK_PARALLEL_NV12 and
RUSTDESK_NVENC_LOW_LATENCY unset in all comparison cases. Wait for fresh 4K
client submissions after each new service/client connection, then run:

```bash
# On OMEN, in its graphical user's environment:
XDG_RUNTIME_DIR=/run/user/1000 \
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
WAYLAND_DISPLAY=wayland-0 GDK_BACKEND=wayland \
python3 res/dev/playback_motion_probe.py \
  --video /path/to/motion-4k60.mkv --output HDMI-1 --mode maximized --seconds 55
```

The checked-in fixture generator and bounded probe were already introduced by
the capture investigation. Verify live display-names, dimensions, advancing
playback position, pause=false and drop counters for every run. Video viewport
is smaller than the full 3840x2160 desktop; this is a desktop capture test,
not a full-screen direct-scanout test. No compilation runs during measurements.

## Logging and sampling

Debug core logs go to stderr/journal with UTC timestamps. Release core uses
flexi_logger files under ~/.local/share/logs/RustDesk, including flutter_ffi
and server subdirectories, with local timestamps and explicit offsets. Release
has no Dart VM service. An extractor assuming Debug stderr/UTC silently drops
Release evidence; do not modify shared hbb_common logging to work around it.

The summarizer now optionally accepts aware ISO --since/--until bounds and
recognizes both formats. Without bounds its prior behavior is retained.
Filter only sanitized telemetry markers; keep full logs, configuration and VM
URLs private. For a source launch timestamp T select report timestamps from
T+15 to T+50 seconds on both hosts, e.g.:

```bash
python3 res/dev/summarize_display_metrics.py /private/case-metrics.log \
  --since 2026-10-23T10:00:15Z --until 2026-10-23T10:00:50Z
```

Client FPS is weighted by metric window duration. Stage timings are means of
window p95 values, not merged frame percentiles and not additive end-to-end
latency. Submission callback FPS and player counters do not prove physical
compositor presentation FPS. Bounded loaded-host trials are not empty-host
maximum-throughput measurements.

## Regression surface

- res/dev/build_linux.sh: select corresponding Rust and Flutter build modes.
- res/dev/run_linux.sh: select bundle only; existing runtime defaults retained.
- libs/scrap/src/wayland/pipewire.rs: opt-in appsink experiment only.
- src/server/video_metrics.rs: add one allowed experimental child environment flag.
- res/dev/summarize_display_metrics.py: optional time bounds for both log formats.
- New test_display_metrics_time_filter.py: verifies inclusive UTC-equivalent
  Debug/Release selection and exclusion of outside/untimed records.

No shared traits, signatures, dependencies, submodules, protocol, codec quality
or default pacing policy changed. Existing multiscreen capturer lifecycle is
held fixed: src/server/wayland.rs precreates and retains a capturer per shared
screen. The unselected screen can still produce source buffers. That behavior
is confirmed by code/telemetry, but its contribution to the remaining gap
requires a separate lifecycle experiment; it is not a proven unique cause.

## Release renderer correction

The first Release launch used Impeller despite the launcher's Skia environment
switch. Confirmed in the installed Flutter 3.47.7 source:
`/home/x/flutter/engine/src/flutter/shell/platform/common/engine_switches.cc`
excludes environment engine switches under FLUTTER_RELEASE. Flutter's
[Linux Impeller setup](https://github.com/flutter/flutter/blob/master/engine/src/flutter/impeller/README.md)
uses fl_dart_project_set_enable_impeller on the project instead.

The development launcher now exports its validated RUSTDESK_DEV_RENDERER.
A small Linux renderer_view.h adapter applies that explicit choice to each
FlDartProject before fl_view_new. CMake force-includes it only in the runner
and desktop_multi_window C++ targets so main and remote-window engines agree.
The local macro redirects only their view construction; it does not patch the
shared plugin cache or the Flutter SDK. Unset keeps the engine's original
default, and explicit impeller remains selectable. This uses the current SDK's
public project API; older Flutter SDKs were not tested.

Both Debug and Release Flutter bundles rebuilt successfully with two jobs.
Every controlled case emitted two project-renderer=skia messages, no Impeller
backend message, and fresh 4K client submissions. Release /proc mappings
confirmed both the Release Rust core and libapp.so AOT; DISPLAY was absent.
The remote desktop --server executable/core also came from the separate
matching Release test bundle. A root service flag alone was not taken as proof
of desktop-child activation.

## Completed 2x2 measurements

After the user confirmed the pause, each case used a fresh service/client,
55-second playback and the report-time window from source launch+15 to +50s.
No builds ran during these intervals. The quality request remained custom33 /
60 FPS; actual QoS is reported rather than forced. Serial NV12 and the original
NVENC preset were used throughout. All captured desktops were 3840x2160,
all server encoder samples reported hardware_encoder=true and all client
intervals used ffmpeg/hevc/AV_HWDEVICE_TYPE_CUDA.

| Both endpoints | Appsink | Source /s | Accepted /s | Submit FPS | QoS mean | Convert ms | Encode ms | Submit ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Debug | Default | 42.54 | 42.12 | 42.13 | 60 | 6.63 | 15.47 | 7.78 |
| Debug | Unpaced | 42.28 | 41.63 | 41.64 | 60 | 6.89 | 15.82 | 8.36 |
| Release | Default | 39.38 | 39.35 | 39.39 | 59.77 | 8.07 | 16.16 | 27.82 |
| Release | Unpaced | 35.79 | 35.53 | 35.75 | 59.43 | 7.83 | 15.86 | 28.18 |

Timing columns are means of window p95 values, not additive end-to-end latency.
Each stable interval had zero client overflow/discard/decode errors and server
shared-queue peak0. ACK window-p95 means were 0.42/0.41/0.27/0.27ms; send queue/window-p95
means stayed around 0.2–0.32ms. Hardware success does not establish 4K60.

The viewport was 3740x2112 for Debug/default, Debug/unpaced and
Release/unpaced, and 3739x2112 for Release/default, all verified on HDMI-1.
In the probe's stable elapsed12..47s source records, time position advanced
across loop boundaries; pause=false, NVDEC and estimated-vf-fps about60.
Player frame-drop maxima per loop were respectively 1/0/0/3, with decoder
and delayed-frame counters0. The counters reset when the short file loops;
they are not aggregate drop counts or compositor presentation proof.

Unpaced cases emitted four recorder-activation messages each and the actual
Release desktop child had RUSTDESK_PIPEWIRE_UNPACED=1. Default cases emitted
none. This confirms the experiment ran, but **it showed no throughput benefit
in this environment**. It remains opt-in and off by default. No code removes
server pacing, increases queues, changes quality or forces a lower resolution.

**4K60 still failed.** Source production closely tracked accepted/submitted
rates; queues did not show sustained buildup. The additional Release submission
wait (about28ms versus8ms) is a separate observation needing client/engine/GPU
attribution. The final Flutter focus log in each case was active=true, but no
physical presentation measurement was available. Other GPU workloads remained
active and source throughput drifted down over time. This sequential matrix
is not a randomized or same-load proof that Release or unpaced itself caused
all FPS differences; no percentage regression or improvement is claimed.

## Excluded attempts and limits

The first exploratory Debug/default video viewport was 3072x1728 and was
excluded from the comparable matrix. The maximization helper now waits between
fullscreen exit and maximizing, then waits for the configure to settle. It
still checks output identity; measured viewport size remains necessary.
An exploratory Release/Impeller run is also excluded because the client
renderer did not match Debug/Skia.

The first Release service attempt failed GStreamer PLAYING with
"Element failed to change its state" and disconnected. A fresh service/client
retry succeeded; no unique root cause or permanent fix for that intermittent
startup failure was established. One controlled Debug source invocation
returned nonzero and was discarded/repeated; its failed invocation is not
included in the matrix. Successful cases all completed their bounded probe.
Do not turn either transient failure into a confirmed compiler/driver diagnosis.

No fresh keyboard, clipboard, multiscreen, long low-memory, simultaneous dual
4K60, weak-network quality or physical presentation acceptance was performed.
The next focused investigation should separate active-only PipeWire capturers
from the currently retained unused-screen pipeline, and isolate Release client
submission/engine scheduling with mixed endpoint builds under comparable GPU
load. GPU-native conversion remains a later path requiring its own validation.

## Verification / artifacts

Commands passed:

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release res/dev/build_linux.sh
# After the native renderer adapter (no Rust changes), in flutter/:
PATH="$HOME/.local/share/rustdesk-dev/build-tools:$PATH" RUSTDESK_BUILD_JOBS=2 CMAKE_BUILD_PARALLEL_LEVEL=2 flutter build linux --release --no-pub
PATH="$HOME/.local/share/rustdesk-dev/build-tools:$PATH" RUSTDESK_BUILD_JOBS=2 CMAKE_BUILD_PARALLEL_LEVEL=2 flutter build linux --debug --no-pub
# In repository root:
python3 res/dev/test_display_metrics_time_filter.py
python3 -m py_compile res/dev/summarize_display_metrics.py res/dev/test_display_metrics_time_filter.py res/dev/playback_motion_probe.py
bash -n res/dev/build_linux.sh res/dev/run_linux.sh
git diff --check
```

Time-filter regression: 1 passed. The native builds and real main/remote-window
activation verify the renderer hook; no synthetic implementation-mirroring
renderer test was added. Only the generated analyzer-header change was restored.

Core hashes match local and OMEN staged bundles:

- Debug core: 5e2c82ba4f2052ab29eee307e1f3364b601aac8e8b6d12676353fb73ea35c887
- Release core: 24c5647069587d34ea18b3fdc8b54a6dfb3bfe8678a81c18b163df971a483d3a
- Release Flutter AOT: 78202626fa1a95fe36c51a055fb06f55a6c8a8ba681b889583b12dbad5659a6c
- Final Debug runner: deb35ef803364aa79a5e4ee12fb3da244a5362f56f4a8b9d7e01737775bf6bc2
- Final Release runner: 3c0b7b0a7d19315d3fbd8354fee647dfc71d3e116160ee3b1a641c91889525c9
- Release desktop_multi_window plugin: 6cf9b628c99e7b5960682582f079306d9a6142aa1785d80f09f57c50200e0cdb

Private evidence: ~/.cache/rustdesk-dev/clock-controlled-{debug,release}-{clock,unpaced}-*
contains sanitized stage summaries, bounded source reports and private runtime
logs. Full logs/configuration/screenshots/VM URLs are not committed or uploaded.

Additional regression surface for this verification turn:

- flutter/linux/renderer_view.h: new explicit development project setting.
- flutter/linux/CMakeLists.txt: include the adapter in two Linux C++ targets.
- res/dev/run_linux.sh: export the already-validated renderer choice.
- res/dev/playback_motion_probe.py: allow asynchronous fullscreen exit before
  requesting maximization; no capture/codec behavior change.

No shared Rust trait, signature, dependency revision, submodule, installed
binary, protocol, authentication or default quality policy changed.

## Cleanup / rollback

All bounded source probes exited. The temporary /run service override was
removed and original OMEN rustdesk.service restored active. The three local
quality/FPS fields were restored and compared with the private backup, without
printing or replacing credentials. The default Debug native client reconnected
to AOC: fresh PeerInfo1.5.0/Linux/currentDisplay0, H265 statistics and zero
metrics events. This is reconnect readiness, not repeated input acceptance.

Separate /opt test bundles and private staging/build logs remain for reuse;
installed binaries were not replaced. No network, monitor or unrelated service
configuration changed. To restore original sink behavior leave
RUSTDESK_PIPEWIRE_UNPACED unset. Leaving RUSTDESK_DEV_BUILD_MODE unset selects
Debug. For the native renderer adapter, leaving RUSTDESK_DEV_RENDERER unset
when directly launching the bundle preserves the engine default. A scoped
revert of the Linux adapter/CMake hook/launcher export removes that hook.
No permanent deployment or Gitea push performed.

User clarification after the tests: the earlier report of a seemingly stuck
window referred to needing the remote desktop-sharing selection, not a client
hang. Keep this separate from the logged first-attempt GStreamer PLAYING
failure; no causal link between those events was established. A private rendered
snapshot of the restored Debug remote view contained the OMEN desktop and the
Tailscale TCP connection was established. Snapshot visibility / cached model
statistics alone cannot prove physical display freshness or replace any new
remote-side Portal approval. If a new sharing prompt appears, select the
intended screen on OMEN and approve it there. No chooser was bypassed or
approved blindly, and authorization waiting was not included in stable FPS data.

Sanitized verified lessons appended to NAS knowledge base and read back:
`experience/2026-10-23-rustdesk-1-5-0-flutter-3-47-linux-build-and-tailscale-dual-m.md`.

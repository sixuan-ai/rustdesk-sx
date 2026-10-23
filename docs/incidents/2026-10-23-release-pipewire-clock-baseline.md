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
`/opt/rustdesk-clock-debug` or `/opt/rustdesk-clock-release` directory and use
only `/run/systemd/system/rustdesk.service.d/90-development-verification.conf`:

```ini
[Service]
ExecStart=
ExecStart=/opt/rustdesk-clock-release/rustdesk --service
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

## Current validation and pending measurement

Both hardware builds passed: Debug and the full optimized Rust/Flutter Release
bundle. Release Rust compilation took about 9m56s on this loaded machine.
Shell syntax, Python compilation, the time-filter regression test (1 passed)
and git diff --check passed. Debug temporary service/client connected to the
AOC with fresh 3840x2160 submissions and ffmpeg/hevc/AV_HWDEVICE_TYPE_CUDA;
server telemetry confirmed hardware_encoder=true and target_fps=60. This was
an idle desktop readiness check, not a dynamic 4K60 throughput result.

Core SHA-256 (matching local and staged OMEN artifacts):

- Debug: 5e2c82ba4f2052ab29eee307e1f3364b601aac8e8b6d12676353fb73ea35c887
- Release: 24c5647069587d34ea18b3fdc8b54a6dfb3bfe8678a81c18b163df971a483d3a
- Release Flutter libapp.so: 78202626fa1a95fe36c51a055fb06f55a6c8a8ba681b889583b12dbad5659a6c

**The 2x2 performance matrix has not run.** The new client was connected, but
source playback was held while awaiting a fresh user foreground/pause
confirmation; a pause granted for an earlier task was not assumed to remain
in effect. No source was launched. Consequently no Release FPS gain, appsink
clock benefit, runtime activation of the unpaced mode or 4K60 pass is claimed.
The full Release remote connection still needs runtime validation.

The next run should compare Debug/default, Debug/unpaced, Release/default and
Release/unpaced, fixed quality 33 / target60 / original NVENC profile and serial
NV12. Save sanitized source/client/server evidence per case using the bounded
sampling procedure above. Repeat an effective pair if needed before changing
any default. These are measurement prerequisites to later capture lifecycle
or GPU-native conversion changes; no speculative default optimization was
made in this task.

## Cleanup / rollback

The waiting orchestrator was stopped before playback. The temporary /run
service override was removed, original OMEN rustdesk.service restored active,
and the three local quality/FPS fields restored from a private backup without
printing or replacing credentials. The default Debug native client was
relaunched with metrics and all experimental flags unset. The independent
/opt test bundles and private staging/build logs remain for the next test;
the installed binaries were never replaced. No network, monitor or unrelated
service configuration changed.

To return to the original capture clock, leave RUSTDESK_PIPEWIRE_UNPACED unset.
To return to the original development build behavior, leave
RUSTDESK_DEV_BUILD_MODE unset. No permanent deployment or Gitea push performed.

Post-cleanup check: fresh PeerInfo version1.5.0/Linux/currentDisplay0 and H265
statistics were present, and the restored client emitted zero display_metrics
events. This confirms reconnect/readiness only; no fresh keyboard, clipboard,
multiscreen or dynamic throughput acceptance is claimed here.

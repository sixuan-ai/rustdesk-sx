# 2026-10-23 Wayland 4K throughput isolation

## Summary

Added opt-in PipeWire source/consumer measurements and bounded stage probes on
`codex/stable-1.5.0-dev`, starting at `8977234f2`. A better calibrated source
produced about 44 submitted FPS at 3840×2160/H.265. **4K60 remains unverified.**
The previous approximately 14 FPS result tracked a slow GTK test window; the
new number is a measurement correction, not a demonstrated performance gain
from these monitoring changes. No encoder preset or transport policy changed.

## Environment and scope

- Observation: 2026-10-23. Local Ubuntu 26.04.1/GNOME Wayland, RTX 5060 Ti;
  OMEN GNOME Wayland, RTX 4060, NVIDIA 595.99.02.
- Flutter 3.47.7, Rust 1.99.1, Linux Debug hardware-codec bundle, two build jobs.
- Tailscale direct IP/TCP 21118. AOC HDMI-1: 3840×2160, 144 Hz, GNOME scale 1.5;
  internal eDP-1: 2560×1440, 60 Hz. Live output names were checked.
- Other GPU applications remained running. GPU utilization was about 69% even
  with RustDesk stopped. These are loaded-host observations, not controlled
  idle-machine comparisons.
- OMEN used a separate `/opt/rustdesk-metrics-verification` bundle via a
  temporary `/run/systemd/system/rustdesk.service.d/90-development-verification.conf`.
  Installed binaries were not overwritten.

## Symptoms and investigation

### Calibrate the producer before interpreting remote FPS

`video_load_probe.py --unpaced-sink` submitted about 60 buffers/s but its GTK
frame clock painted only about 14–15 times/s. The direct GLES3 GLArea fixture
also rendered about 15–16 times/s using NVIDIA, including while only the
RustDesk service was temporarily stopped. This establishes a source limitation;
it does not identify a unique GTK, driver, compositor or GPU-workload cause.

`playback_motion_probe.py` instead uses mpv GPU-next, native Wayland/Vulkan and
NVDEC. It logs output, dimensions, pause, playback position and drop counters.
The output must be verified after mapping: the startup fullscreen output option
alone initially placed the window on eDP-1. A post-map fullscreen request and
live `display-names` verification selected HDMI-1. These player counters are
not compositor presentation acknowledgments.

One continuous fullscreen playback test showed advancing, unpaused playback
with only roughly one duplicate capture buffer/s. Maximizing the same player
on the same output restored capture. Trigger and root cause remain unresolved;
this is not evidence that every Vulkan fullscreen window fails. A temporary
capture sink scheduling experiment did not recover the slow GTK fixture and
was removed. Capture synchronization/deadline defaults remain unchanged.

### Bounded Tailscale TCP test

An ephemeral iperf3 server bound to the peer's Tailscale address and port 15201
was used for eight-second tests requested at 50 Mbps:

```bash
iperf3 -c <OMEN_TAIL_IP> -p 15201 -R -t 8 -b 50M -J
iperf3 -c <OMEN_TAIL_IP> -p 15201 -t 8 -b 50M -J
```

| Direction | Received | Sender retransmissions |
| --- | ---: | ---: |
| OMEN → local (video direction) | 50.064 Mbps | 0 |
| Local → OMEN | 30.61 Mbps | 14 |

These are observed bounded throughput results, not maximum link capacity or
proof against transient loss. The video direction had headroom over the
observed remote stream; no new transport is justified by these samples alone.

### Codec-only matrix

`codec_stage_bench.py` generates eight NV12 frames into tmpfs, encodes 180
frames with HEVC NVENC, CBR 12 Mbps, zero B frames/delay, then decodes with CUDA
and downloads NV12. Wall time includes codec initialization, excludes fixture
generation, desktop capture, RGB conversion, network and display.

| OMEN resolution | p4 encode FPS | p1 encode FPS | p4 decode/download FPS | p1 decode/download FPS |
| --- | ---: | ---: | ---: | ---: |
| 1920×1080 | 145.02 | 181.52 | 247.56 | 237.79 |
| 2560×1440 | 109.52 | 147.33 | 219.77 | 210.76 |
| 3840×2160 | 65.93 | 92.44 | 168.20 | 155.10 |

Local 4K p4 encode: 87.30 FPS; CUDA decode/download: 295.67 FPS. This shows
synthetic codec throughput feasibility, not RustDesk 4K60 or text quality.
The application has not been changed to select p1.

### Actual remote pipeline

A 75-second maximized playback run started after confirming the new client
was connected. Statistics use the approximately 50-second interval between
start+15 and start+65 seconds. Input video is 4K60; the maximized video viewport
was about 3740×2112, while the captured/encoded desktop was 3840×2160. Borders
and some static desktop area therefore remain in the capture.

| Measurement | Result |
| --- | ---: |
| PipeWire source buffers | 62.55/s |
| Consumer pulled / accepted | 43.84 / 43.76 per second |
| Duplicate pixels / pull timeouts | 0.08 / 0.36 per second |
| Actual server QoS target | 60 FPS |
| Client received / submitted | 43.75 / 43.75 FPS average |
| Client pending peak | 3 |
| Overflow / discarded / decode errors | 0 / 0 / 0 |
| Shared server queue peak | 0 |

Mean of per-window p95 values (not a merged frame percentile):

| Stage | ms |
| --- | ---: |
| Consumer map | about 0 |
| Compare/copy | 6.65 |
| Consumer pull wait | 3.73 |
| Server capture call | 9.79 |
| Server pixel conversion | 6.77 |
| Server encode call | 16.07 |
| Server enqueue | 0.08 |
| Video queue wait / send path | 0.32 / 1.90 |
| Client queue wait | 2.26 |
| Client decode/convert | 12.80 |
| Flutter submit | 10.72 |

Stages can overlap; summing these percentiles is not an end-to-end frame latency.
Submitted callbacks are not physical display FPS. The gap between producer and
consumer and the low network queues narrow the next investigation to capture
consumption, copy/conversion and synchronous encoding/scheduling. No unique
remaining bottleneck has been proven.

## Implementation and regression surface

- `libs/scrap/src/wayland.rs`: registers a Wayland-only metrics module.
- `libs/scrap/src/wayland/pipewire.rs`: optional recorder-local state and thin
  timing/counter hooks are necessary to distinguish pull wait, duplicates,
  accepted buffers, PTS deltas and copy stages. A source pad probe is attached
  only with `RUSTDESK_DISPLAY_METRICS=1`. PTS deltas and monotonic arrival deltas
  remain separate clock domains. Existing buffer, crop, comparison, appsink
  dropping, `always-copy`, videoconvert and sink scheduling behavior is retained.
- `src/server/video_metrics.rs` and `src/server/video_service.rs`: the existing
  optional report includes the real QoS FPS target via its sole caller.
- `res/dev/summarize_display_metrics.py`: parses source and consumer events
  by PipeWire node; preserves existing server/client event support.
- `res/dev/video_load_probe.py`: reports GTK paint counts; an explicit test-only
  unpaced option distinguishes sink submission from actual GTK drawing.
- New bounded diagnostic scripts isolate codecs, native GL rendering and
  Vulkan playback. No shared trait, protocol, lockfile or submodule changed.

Metrics default off; samples are bounded to 512 values per stage/window. The
on-state probe/logging has overhead, so the numbers are diagnostic observations.
Disabled metrics retain the existing pixel-processing path and attach no probe.

## Reproduction and verification

Build: `RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh` passed (two jobs).
Core SHA-256: `8dd572609e61fee8730aa64e79efb6c445c852e071cae8ef8a9bb39cf00662dd`.

Focused metrics test: **1 passed**, 24 filtered:

```bash
env CARGO_HOME=/home/x/.local/share/rustdesk-dev/cargo-hwcodec-f184b11b5531 \
 RUSTDESK_HWCODEC_SYSTEM=1 CARGO_BUILD_JOBS=2 CARGO_PROFILE_DEV_DEBUG=0 \
 CMAKE_BUILD_PARALLEL_LEVEL=2 CMAKE_POLICY_VERSION_MINIMUM=3.5 \
 CXXFLAGS='-include cstdint' \
 PKG_CONFIG_PATH=/home/x/.local/share/rustdesk-dev/pkgconfig \
 PATH=/home/x/.local/share/rustdesk-dev/build-tools:/home/x/.local/share/rustdesk-dev/tools/bin:/home/x/.cargo/bin:/home/x/flutter/bin:/usr/bin:/bin \
 cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland \
 wayland::capture_metrics::tests
```

`python3 -m py_compile` for all five changed/new Python helpers and
`git diff --check` passed. Codec probes ran on both hosts; the playback/capture
measurements above ran through the actual OMEN Tailscale connection.

Example bounded probes (OMEN graphical session environment required):

```bash
python3 res/dev/codec_stage_bench.py --frames 180
python3 res/dev/playback_motion_probe.py --video <generated-4k60-video> \
 --output HDMI-1 --mode maximized --seconds 75
python3 res/dev/summarize_display_metrics.py <filtered-client-or-server-log>
```

Raw evidence stays private under local `/home/x/.cache/rustdesk-dev/`:
`maximized-connected-{client,server}-stable.log`, `omen-codec-stage-bench.jsonl`,
`local-codec-stage-bench.jsonl`, and `iperf-{reverse,forward}-50m.json`.
Build/test logs: `capture-final-build.log`, `capture-metrics-tests-final.log`.
OMEN's synthetic source log is under
`/home/x/.cache/rustdesk-wayland-verification/maximized-connected.log`.
No screenshots, credentials, private VM service URLs or complete logs are committed.

## Cleanup, rollback and remaining work

All bounded source/player/iperf tests exited. Removed the temporary service
override, reloaded systemd and restarted only RustDesk. Verified active original
`/usr/bin/rustdesk --service` and `/usr/share/rustdesk/rustdesk --server`.
Restored only the three test quality/FPS preferences from a private backup,
preserving credentials and unrelated peer settings. Relaunched native Wayland
development client without DISPLAY or the metrics flag; real peer version
1.5.0/H.265, AOC display 0 and updating quality statistics confirmed connection.
This cleanup check is not a repeat 4K60 or keyboard/multiscreen acceptance test.

Before rebuilding, stop only the development bundle. `/proc/<pid>/exe` can end
in ` (deleted)` after a previous build replaces its executable; strip that suffix
when matching the exact bundle path or stale clients can survive unnoticed.
Main-window initialization before a separate `--connect` avoids the previously
observed direct-start GTK EGL failure; its root cause remains out of scope.

Code rollback is a scoped revert; metrics can be disabled simply by omitting
`RUSTDESK_DISPLAY_METRICS`. Cached test bundles/video remain for reproduction.
No persistent OMEN service override or global display mode change remains.

Next: optimize/compare capture memory work and conversion/encode scheduling,
then controlled low-latency H.265 preset tests with visual quality checks. Only
after that evaluate codec changes and per-display adaptive budgets. Release,
physical presentation FPS, repeatable fullscreen behavior, dual-screen 60 FPS
and constrained-bandwidth quality are still unverified.

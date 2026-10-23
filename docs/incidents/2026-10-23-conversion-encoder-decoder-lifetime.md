# 2026-10-23 NV12 / NVENC stages and Linux decoder lifetime

## Summary

Work based on `79191a398`, branch `codex/stable-1.5.0-dev`.

- Linux RAM decoder reset now releases the old hardware decoder before creating
  its replacement. Explicit Flutter full-screen-selection sets retire unused
  decoder workers and reject late packets for those screens.
- Added independently opt-in parallel NV12 conversion and a Linux development
  NVENC p1/ultra-low-latency profile. Both remain **off by default**: isolated
  stage improvements did not establish stable end-to-end FPS gains or acceptable
  p1 text/detail quality. The baseline serial conversion/encoder profile remains
  available without either environment variable.
- Added frame-ack wait and pacing-sleep metrics without changing frame pacing.
- Fixed stale compiled C++ artifacts when changing the isolated hwcodec overlay.

**4K60 did not pass.** In the user-confirmed foreground run, target was 60,
source buffers averaged 48.21/s, accepted buffers 47.05/s and client submissions
47.07 FPS. Four successive screen switches retained CUDA H.265 with no decode
errors or CUDA OOM in this run. This does not prove all low-memory cases resolved.

## Environment / scope

Observed 2026-10-23: Ubuntu 26.04.1/GNOME Wayland, Flutter 3.47.7, Rust 1.99.1,
Linux Debug/Skia/hwcodec bundle. Local RTX 5060 Ti 8 GB, OMEN RTX 4060. Other
GPU workloads remained running; no global display mode or GPU settings changed.
Local client started without DISPLAY. Actual target was OMEN's Tailscale IP,
RustDesk TCP 21118. OMEN AOC HDMI-1 desktop capture was 3840×2160; inner screen
2560×1440. No protocol or dependency-version changes were required.

Each bounded source was native Wayland/Vulkan mpv with NVDEC and a synthetic
4K60 file, maximized on verified HDMI-1. Video viewport was about 3740×2105 or
3740×2112, with small static desktop borders inside the 3840×2160 capture.
Playback position advanced, pause=false and the stable sources had zero drop
counters. These are not compositor presentation acknowledgments. Peer quality
was temporarily custom 33 / 60 FPS. Test services used only a separate /opt
bundle and a /run service override, not the installed OMEN binaries.

## Root causes addressed

### Decoder allocation peaks and inactive workers

`VideoHandler::reset` previously evaluated `Decoder::new(...)` while the old
decoder was still alive, then dropped the old value during assignment. CUDA
contexts/surfaces could therefore overlap. In addition, `video_threads` retained
workers for displays no longer captured. Previous investigation observed CUDA
OOM with only 121 MiB free locally; this is not proof of a general leak.

The new Linux RAM helper clears H.264/H.265 RAM decoder options before reset.
It does not change VRAM-texture decoder reset behavior. A Linux Flutter/hwcodec
selection object tracks explicit complete `CaptureDisplays.set` requests:
retired workers are dropped; their existing discard-on-drop path drains queued
work and closes the receiver; late frames cannot recreate them. A new selected
screen still starts through the existing lazy worker/keyframe path.

Every lookup of this new selection is local to the connection: update from an
outgoing full set, retain workers using that set, and gate incoming video frames.
The full set already accounts for other Flutter windows. Invalid-only sets
preserve the previous selection, matching server rejection. Incremental add/sub
requests return to legacy behavior; camera sessions bypass this feature. The
existing `video_format == Unknown` distinguishes the initial worker so removing
the final inactive worker does not reinitialize the user's recording preference.

### Pixel conversion and encoder options

The original NV12 conversion already uses libyuv SIMD. The optional two-part
conversion splits at an even row, keeping each chroma row with its two RGB rows.
Source/destination strides and plane bounds are checked. Parent plus one scoped
worker convert disjoint slices; failure reports an error. The hook applies only
to Linux BGRA/RGBA NV12 at least 2560×1440, with the flag enabled; unsupported
sizes/layouts retain the serial call. Tests compare all output bytes, including
padding, for BGRA/RGBA with a 2/4-row split.

The optional NVENC overlay sets p1, tune=ull, rc-lookahead=0 and zerolatency=1
before codec initialization. The existing zero-delay/B-frame settings remain.
Only NVENC and literal opt-in 1 use this path. Installed FFmpeg encoder help
identifies p1 as fastest/lowest quality, so throughput alone is insufficient to
make it the default. The actual C++ initialization log confirms its activation.

### Pinned git dependency build cache

Replacing C++ files in the same pinned git checkout did not rebuild hwcodec:
the binary lacked the new profile string and runtime activation message even
though the environment flag reached the server. Cargo treats the revision as
immutable. An early `stage-fast` attempt is excluded from NVENC conclusions.

`prepare_hwcodec.py` now hashes all overlay patches into a repository-target
stamp. A changed/missing stamp runs `cargo clean --package hwcodec` using the
isolated Cargo home before building. Only this dependency's build artifacts are
invalidated; immutable shared source caches, Cargo.lock and submodules are not
modified. After rebuilding, `strings` and actual encoder logs both contained
`NVENC low-latency profile: p1/ull/lookahead=0`.

## Measurements

55-second source runs; stable logs select UTC report timestamps from launch+15
to launch+50 seconds. Client FPS is time-weighted; millisecond columns below
are means of window p95 values, not merged frame percentiles or additive latency.

| Case | Submit FPS | QoS target | Convert ms | Encode ms | Source buffers/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline, both flags off | 46.61 | 59 | 7.48 | 15.98 | 59.76 |
| Parallel NV12 only | 43.10 | 55.37 mean | 5.50 | 16.03 | 56.90 |
| Parallel + verified NVENC low latency | 48.48 | 60 | 5.70 | 11.85 | 52.26 |
| Final user-confirmed foreground | 47.07 | 60 | 5.71 | 11.87 | 48.21 |

These loaded-host observations support about 26% lower conversion/encoding
window p95 in their respective modes, **not** an end-to-end FPS improvement
claim. Source rates, duplicate counts and local submission delays varied.
All four stable windows had zero overflow, discard and decode errors; shared
server queue peak was zero. The initial parallel-only run had approximately
30 ms Flutter submission p95; the foreground run about 8.11 ms.

Foreground final run: source/consumer node 130, accepted 47.05/s, duplicate
pixels 1.08/s, pull timeouts 2.27/s. Source arrival window p95 mean 36.86 ms;
capture call 15.09 ms includes waiting for samples. Frame-ack wait was 0.44 ms,
pacing sleep 7.33 ms, send queue wait 0.32 ms and send path 2.12 ms. Sleep
includes iterations without a new frame and cannot be counted as pure wasted
encoding time. No pacing policy, queue depth or reliability change was made.
This run narrows the next work toward source production/capture timing rather
than blaming a saturated socket queue. It does not establish a unique capture
or compositor root cause.

### Multiscreen validation

After the foreground throughput interval, user-authorized pause remained in
effect for 1→0→1→0 switches. Each result had fresh submissions:

| Display | Resolution | Decoder | FPS at check | Decode errors |
| --- | --- | --- | ---: | ---: |
| Inner 1 | 2560×1440 | H.265/CUDA | 33 | 0 |
| AOC 0 | 3840×2160 | H.265/CUDA | 34 | 0 |
| Inner 1 | 2560×1440 | H.265/CUDA | 34 | 0 |
| AOC 0 | 3840×2160 | H.265/CUDA | 33 | 0 |

Source video had ended during these switches; these FPS are desktop freshness
checks, not the 4K60 benchmark. Logs showed a worker exit for each retired screen,
no CUDA OOM and no first-frame decode failure. Half-second NVML sampling of the
development CUDA process reported 584–762 MiB during the switch interval.
Sampling can miss short allocation peaks. Warm-up/cache fluctuations remain;
four switches do not prove a long-duration memory plateau. Available memory
was higher than in the earlier 121 MiB-free failure; no strict same-load OOM
comparison is claimed. Simultaneously displaying both screens still requires
memory for both active decoders and was not tested here.

## Commands / regression surface

Build: `RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh` passed with two jobs.
Use the isolated environment from the preceding incident for focused tests:

```bash
cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland parallel_nv12::tests
cargo test --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste,hwcodec client::linux_video_resources::tests
python3 -m py_compile res/dev/prepare_hwcodec.py res/dev/summarize_display_metrics.py
git diff --check
```

Conversion: 1 passed; selection: 2 passed. Python compilation and diff checks
passed. Bench/multiscreen artifact SHA-256:
`8329728e60a5f52239784c46671453cbaecec0ab7dfd75cb51e300586f823b77`.
The final source removed reset assignments for untested VRAM-texture options
(not enabled in this build), preserving their previous reset path. Final rebuilt
core SHA-256: `32e9fb3eef94cd78d6bc3d2dd83e3c4356aa42f2ad2262139ab7a2f0d0dcc9ee`.

Existing files touched, and why:

- `libs/scrap/src/common/codec.rs`: narrow Linux RAM decoder release helper;
  no shared trait/signature changes.
- `src/client.rs`: Linux module registration and release-before-reset hook.
- `src/client/io_loop.rs`: selection update/gate/worker retirement; Linux-only
  format assignment ordering preserves one-time recording initialization.
  Unsupported builds keep their previous order/initialization condition.
- `libs/scrap/src/common/convert.rs`: optional Linux NV12 helper hook; serial
  path retained with flags off or unsupported formats/layouts.
- `res/dev/prepare_hwcodec.py`: include the new reviewable overlay patch and
  invalidate stale compiled artifacts when its content changes.
- `src/server/video_metrics.rs`: forward only literal performance opt-ins to
  the actual desktop child and report bounded ack/sleep timing samples.
- `src/server/video_service.rs`: four timing hooks around existing wait/sleep.
- `res/dev/summarize_display_metrics.py`: parse the two added timing fields.

New selection and conversion logic live in their feature modules. No lockfile,
submodule, network protocol, ID/relay behavior or general encoder trait changed.

## Reproduction, cleanup and rollback

Development knobs, set on OMEN's service (the existing explicit child helper
forwards literal 1 even with metrics off):

```ini
Environment=RUSTDESK_DISPLAY_METRICS=1 RUST_LOG=info RUSTDESK_PARALLEL_NV12=1 RUSTDESK_NVENC_LOW_LATENCY=1
```

Run the source in the live OMEN graphical session:

```bash
env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
 WAYLAND_DISPLAY=wayland-0 GDK_BACKEND=wayland \
 python3 playback_motion_probe.py --video motion-4k60.mkv --output HDMI-1 --mode maximized --seconds 55
python3 res/dev/summarize_display_metrics.py <stable-client-or-server-log>
```

Raw private evidence lives in `/home/x/.cache/rustdesk-dev/`:
`stage-{base,parallel,tuned,final,foreground}-*-stable.log`, corresponding source
logs, `stage-switch-results.log`, `stage-cycle-gpu.log`, and build/test logs with
`scheduling-` prefix. `stage-fast` used a stale pre-patch C++ artifact and is
excluded. Private orchestration and VM helper logs are not committed; reproducible
build, source, flags and interpretation commands are recorded here. No complete
environments, screenshots, passwords or VM authentication URLs are included.

All bounded playback probes exited. Removed the /run service override,
daemon-reloaded and restarted only RustDesk. Original service/server active;
installed OMEN files unchanged. Restored only image_quality,
custom_image_quality and custom-fps from a private backup, preserving credentials.
The final rebuilt native Wayland client was relaunched without DISPLAY or
metrics, reconnected to AOC with real peer 1.5.0/H.265 and updating speed/FPS;
metrics event count was zero. `ss -tn` confirmed the Tailscale IP TCP 21118
connection. This restoration smoke check used the final rebuilt artifact;
it was not a repeat performance benchmark or input/clipboard acceptance test.

Omit both performance flags to retain serial conversion and the upstream
encoder profile. Revert this scoped commit to roll back Linux decoder lifecycle
changes. Cached test artifacts remain for reproduction. No permanent OMEN
deployment was performed.

Remaining work: sustained 4K60/physical presentation measurement, Release
comparison, source production/compositor/capture timing, longer and genuinely
low-memory switch testing, incremental selection retirement, simultaneous
multiscreen hardware budget, and p1 text/detail quality at constrained bitrate.
Keyboard, clipboard, recording, cameras, VRAM-texture decoding and other
platforms were not runtime-tested this turn.
The earlier sink-clock experiment used a GTK fixture that was subsequently
found to paint slowly; that negative result does not replace a future clock
comparison using the calibrated native playback source.

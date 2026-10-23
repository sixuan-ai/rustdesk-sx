# 2026-10-23 PipeWire retained-buffer comparison

## Summary

Follow-up to `2026-10-23-capture-throughput-isolation.md`, starting from
`79212e24f` on `codex/stable-1.5.0-dev`. The PipeWire recorder already owns the
previous readable mapped buffer, but copied every changed full frame into an
additional `saved_raw_data` vector for the next equality check. Compare against
the existing mapping instead. This removes one full-frame cache copy and its
allocation (33,177,600 bytes at 3840×2160) on the optimized path; it is not a
zero-copy capture/encode implementation.

The optimized path is enabled for PipeWire. Set
`RUSTDESK_PIPEWIRE_REUSE_BUFFER=0` in the server environment to use the original
vector comparison/copy path. Metrics remain independently opt-in with
`RUSTDESK_DISPLAY_METRICS=1`. Only literal 0/1 capture overrides are forwarded
through Linux's explicit sudo desktop-child environment list.

## Environment and measurement scope

2026-10-23: Ubuntu 26.04.1/GNOME Wayland, Flutter 3.47.7, Rust 1.99.1, Linux
Debug hardware bundle; local RTX 5060 Ti and OMEN RTX 4060. Same source and
Tailscale direct connection as the preceding incident. Other GPU applications
remained running. No global resolution, refresh rate or GPU settings changed.

OMEN's AOC HDMI-1 desktop capture is 3840×2160. The bounded mpv Wayland/Vulkan
NVDEC fixture uses a 4K60 synthetic video, maximized viewport 3740×2105.
Its output, unpaused state, advancing playback position and zero playback drop
counters were checked. Player counters do not prove compositor presentation FPS.
Quality was custom 33 with target 60 FPS, H.265/NVENC and CUDA decoding.

## Investigation and result

Two variants of the same experimental binary were selected with the server
environment switch; a fresh client connection was confirmed after service
restarts. Each fixture ran for 55 seconds; metrics use UTC report timestamps
between fixture launch+15 and launch+50 seconds. The desktop service child's
selected environment keys were checked, without printing complete environments.

| Stable-window measurement | Original copy | Retained mapping |
| --- | ---: | ---: |
| Client submitted FPS (weighted mean) | 43.16 | 50.38 |
| Consumer accepted buffers/s | 43.18 | 50.40 |
| Comparison/copy window p95 mean | 5.92 ms | 0.24 ms |
| Server capture-call window p95 mean | 13.02 ms | 7.20 ms |
| Pixel conversion window p95 mean | 6.69 ms | 7.75 ms |
| Encode-call window p95 mean | 16.16 ms | 15.98 ms |
| Actual QoS target | 60 FPS | 60 FPS |
| Client overflow/discard/decode errors | 0/0/0 | 0/0/0 |
| Server shared queue peak | 0 | 0 |

These loaded-host A/B samples show a roughly 17% submission-rate improvement
with substantially less comparison/copy work, not a guarantee across workloads.
Producer buffers were 52.27/s and 56.29/s respectively; surrounding load and
compositor scheduling are not identical. Window percentile means must not be
summed into an end-to-end frame latency. **4K60 is still not achieved.**

Switching back to the original path and repeating the 55-second fixture gave
44.24 submitted FPS and 6.33 ms comparison/copy window p95 mean (consumer
44.21/s, producer 55.62/s, QoS 60, zero overflow/discard/decode errors). Thus
the observed gain is about 14–17% against the two original-path runs. The local
Flutter submission timing varied in this repeat, reinforcing that these are
loaded-host results rather than controlled end-to-end latency benchmarks.

The first attempted optimized fixture had no live client after a service
restart; stale Dart model statistics were detected because server metrics had
stopped. That attempt is excluded. Reopening the client and checking fresh
server capture events established the actual optimized run above.

## Correctness and regression surface

- New `libs/scrap/src/wayland/buffer_compare.rs` compares the entire byte slice,
  including lengths; it uses no hashes or sampled pixels. Tests cover first
  frame, unchanged pixels, the final pixel, size change and mapped-buffer
  ownership when an upstream GstBuffer clone is made writable.
- `libs/scrap/src/wayland.rs` registers this Wayland-only helper.
- `libs/scrap/src/wayland/pipewire.rs` adds one recorder-local switch and chooses
  the comparison path. `always-copy=true` and the existing owned read mapping
  keep the previous pixels alive. No extra mapping or cross-thread frame cache
  is introduced. Crop, pixel-format conversion, appsink dropping, source buffer
  copying and encoder/transport behavior are unchanged. Invalid-size buffers
  are not installed as the comparison reference on the optimized path.
- `src/server/video_metrics.rs` forwards only the explicit capture override
  through the existing Linux child-environment helper, even with metrics off,
  so rollback reaches the process actually capturing the desktop.

The original fallback retains its exact full-frame cache comparison/copy.
Other capture backends and shared encoder traits are unchanged. No codec
preset, bitrate, protocol, dependency, submodule or lockfile changes are included.

## Verification commands and evidence

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh
# Use the isolated hardware Cargo/toolchain environment from the preceding note:
cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland \
 wayland::buffer_compare::tests
git diff --check
```

Initial build passed with two jobs; both focused tests passed. The exact isolated
environment is recorded in the preceding incident. Raw evidence stays private
under `/home/x/.cache/rustdesk-dev/reuse-{off,on}-*-stable.log` and
`reuse-{off,on}-source.log`; `reuse-build.log` and `reuse-tests.log` hold build
and test output. No screenshots, full environments, peer credentials or VM
service URLs are committed.
The original-path repeat uses `reuse-off2-*-stable.log` and
`reuse-off2-source.log` in the same private directory.

Final default-enabled hardware build also passed (two jobs). With the same
isolated environment, `cargo test --locked -p scrap --lib --features
hwcodec,linux-pkg-config,wayland wayland::` passed **25 tests**, two filtered out.
`git diff --check` passed. Final core SHA-256 on both hosts:
`8232449a288ae51f7bbfbfa220c891649ab18843dfb5fb9e643c94f38bd1ee05`.
The final server child had metrics enabled and **no reuse override**, confirming
the default path; a live 4K report showed 52 accepted buffers in 1015.93 ms and
0.216 ms comparison p95. This short check is not another stable-window benchmark.

### Multiscreen and GPU memory limit

AOC → internal → AOC produced updating frames at both 3840×2160 and 2560×1440,
but this is **not** a clean hardware-decoding acceptance pass. A switch failed
CUDA decoder initialization (`cuvidCreateDecoder`, `CUDA_ERROR_OUT_OF_MEMORY`),
followed by codec renegotiation and H.264 software fallback. Local `nvidia-smi`
then reported RTX 5060 Ti 8151 MiB total, 7585 MiB used and 121 MiB free. These
are dated observations; they do not establish a memory leak or its owner.

The same final binary was restarted with server reuse override **0**, verified
in the actual desktop child environment. Repeating the internal-screen switch
also produced `CUDA_ERROR_OUT_OF_MEMORY`, H.265 decoder creation failure and a
first-frame decode error, then updating 2560×1440 software H.264 frames. Thus the
condition reproduces with the original comparison path; it is not evidence of
an optimization-specific failure. Other GPU workloads were not stopped. Exact
allocation ownership and decoder-lifetime improvements remain separate work.
Private evidence: `reuse-final-client.log`, `reuse-final-server.log`, and
`reuse-fallback-client.log`. The single-screen A/B windows above precede these
switches and had zero decode errors; do not mix the acceptance scopes.

## Remaining work and rollback

Next isolate RGB-to-NV12 conversion and synchronous hardware encoder calls,
then compare low-latency H.265 parameters with text/detail quality checks.
Release throughput, actual presentation FPS, dual-screen 60 FPS, constrained
bandwidth quality and the earlier intermittent fullscreen-capture symptom
remain unverified by this change.

For code rollback, revert this scoped commit. For operational rollback, set
`RUSTDESK_PIPEWIRE_REUSE_BUFFER=0` on the server and restart only RustDesk.
Temporary verification overrides must be removed and the original OMEN service
restored after testing; restore only the three test quality/FPS preferences,
preserving peer credentials. Cached test artifacts can remain for reproduction.

Completed cleanup: all bounded playback fixtures exited; removed the `/run`
override, daemon-reloaded and restarted only RustDesk. Verified active original
`/usr/bin/rustdesk --service` and `/usr/share/rustdesk/rustdesk --server`.
Restored only image_quality, custom_image_quality and custom-fps from the private
backup. The native Wayland development client was relaunched without DISPLAY
or the metrics flag, reconnected to AOC (real peer 1.5.0/H.265, updating speed/FPS)
and emitted zero metrics events. Installed OMEN binaries remain unchanged;
the optimization was verified through the temporary bundle, not permanently
deployed. Keyboard, clipboard and text quality were not re-tested this turn.

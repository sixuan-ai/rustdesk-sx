# 2026-10-23 hwcodec and GStreamer binding upgrade

## Summary

Based on `bf24c167319c5971c3b251fb7e08459332031359`, on
`codex/stable-1.5.0-dev`. hwcodec and GStreamer bindings were upgraded in that
order, with independent full Release bundles retained for comparison.
Linux builds and 28 relevant tests pass; native Wayland/Tailscale 4K streaming
and hardware codecs work. **Performance acceptance remains open: neither a
stable throughput improvement nor 4K60 was established.** The complete upgrade
produced lower FPS than adjacent baseline trials, so it must not be advertised
as a performance improvement. Network/load/focus confound attribution.

## Environment

Observed 2026-10-23: local Ubuntu 26.04.1 / GNOME Wayland, Rust 1.99.1,
Flutter 3.47.7 / Dart 3.13.5, RTX 5060 Ti; OMEN RTX 4060 Laptop GPU,
GNOME Wayland, AOC HDMI-1. Both use system GStreamer 1.28.2. The Linux build
uses system FFmpeg 8. Other applications and GPU workloads were retained.
Builds use two jobs; none ran during the video trials.

## Dependency changes / investigation

- hwcodec 0.7.1 (`778df1f99597722473b29443bac22ae6c23946fe`) -> 0.8.0,
  pinned in the manifest to `ec38ebaf2454269d4c5668a57e3813c6e5541be7`.
  The exact 46-commit upstream range was inspected. Linux RAM decoder changes
  include resetting the software transfer frame on resolution changes, plus
  C++ exception boundaries. Windows VRAM changes also remove direct vendor SDK
  implementations; Windows behavior is outside this validation.
- gstreamer 0.16.7 -> 0.25.4; gstreamer-app 0.16.5 -> 0.25.2;
  gstreamer-video 0.16.7 -> 0.25.4. The obsolete app `v1_10` feature was removed;
  the new baseline already supports that API. No newer runtime API feature was
  enabled. The bindings require Rust >=1.92; default core runtime floor is 1.14.
- GStreamer's GLib family becomes 0.22, while GTK remains 0.18. These coexist
  without migrating GTK or exchanging Rust wrapper objects between versions.
  Necessary transitive changes include shared bitflags, indexmap, memchr and
  pkg-config versions; other consumers also use these updated libraries. Unrelated Windows-only
  resolution changes from Cargo were restored.

All three existing hwcodec patches apply unchanged through prepare_hwcodec.py:
system-FFmpeg linkage, FFmpeg8 API compatibility, and opt-in NVENC low latency.
The latter remains disabled by default. No SDK or shared Cargo checkout was
modified; the existing isolated hwcodec Cargo overlay remains in use.

## Fix / regression surface

- libs/scrap/Cargo.toml and Cargo.lock select the new dependencies. hwcodec
  affects consumers enabling that optional feature; GStreamer is Linux/Wayland
  only. Other platforms were not built or tested.
- libs/scrap/src/wayland/pipewire.rs adapts element builders, caps, buffer/crop
  access, property setters, state waits and optional PTS to the new APIs.
- libs/scrap/src/wayland/capture_metrics.rs adapts source-pad and optional PTS
  access, preserving nanoseconds and existing counters.
- res/dev/run_linux.sh adds optional RUSTDESK_DEV_BUNDLE_DIR so snapshots use the
  same Wayland/GTK/IBus/Skia launcher. Unset retains the existing path.

The PipeWire -> videoconvert -> appsink pipeline, ordered BGRx/RGBx formats,
always-copy, max-buffers1/drop, state waits, retained read mapping, crop handling,
duplicate detection, encoder settings, queue bounds and protocol are preserved.
Parallel NV12, low-latency NVENC and unpaced appsink stay opt-in and were unset
throughout comparisons. No shared traits/signatures or submodules changed.

## Verification

Run from the repository, with the existing system build dependencies installed:

```bash
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
```

Both complete matching Rust+Flutter bundles built successfully. Release was
also built at the intermediate hwcodec-only stage. Generated-only analyzer
exclusions were removed; no generated bridge or Flutter dependency change
remains. Shell syntax and git diff --check pass.

For the following test commands, use the same system environment as
build_linux.sh: CARGO_HOME from prepare_hwcodec.py, RUSTDESK_HWCODEC_SYSTEM=1,
the local pkgconfig directory, CXXFLAGS including -include cstdint,
CMAKE_POLICY_VERSION_MINIMUM=3.5, CARGO_PROFILE_DEV_DEBUG=0, and two build jobs.

```bash
cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland wayland::
cargo test --locked -p scrap --lib --features hwcodec,linux-pkg-config,wayland parallel_nv12::tests
cargo test --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste,hwcodec client::linux_video_resources::tests
```

Results: 25/25, 1/1 and 2/2 pass. Coverage includes retained 4K mapped-buffer
ownership, last-pixel changes, PTS accounting, display remapping, NV12 padded
chroma equivalence and rejection of late frames after selection changes.

## OMEN trials

The user was notified before each batch. The complete baseline, hwcodec-only
and final bundles were staged separately under /opt/rustdesk-dep-{baseline,
hwcodec,gstreamer}; installed binaries were preserved. A temporary /run service
override selected each bundle. Local process maps confirmed matching core/AOT
and absence of DISPLAY; the later batch also checked the actual OMEN desktop
--server executable/core and metrics flag, rather than only the root unit.

Each trial used a fresh connection, Skia in both Flutter projects, custom
quality33 / requested60 FPS, the existing playback_motion_probe.py for55s on
HDMI-1, and summarize_display_metrics.py with aware timestamp bounds T+15..50s.
The source reported NVDEC, pause=false, advancing time positions across loops
and nominal60 FPS. Viewports were3740x2105 or3740x2112 within a3840x2160 desktop;
they were not fullscreen direct-scanout measurements. All windows reported
hardware_encoder=true and client ffmpeg/hevc/AV_HWDEVICE_TYPE_CUDA. All seven
trials had zero client decode errors, overflow and discarded frames, and zero
server shared-queue peak.

| Sequence | Both endpoints | Source /s | Accepted /s | Submitted /s | Convert ms | Encode ms | ACK ms | Write ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Batch1 A | Baseline |57.99|25.84|25.28|7.71|15.91|45.77|51.51|
| Batch1 B | hwcodec only |57.65|26.80|26.66|7.48|15.89|56.58|63.40|
| Batch2 A | Baseline |58.14|43.89|43.48|7.13|15.86|11.72|20.44|
| Batch2 B | Complete upgrade |57.50|31.80|31.55|7.02|15.89|81.51|103.29|
| Batch2 A | Baseline |57.13|44.37|44.93|7.25|16.10|0.29|0.10|
| Batch2 C | hwcodec only |57.93|42.08|41.70|7.97|15.88|38.39|50.70|
| Batch2 B | Complete upgrade |58.66|38.48|38.50|7.73|16.10|67.61|73.38|

FPS is weighted telemetry throughput, not physical presentation FPS. Timings
are means of per-window p95 values; they are not additive end-to-end latency.
Baseline itself varied25..45 FPS. Complete-upgrade trials were lower than the
adjacent baseline; this is an unresolved performance finding, not proof of a
GStreamer regression or a passed performance acceptance. Encode timing stayed
near16ms and conversion near7..8ms across versions, whereas write/ACK waits
varied substantially. A late TCP snapshot on the final session showed
rtt44.8ms, cwnd10, cumulative140 retransmitted segments /170326 bytes; it was
not sampled across every interval and cannot establish packet-loss causality.
A Tailscale ping earlier confirmed direct transport at39ms; a later probe timed
out. Final focus logs were not uniformly active across cases, another limit.

Private evidence, full logs and snapshots (not committed):
~/.cache/rustdesk-dev/dependency-upgrade/{first-batch,baseline-before,final,
baseline-after,hwcodec-repeat,final-repeat}. No credentials were copied into
the repository or benchmark summaries.

Release core SHA256s:

- baseline: b9e3a015b99993024b1455c5a4269707ad264a81473b86e4bbe7b224d32ed57f
- hwcodec-only: 74f0fe7d23ac767113e0b099da87203810c60e3c9200339f9108949aa0e41672
- final: 6303f3563462bbfe391332c768701cfded0d8fcfdde576aec924c827ff4b6de7

## Remaining risk / rollback

Next performance work should isolate endpoint changes and repeat under a
stable network, controlled foreground/GPU load, and identical viewport. Log
bitrate and TCP behavior alongside frame ACKs before attributing the lower
complete-upgrade FPS to the bindings. Do not enable larger queues or experimental
codec flags to conceal the gap. Ubuntu24 and non-Linux platforms are unverified;
the default binding runtime floor alone does not constitute Ubuntu24 testing.

The original OMEN /usr/bin/rustdesk service was restored, the /run override
removed, and the original balanced/quality50/30FPS preferences restored by
editing only those three keys. The upgraded local Debug client was relaunched
without DISPLAY or metrics and received a remote texture event. No system
display, GPU, network or unrelated service configuration changed. Source rollback
is git revert of this upgrade commit followed by rebuilding; the preserved
baseline bundle can be selected with RUSTDESK_DEV_BUNDLE_DIR for diagnostics.

## Follow-up: endpoint / network isolation

The [subsequent controlled endpoint matrix](2026-10-23-gstreamer-endpoint-network-isolation.md)
held hwcodec0.8 fixed and swapped capture bindings at the client/server
independently, with verified foreground state. Independent TCP tests reproduced
network variation/retransmissions, and the complete upgrade was no longer the
slower case. A consistent GStreamer capture regression was not reproduced;
network is not proven to explain every timing difference. The upgrade stays
on the development branch; 4K60 and a stable performance improvement remain open.

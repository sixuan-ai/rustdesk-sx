# 2026-10-23 GStreamer endpoint and network isolation

## Summary

On `codex/stable-1.5.0-dev`, based on `25f58c553`, cross-tested new and old
GStreamer bindings independently at each endpoint. **Network impairment and
variation were reproduced independently of RustDesk; a consistent GStreamer
capture regression was not reproduced.** Keep the upgrade, without claiming
a throughput improvement or 4K60. This result narrows attribution; it does not
prove that every timing difference is caused by the network.

The earlier observation of lower complete-upgrade FPS remains a valid historical
measurement, but is not sufficient evidence to roll back the bindings.

## Environment / controls

Observed 2026-10-23, local Ubuntu26.04.1/GNOME Wayland, RTX5060Ti; OMEN GNOME
Wayland/RTX4060, AOC HDMI-1. Rust1.99.1, Flutter3.47.7, system FFmpeg8 and
GStreamer1.28.2. Existing full Release snapshots were reused, without rebuilding
or changing production code during this task.

- **H:** hwcodec0.8.0 + GStreamer0.16 bindings, the previous intermediate build.
- **G:** hwcodec0.8.0 + GStreamer0.25 bindings, the current complete upgrade.
- Thus hwcodec is held fixed; “old” in the matrix means old bindings, not the
  original hwcodec0.7.1 build. Necessary transitive binding dependencies differ
  as documented in the preceding upgrade record.
- Both snapshots have byte-identical runner, Flutter engine and libapp.so AOT.
  The Rust cores match the hashes recorded in
  [the upgrade incident](2026-10-23-hwcodec-gstreamer-upgrade.md).
- Each connection used a fresh local client and OMEN service/desktop process.
  Process maps checked the selected core/AOT, local DISPLAY absence, and the
  actual OMEN desktop child executable/core and metrics flag.
- Both Flutter projects reported Skia. Custom quality33 / requested60 FPS,
  original encoder/pacing/ABR policy, mapped-buffer reuse, queue sizes and
  disabled experimental NV12/NVENC/unpaced flags were held fixed. Requested
  quality is not proof of an identical instantaneous adaptive encoder bitrate.
- User paused other controls. AT-SPI sampled the OMEN remote window at1Hz;
  all five accepted intervals had35/35 known/active samples. Source viewport
  was exactly3740x2112 in all accepted cases, desktop3840x2160. Other GPU
  applications remained running; their instantaneous workloads were not pinned.

## Investigation / reproduction

The existing bundles remain in the private dependency-upgrade cache and the
independent OMEN /opt/rustdesk-dep-hwcodec and /opt/rustdesk-dep-gstreamer
directories. Installed binaries were preserved. Use the temporary /run override
described in the preceding incident to select the **server** bundle; select the
**client** independently with RUSTDESK_DEV_BUNDLE_DIR, for example:

```bash
RUSTDESK_DEV_BUILD_MODE=release \
RUSTDESK_DEV_BUNDLE_DIR="$HOME/.cache/rustdesk-dev/dependency-upgrade/gstreamer/bundle" \
RUSTDESK_DISPLAY_METRICS=1 RUST_LOG=info res/dev/run_linux.sh
```

After initializing the main window, invoke the same launcher/environment with
`--connect <OMEN_TAILSCALE_IP>`. Do not put a password in the command. Temporarily set
only the three quality/FPS keys while the client is stopped; restore them after
testing, preserving all authentication fields. Do not embed the literal unit
ExecStop match in a long-lived SSH shell's arguments; write overrides via stdin.

After fresh 4K frames and confirmed foreground state, start synchronized TCP
sampling on OMEN and the existing bounded playback source:

```bash
# Run from the local repository; replace PRIVATE with an existing private directory.
ssh -oBatchMode=yes omen python3 - --seconds 65 \
  < res/dev/sample_stream_tcp.py > PRIVATE/tcp.jsonl &
tcp_probe=$!
# Record aware UTC time T immediately before launching the source.
ssh -oBatchMode=yes omen \
  'env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-0 GDK_BACKEND=wayland python3 /home/x/.cache/rustdesk-wayland-verification/playback_motion_probe.py --video /home/x/.cache/rustdesk-wayland-verification/motion-4k60.mkv --output HDMI-1 --mode maximized --seconds 55' \
  > PRIVATE/source.jsonl
wait "$tcp_probe"
```

Use summarize_display_metrics.py with aware --since T+15 / --until T+50 bounds
for both endpoints. Release logs come from ~/.local/share/logs/RustDesk, not
Debug stderr. Only export whitelisted telemetry markers. Check source NVDEC,
advancing time position, pause=false, display-names and viewport before accepting
a case. Counters reset when the short video loops; player drop counters are not
aggregate physical presentation measurements.

For foreground verification, query Atspi.get_desktop(0), select only the
RustDesk application's window whose title begins with the intended peer, and
record get_state_set().contains(Atspi.StateType.ACTIVE) every second with aware
UTC timestamps. Reject windows with unknown/inactive samples in the measured
interval. Component.grab_focus returned false in a local probe; activation was not
assumed from that call. The user was asked to return to the remote window. This test injected no keys.

The new sample_stream_tcp.py runs read-only `ss -tinH state established` filtered
to source port21118, once per second. It exports hashed socket identity and
numeric counters, without endpoint names or configuration. Reject ambiguous
multiple sockets or a connection change within an interval. For the first/last
TCP samples inside the same bounds:

```text
TCP goodput Mbps = 8 * delta(bytes_acked) / delta(sample time) / 1,000,000
Retransmitted segments = delta(total_retrans)
```

This is TCP application goodput, including protocol traffic, not the configured
encoder bitrate or raw link capacity. `retrans:0/140` means0 currently in flight
and140 cumulative retransmissions; parse the second number. `rtt:44.8/4.4`
contains RTT and its variation, not two RTT samples. Missing counters remain
unknown. Socket hashing prevents accidental cross-connection deltas.

## Results

Accepted intervals use identical report-time bounds, foreground checks and
viewport. Timings are means of per-window p95 values, not additive latency.
TCP counter deltas span about34s within the35s bounds.

| Case | Client | Server | Source/s | Submitted FPS | TCP Mbps | Retrans segments | Write ms | Frame ACK ms |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| HH2 | H | H |56.73|37.18|3.574|78|82.19|71.25|
| GH1 | G | H |58.45|31.40|2.399|98|115.31|102.87|
| GG1 | G | G |58.59|43.21|3.347|69|54.68|57.64|
| HG2 | H | G |55.98|34.20|2.464|76|26.40|46.83|
| HH3 | H | H |58.21|37.38|3.845|64|76.03|62.32|

Every accepted interval used H265/CUDA decoding and a hardware encoder, with
zero decode errors, discarded/overflow frames and server shared-queue peak.
Conversion p95 means were6.56..7.74ms; encode15.73..15.95ms. Source player
drop-counter maxima in the stable sampled intervals were0. Source production
did not show a consistent deficit with G.

TCP RTT medians were44.0..45.3ms; median congestion windows12..18 segments.
Receiver windows were recorded as well; these are observability samples, not
a packet capture or a controlled loss-injection test. A low GH1 rate occurred
with the **old server capture bindings**, whereas the complete upgrade GG1 was
the fastest accepted case. This contradicts a repeatable “new capture bindings
always cause the lower FPS” explanation. It does not isolate all transitive
client-library effects or estimate a small binding-version effect statistically.

Two separate8-second iperf3 reverse TCP runs requested50Mbps, with RustDesk
video stopped. A temporary single-use listener was bound to the Tailscale address
on port52401. Commands: `timeout 25 iperf3 -s -1 -B <OMEN_TAILSCALE_IP> -p 52401 -J`
on OMEN and `iperf3 -c <OMEN_TAILSCALE_IP> -p 52401 -R -t 8 -b 50M -J` locally.
Before/after received goodput was **3.670 / 6.422Mbps**, with **26 / 55** sender
retransmissions. Sender-side JSON independently confirmed these retransmission
counts. These bounded single-flow results demonstrate a changing transport
condition without GStreamer; they do not measure the maximum physical link rate.

Excluded HH1 had25/35 active focus samples and38.71FPS; excluded HG1 had20/35
and38.30FPS. Both remain in private evidence, rather than being silently removed.
HG2 is the foreground-valid repeat of HG1.

## Findings / remaining risk

Confirmed: network variation/retransmissions exist outside RustDesk and can
produce long write/ACK waits with old bindings too. Foreground state was also
a confound in earlier measurements. No consistent source-capture regression
was reproduced; rolling back GStreamer is not justified by these data alone.

Network is **not proven to be the sole cause**. HG2 had lower QoS mean41.03FPS
and client submission p95 mean24.23ms, compared with HH2/HH3 submission around
11.5ms; its lower write wait does not explain every remaining difference.
GPU/Flutter scheduling, adaptive quality and TCP recovery histories remain
coupled. The trial order was sequential, not a randomized statistical study.
4K60 and a stable dependency-upgrade speed benefit remain unverified.

Next: investigate the Tailscale/physical egress path with bounded repeated TCP
tests, distinguish direct/relay transitions and retransmission/congestion from
receiver pressure, then repeat the matrix on a stable path while pinning GPU
load and logging actual encoder bitrate. Do not change global qdiscs, disable
congestion control, enlarge queues or lower quality to mask the finding.

## Changes, checks and cleanup

Only new development TCP diagnostics/tests and incident documentation changed;
no application runtime, dependency, codec, network or display policy changed.
`python3 -m unittest discover -s res/dev -p test_sample_stream_tcp.py` passed2
tests. A live1-second SSH probe produced valid counters; all five accepted
cases passed executable/core/AOT, foreground, hardware/dimension and error
checks. `git diff --check` passed. No Rust rebuild was needed for these changes.

OMEN original rustdesk.service is active with its installed binary; the /run
override was removed. The exact three original preferences were restored and
compared with their private backup. All bounded source/iperf processes exited.
The normal upgraded Debug client was relaunched without DISPLAY/metrics and
received a remote texture event. Other applications/services were preserved.
No remote push or permanent deployment was performed.

Private raw evidence and orchestration are under
~/.cache/rustdesk-dev/network-isolation, including per-case summaries, TCP/focus
JSONL and iperf JSON. They were not committed; the reproduction protocol and
read-only TCP sampler are checked in. There is no persistent runtime change to
roll back; reverting this task's commit removes only diagnostics/documentation.

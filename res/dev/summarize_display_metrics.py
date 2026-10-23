#!/usr/bin/env python3
"""Summarize only sanitized display telemetry from a RustDesk log (no VM URLs)."""
import argparse
from collections import defaultdict
import json
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('log')
parser.add_argument('--skip-windows', type=int, default=0)
args = parser.parse_args()
windows = defaultdict(list)
with open(args.log, errors='replace') as stream:
    for line in stream:
        for marker in ('pipewire_capture_metrics ', 'pipewire_source_metrics ', 'server_display_metrics ', 'server_video_queue_metrics ', 'display_metrics '):
            if marker in line:
                try:
                    sample = json.loads(line.split(marker, 1)[1])
                    windows[(marker.strip(), sample.get('display', sample.get('node')))].append(sample)
                except (ValueError, KeyError):
                    pass
                break
for (stage, display), samples in sorted(windows.items()):
    samples = samples[args.skip_windows:]
    if not samples: continue
    result = {'stage': stage, ('node' if stage.startswith('pipewire_') else 'display'): display, 'windows': len(samples)}
    for key in ('buffers', 'samples_pulled', 'accepted_buffers', 'duplicate_pixels', 'pull_timeouts'):
        if key in samples[0]:
            result[key + '_per_s'] = round(sum(s[key] for s in samples) * 1000 / sum(s['window_ms'] for s in samples), 2)
    result['dimensions'] = sorted({f"{s['width']}x{s['height']}" for s in samples if 'width' in s})
    result['decoders'] = sorted({s['decoder'] for s in samples if 'decoder' in s})
    for key in ('received_fps', 'submitted_fps', 'pending_peak', 'overflow', 'discarded', 'decode_errors', 'shared_queue_peak', 'queue_wait_p95_ms', 'stream_write_p95_ms', 'target_fps'):
        values = [s[key] for s in samples if key in s]
        if values:
            mean = statistics.mean(values)
            if key in ('received_fps', 'submitted_fps'):
                mean = sum(s[key] * s['window_ms'] for s in samples) / sum(s['window_ms'] for s in samples)
            result[key] = {'mean': round(mean, 2), 'max': max(values)}
    for key in ('queue_wait_ms', 'decode_convert_ms', 'flutter_submit_ms', 'capture_call_ms', 'pixel_convert_ms', 'encode_ms', 'enqueue_ms', 'pull_wait_ms', 'map_ms', 'compare_copy_ms', 'crop_copy_ms', 'arrival_interval_ms', 'pts_interval_ms', 'frame_ack_wait_ms', 'pacing_sleep_ms'):
        values = [s[key]['p95'] for s in samples if s.get(key, {}).get('samples', 0)]
        if values:
            # Do not mislabel a percentile of window percentiles as a frame percentile.
            result[key] = {'mean_window_p95': round(statistics.mean(values), 2), 'max_window_p95': round(max(values), 2)}
    print(json.dumps(result, ensure_ascii=False))

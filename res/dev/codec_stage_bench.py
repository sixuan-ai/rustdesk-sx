#!/usr/bin/env python3
"""Bounded FFmpeg codec throughput probe, without desktop capture or network.

Generated NV12 input lives in tmpfs; initialization is included in wall time.
These are throughput measurements, not per-frame or display latency.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--frames', type=int, default=180)
p.add_argument('--sizes', nargs='+', default=['1920x1080', '2560x1440', '3840x2160'])
p.add_argument('--presets', nargs='+', choices=['p1', 'p4'], default=['p4', 'p1'])
args = p.parse_args()
if not 60 <= args.frames <= 600:
    p.error('--frames must be 60..600')
for size in args.sizes:
    if size not in ('1920x1080', '2560x1440', '3840x2160'):
        p.error('Unsupported size')

def run(argv):
    started = time.monotonic()
    result = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostats',
        '-threads', '2', '-filter_threads', '2', *argv], capture_output=True, text=True, timeout=90)
    elapsed = time.monotonic() - started
    if result.returncode:
        raise RuntimeError(result.stderr[-1500:])
    progress = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    count = int(progress.get('frame', '0'))
    if count != args.frames:
        raise RuntimeError(f'Expected {args.frames} output frames, got {count}')
    return {'frames': count, 'elapsed_s': round(elapsed, 3), 'wall_fps': round(count / elapsed, 2)}

for size in args.sizes:
    with tempfile.TemporaryDirectory(prefix='rustdesk-codec-stage-', dir='/dev/shm') as temp:
        source, encoded = Path(temp)/'source.nv12', Path(temp)/'encoded.hevc'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-threads', '2',
            '-filter_threads', '2', '-f', 'lavfi', '-i', f'testsrc2=size={size}:rate=60',
            '-frames:v', '8', '-pix_fmt', 'nv12', '-c:v', 'rawvideo', '-f', 'rawvideo', str(source)],
            check=True, timeout=30, stdout=subprocess.DEVNULL)
        for preset in args.presets:
            result = run(['-y', '-stream_loop', '-1', '-f', 'rawvideo', '-pix_fmt', 'nv12',
                '-s:v', size, '-r', '60', '-i', str(source), '-frames:v', str(args.frames),
                '-an', '-c:v', 'hevc_nvenc', '-preset', preset, '-delay', '0', '-bf', '0',
                '-rc', 'cbr', '-b:v', '12M', '-progress', 'pipe:1', str(encoded)])
            print(json.dumps({'stage': 'encode_ram', 'codec': 'hevc_nvenc', 'size': size,
                'preset': preset, 'target_kbps': 12000, **result}), flush=True)
            result = run(['-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda', '-i', str(encoded),
                '-frames:v', str(args.frames), '-vf', 'hwdownload,format=nv12', '-an',
                '-progress', 'pipe:1', '-f', 'null', '-'])
            print(json.dumps({'stage': 'decode_download', 'codec': 'hevc/CUDA', 'size': size,
                'source_preset': preset, **result}), flush=True)

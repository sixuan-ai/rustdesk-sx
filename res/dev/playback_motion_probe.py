#!/usr/bin/env python3
"""Bounded native Wayland/Vulkan playback with verified output and drop counters."""
import argparse
import json
from pathlib import Path
import signal
import socket
import subprocess
import tempfile
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--video', type=Path, required=True)
p.add_argument('--output', required=True, help='Live Wayland output name, e.g. HDMI-1')
p.add_argument('--seconds', type=int, default=90)
p.add_argument('--mode', choices=['fullscreen','maximized'], default='fullscreen')
args = p.parse_args()
if not args.video.is_file() or not 5 <= args.seconds <= 180:
    p.error('Existing video and duration 5..180 required')
def stop(_signal, _frame): raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
with tempfile.TemporaryDirectory(prefix='rd-motion-') as temp:
    ipc = str(Path(temp)/'ipc')
    process = subprocess.Popen(['mpv', '--no-config', '--vo=gpu-next', '--gpu-api=vulkan',
        '--gpu-context=waylandvk', '--hwdec=nvdec', '--no-audio', '--loop-file=inf',
        '--terminal=no', '--input-default-bindings=no', '--input-vo-keyboard=no',
        '--input-terminal=no', '--osc=no', '--force-window=yes', '--input-ipc-server='+ipc, str(args.video)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sock = socket.socket(socket.AF_UNIX); sock.settimeout(5)
    stream = None
    sequence = 0
    def command(*parts):
        global sequence
        sequence += 1
        stream.write(json.dumps({'command':parts,'request_id':sequence}).encode()+b'\n')
        while True:
            message = json.loads(stream.readline())
            if message.get('request_id') == sequence:
                if message.get('error') != 'success':
                    raise RuntimeError(f'mpv command {parts[0]} failed: {message.get("error")}')
                return message.get('data')
    try:
        for _ in range(100):
            if process.poll() is not None: raise RuntimeError('mpv exited before IPC became available')
            if Path(ipc).exists(): break
            time.sleep(.1)
        sock.connect(ipc); stream = sock.makefile('rwb', buffering=0)
        time.sleep(1)
        command('set_property','fs-screen-name',args.output)
        for _ in range(5):
            command('set_property','fullscreen',False)
            command('set_property','fullscreen',True)
            time.sleep(.5)
            if args.output in (command('get_property','display-names') or []): break
        else: raise RuntimeError('Compositor did not place test window on requested output')
        if args.mode == 'maximized':
            command('set_property','fullscreen',False)
            # Wayland applies fullscreen exit asynchronously. A maximize request
            # sent before that configure can leave a smaller restored window.
            time.sleep(.5)
            command('set_property','window-maximized',True)
            time.sleep(1)
            if args.output not in (command('get_property','display-names') or []):
                raise RuntimeError('Maximized test window moved to another output')
        started = time.monotonic()
        while time.monotonic()-started < args.seconds:
            sample={'elapsed_s':time.monotonic()-started}
            for key in ('display-names','osd-dimensions','hwdec-current','estimated-vf-fps',
                'frame-drop-count','decoder-frame-drop-count','vo-delayed-frame-count','pause','time-pos'):
                sample[key]=command('get_property',key)
            if sample['pause']: raise RuntimeError('Playback was paused; source is invalid')
            print(json.dumps(sample),flush=True)
            time.sleep(1)
    finally:
        if stream: stream.close()
        sock.close()
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()

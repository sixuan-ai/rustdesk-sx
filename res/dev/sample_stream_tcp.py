#!/usr/bin/env python3
"""Read bounded TCP counters for a RustDesk server, without changing the link.

Output contains socket hashes and numeric counters only. Throughput derived from
bytes_acked includes protocol traffic; it is not the encoder's configured bitrate.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess
import time


def parse_ss(text):
    rows = []
    for line in text.splitlines():
        if not line.startswith((' ', '\t')):
            fields = line.split()
            if len(fields) < 4:
                continue
            rows.append({'socket_id': hashlib.sha256(
                ' '.join(fields[-2:]).encode()).hexdigest()[:16]})
        elif rows:
            row = rows[-1]
            for name in ('bytes_sent', 'bytes_acked', 'bytes_received',
                         'bytes_retrans', 'data_segs_out', 'data_segs_in',
                         'cwnd', 'mss', 'snd_wnd', 'unacked', 'lost'):
                match = re.search(r'\b' + name + r':(\d+)\b', line)
                if match:
                    row[name] = int(match[1])
            match = re.search(r'\brtt:([\d.]+)/([\d.]+)', line)
            if match:
                row['rtt_ms'], row['rtt_variation_ms'] = map(float, match.groups())
            match = re.search(r'\bretrans:(\d+)/(\d+)\b', line)
            if match:
                row['retrans_out'], row['total_retrans'] = map(int, match.groups())
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=int, default=65)
    parser.add_argument('--port', type=int, default=21118)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 180 or not 1 <= args.port <= 65535:
        parser.error('duration must be 1..180 seconds and port 1..65535')
    started = time.monotonic()
    while time.monotonic() - started < args.seconds:
        result = subprocess.run(
            ['ss', '-tinH', 'state', 'established', f'( sport = :{args.port} )'],
            capture_output=True, text=True, check=True, timeout=5)
        print(json.dumps({'at': datetime.now(timezone.utc).isoformat(),
                          'elapsed_s': time.monotonic() - started,
                          'sockets': parse_ss(result.stdout)}), flush=True)
        time.sleep(1)


if __name__ == '__main__':
    main()

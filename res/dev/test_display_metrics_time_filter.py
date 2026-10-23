#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class TimeFilterTest(unittest.TestCase):
    def test_selects_same_utc_window_from_debug_and_release_logs(self):
        payload = 'server_video_queue_metrics {"display":0,"shared_queue_peak":0}'
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'metrics.log'
            log.write_text('\n'.join([
                '[2026-10-23T10:00:10Z INFO] ' + payload,
                '[2026-10-23 18:00:20.000000 +08:00] INFO ' + payload,
                '[2026-10-23T10:00:30Z INFO] ' + payload,
                payload,
            ]))
            result = subprocess.run([
                sys.executable, str(Path(__file__).with_name('summarize_display_metrics.py')),
                str(log), '--since', '2026-10-23T10:00:10Z',
                '--until', '2026-10-23T10:00:20Z',
            ], capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(result.stdout)['windows'], 2)


if __name__ == '__main__':
    unittest.main()

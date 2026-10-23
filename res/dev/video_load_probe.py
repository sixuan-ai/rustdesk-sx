#!/usr/bin/env python3
"""Temporary native GTK/GStreamer GPU workload with measured source FPS."""
import argparse
import json
import sys
import time
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('Gst', '1.0')
from gi.repository import Gdk, GLib, Gst, Gtk

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--monitor', type=int, required=True, help='live GDK monitor index')
p.add_argument('--seconds', type=int, default=90)
p.add_argument('--fps', type=int, choices=(30, 60), default=60)
p.add_argument('--width', type=int, default=3840)
p.add_argument('--height', type=int, default=2160)
p.add_argument('--unpaced-sink', action='store_true', help='Disable sink clock waiting for source throughput isolation')
args = p.parse_args()
display = Gdk.Display.get_default()
if not display or not 0 <= args.monitor < display.get_n_monitors():
    raise SystemExit('Requested monitor is not available')
Gst.init(None)
sink = Gst.ElementFactory.make('gtkglsink', 'screen')
if sink is None:
    raise SystemExit('GStreamer gtkglsink is required')
pipeline = Gst.parse_launch(
    f'gltestsrc is-live=true pattern=smpte ! '
    f'video/x-raw(memory:GLMemory),width={args.width},height={args.height},framerate={args.fps}/1 ! '
    'gltransformation name=motion ! fpsdisplaysink name=metrics '
    'text-overlay=false signal-fps-measurements=true fps-update-interval=1000')
metrics = pipeline.get_by_name('metrics')
metrics.set_property('video-sink', sink)
if args.unpaced_sink:
    metrics.set_property('sync', False)
    sink.set_property('sync', False)
    sink.set_property('qos', False)
    sink.set_property('max-lateness', -1)
paint_frames = 0
metrics.connect('fps-measurements', lambda _s, fps, drop, avg:
    print(json.dumps({'elapsed_s': time.monotonic() - started, 'source_sink_fps': fps, 'drop_rate': drop, 'average_fps': avg, 'gtk_paint_frames': paint_frames}), flush=True))
window = Gtk.Window(title='RustDesk GPU 4K motion verification')
window.add(sink.get_property('widget'))
window.fullscreen_on_monitor(window.get_screen(), args.monitor)
window.connect('destroy', Gtk.main_quit)
window.show_all()
started = time.monotonic()
failed = False

def painted(_clock):
    global paint_frames
    paint_frames += 1

def observe_frame_clock():
    clock = window.get_frame_clock()
    if clock is None:
        return True
    clock.connect('after-paint', painted)
    return False

GLib.timeout_add(100, observe_frame_clock)

def animate():
    pipeline.get_by_name('motion').set_property('rotation-z', (time.monotonic() - started) * 12 % 360)
    return True

bus = pipeline.get_bus()
bus.add_signal_watch()
def on_message(_bus, msg):
    global failed
    if msg.type == Gst.MessageType.ERROR:
        failed = True
        error, _debug = msg.parse_error()
        print('pipeline_error:', error.message, flush=True)
        window.destroy()
bus.connect('message', on_message)
GLib.timeout_add(16, animate)
GLib.timeout_add_seconds(args.seconds, lambda: (window.destroy(), False)[1])
pipeline.set_state(Gst.State.PLAYING)
try:
    Gtk.main()
finally:
    pipeline.set_state(Gst.State.NULL)
print(f'probe_elapsed_s={time.monotonic() - started:.2f}', flush=True)

if failed:
    sys.exit(1)

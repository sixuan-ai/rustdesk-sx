#!/usr/bin/env python3
"""Manual GNOME single-monitor verification using native absolute uinput events.

AT-SPI identifies/focuses the client; GDK's XWayland workarea is read only to
locate a maximized window on this test host. No XTest events reach the client.
Requires python3-evdev, python3-gi, ydotool, and access to /dev/uinput.
"""
import argparse
import os
import subprocess
import time

import evdev
import gi

gi.require_version('Atspi', '2.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Atspi, Gdk
from evdev import AbsInfo, ecodes as e

parser = argparse.ArgumentParser()
parser.add_argument('--pid', type=int, required=True)
parser.add_argument('--title', required=True)
parser.add_argument('--x', type=float, required=True, help='window-local logical x')
parser.add_argument('--y', type=float, required=True, help='window-local logical y')
parser.add_argument('--click', action='store_true')
args = parser.parse_args()
env = os.environ.copy()
env.setdefault('YDOTOOL_SOCKET', f'/run/user/{os.getuid()}/.ydotool_socket')


def target():
    root = Atspi.get_desktop(0)
    for i in range(root.get_child_count()):
        app = root.get_child_at_index(i)
        if app.get_process_id() != args.pid:
            continue
        for j in range(app.get_child_count()):
            w = app.get_child_at_index(j)
            w.clear_cache()
            if w.get_name() == args.title:
                return w
    raise SystemExit('Requested client window is absent')


def keys(*codes):
    subprocess.run(['ydotool', 'key', *codes], env=env, check=True,
                   stdout=subprocess.DEVNULL)


def active():
    return target().get_state_set().contains(Atspi.StateType.ACTIVE)


for _ in range(12):
    if active():
        break
    keys('56:1', '1:1', '1:0', '56:0')
    time.sleep(.3)
else:
    raise SystemExit('Requested client did not become active; no pointer input sent')
display = Gdk.Display.get_default()
if display.get_n_monitors() != 1:
    raise SystemExit('This verification helper requires a single local monitor')
monitor = display.get_monitor(0)
area, screen = monitor.get_workarea(), monitor.get_geometry()
rect = target().get_component_iface().get_extents(Atspi.CoordType.SCREEN)
if (rect.width, rect.height) != (area.width, area.height):
    raise SystemExit('Maximize the client using its title bar before verification')
if not (0 <= args.x < area.width and 0 <= args.y < area.height):
    raise SystemExit('Point is outside the client')
x = round((area.x - screen.x + args.x) / screen.width * 65535)
y = round((area.y - screen.y + args.y) / screen.height * 65535)
caps = {e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
        e.EV_ABS: [(e.ABS_X, AbsInfo(0, 0, 65535, 0, 0, 0)),
                   (e.ABS_Y, AbsInfo(0, 0, 65535, 0, 0, 0))]}
with evdev.UInput(caps, name='RustDesk Wayland verification pointer',
                  vendor=0x0627, product=1, bustype=e.BUS_USB,
                  input_props=[e.INPUT_PROP_POINTER]) as ui:
    time.sleep(1)
    if not active():
        raise SystemExit('Focus changed; no pointer events sent')
    ui.write(e.EV_ABS, e.ABS_X, x)
    ui.write(e.EV_ABS, e.ABS_Y, y)
    ui.syn()
    time.sleep(.3)
    if args.click:
        if not active():
            raise SystemExit('Focus changed; no click sent')
        ui.write(e.EV_KEY, e.BTN_LEFT, 1)
        ui.syn()
        ui.write(e.EV_KEY, e.BTN_LEFT, 0)
        ui.syn()
        time.sleep(.2)
print('Native absolute pointer event sent' + (' with left click' if args.click else ''))

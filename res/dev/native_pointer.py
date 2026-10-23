#!/usr/bin/env python3
"""Move/click inside a known X11 dev window using native Wayland input."""
import argparse
import os
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--window", required=True)
parser.add_argument("--x", type=int, required=True)
parser.add_argument("--y", type=int, required=True)
parser.add_argument("--click", action="store_true")
args = parser.parse_args()
environment = os.environ.copy()
environment.setdefault("YDOTOOL_SOCKET", f"/run/user/{os.getuid()}/.ydotool_socket")


def query(*command):
    return dict(
        line.split("=", 1)
        for line in subprocess.check_output(command, text=True).splitlines()
    )


subprocess.run(["wmctrl", "-ia", args.window], check=True)
time.sleep(0.5)
geometry = query("xdotool", "getwindowgeometry", "--shell", args.window)
if not (0 <= args.x < int(geometry["WIDTH"]) and 0 <= args.y < int(geometry["HEIGHT"])):
    raise SystemExit("Requested point is outside the target window")
target_x, target_y = int(geometry["X"]) + args.x, int(geometry["Y"]) + args.y
# Absolute uinput movement accelerates on this GNOME setup. Small relative
# steps with pointer feedback avoid changing the user's acceleration settings.
for _ in range(180):
    position = query("xdotool", "getmouselocation", "--shell")
    dx, dy = target_x - int(position["X"]), target_y - int(position["Y"])
    if abs(dx) < 4 and abs(dy) < 4:
        break
    step = lambda delta: max(-12, min(12, round(delta / 3))) if abs(delta) >= 4 else 0
    subprocess.run(
        ["ydotool", "mousemove", "--", str(step(dx)), str(step(dy))],
        env=environment, check=True, stdout=subprocess.DEVNULL,
    )
    time.sleep(0.02)
else:
    raise SystemExit("Pointer did not converge; no click sent")
if geometry != query("xdotool", "getwindowgeometry", "--shell", args.window):
    raise SystemExit("Target window moved; no click sent")
if int(position["WINDOW"]) != int(args.window, 0):
    raise SystemExit("Pointer is over another window; no click sent")
if args.click:
    subprocess.run(
        ["ydotool", "click", "0xC0"], env=environment, check=True,
        stdout=subprocess.DEVNULL,
    )
print("Native pointer reached the requested point" + (" and clicked" if args.click else ""))

#!/usr/bin/env python3
"""Manual remote desktop probe; run inside the target's graphical session."""
import argparse
import json
import os
import signal
import time
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk


parser = argparse.ArgumentParser()
parser.add_argument("--state", required=True)
parser.add_argument("--label", default="OMEN")
parser.add_argument("--position", default="100,100")
args = parser.parse_args()
state_path = Path(args.state)
state = {"label": args.label, "text": "", "clicks": 0, "ticks": 0}

window = Gtk.Window(title=f"RustDesk verification — {args.label}")
window.set_default_size(1600, 900)
window.move(*map(int, args.position.split(",")))
css = Gtk.CssProvider()
css.load_from_data(b"* { font-size: 48px; } entry, button { min-height: 100px; }")
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
box.set_border_width(24)
window.add(box)
heading = Gtk.Label(label=f"RustDesk verification — {args.label}")
box.pack_start(heading, False, False, 0)
clock = Gtk.Label()
box.pack_start(clock, False, False, 0)
entry = Gtk.Entry()
entry.set_placeholder_text("Type a unique verification string through RustDesk")
box.pack_start(entry, False, False, 0)
button = Gtk.Button(label="Click count: 0")
box.pack_start(button, False, False, 0)


def save():
    # Atomic state snapshots let SSH observe results without injecting input.
    temporary = state_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    os.replace(temporary, state_path)


def tick():
    state["ticks"] += 1
    state["time"] = time.time()
    clock.set_text(f"{time.strftime('%H:%M:%S')}  |  Frame marker: {state['ticks']}")
    save()
    return True


def changed(widget):
    state["text"] = widget.get_text()
    save()


def clicked(_widget):
    state["clicks"] += 1
    button.set_label(f"Click count: {state['clicks']}")
    save()


entry.connect("changed", changed)
button.connect("clicked", clicked)
window.connect("destroy", Gtk.main_quit)
window.show_all()


def present():
    # GNOME may override a position requested before the X11 window is mapped.
    window.move(*map(int, args.position.split(",")))
    window.present()
    return False


GLib.timeout_add(500, present)
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, lambda: (present(), True)[1])
GLib.timeout_add_seconds(1, tick)
tick()
Gtk.main()

#!/usr/bin/env python3
"""Direct GTK GLArea motion source; count completed render callbacks, not submitted buffers."""
import argparse
import ctypes as C
import json
import time
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk, GLib, Gtk

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--monitor', type=int, required=True)
p.add_argument('--seconds', type=int, default=90)
args = p.parse_args()
display = Gdk.Display.get_default()
if not display or not 0 <= args.monitor < display.get_n_monitors():
    p.error('Monitor is not available')
gl = C.CDLL('libGLESv2.so.2')
def fn(name, result, *params):
    f = getattr(gl, name); f.restype = result; f.argtypes = params; return f
create_shader = fn('glCreateShader', C.c_uint, C.c_uint)
shader_source = fn('glShaderSource', None, C.c_uint, C.c_int, C.POINTER(C.c_char_p), C.c_void_p)
compile_shader = fn('glCompileShader', None, C.c_uint)
shader_status = fn('glGetShaderiv', None, C.c_uint, C.c_uint, C.POINTER(C.c_int))
create_program = fn('glCreateProgram', C.c_uint)
attach_shader = fn('glAttachShader', None, C.c_uint, C.c_uint)
link_program = fn('glLinkProgram', None, C.c_uint)
program_status = fn('glGetProgramiv', None, C.c_uint, C.c_uint, C.POINTER(C.c_int))
use_program = fn('glUseProgram', None, C.c_uint)
uniform_location = fn('glGetUniformLocation', C.c_int, C.c_uint, C.c_char_p)
uniform1f = fn('glUniform1f', None, C.c_int, C.c_float)
uniform2f = fn('glUniform2f', None, C.c_int, C.c_float, C.c_float)
viewport = fn('glViewport', None, C.c_int, C.c_int, C.c_int, C.c_int)
draw_arrays = fn('glDrawArrays', None, C.c_uint, C.c_int, C.c_int)
gen_vaos = fn('glGenVertexArrays', None, C.c_int, C.POINTER(C.c_uint))
bind_vao = fn('glBindVertexArray', None, C.c_uint)
get_string = fn('glGetString', C.c_char_p, C.c_uint)
window = Gtk.Window(title='RustDesk direct GL motion probe')
area = Gtk.GLArea()
area.set_use_es(True)
area.set_required_version(3, 0)
area.set_auto_render(False)
window.add(area)
started = time.monotonic()
next_frame = started
renders = 0
last_report = (started, 0)
failed = False
program = 0

def fail(message):
    global failed
    failed = True
    print(json.dumps({'error': str(message)}), flush=True)
    window.destroy()

def realize(widget):
    global program, time_location, size_location
    widget.make_current()
    if widget.get_error(): fail(widget.get_error()); return
    print(json.dumps({'gl_renderer': get_string(0x1F01).decode(), 'gl_version': get_string(0x1F02).decode()}), flush=True)
    sources = [(0x8B31, b'''#version 300 es
    void main(){ vec2 p=vec2((gl_VertexID<<1)&2, gl_VertexID&2); gl_Position=vec4(p*2.0-1.0,0,1); }'''),
    (0x8B30, b'''#version 300 es
    precision highp float; uniform float t; uniform vec2 size; out vec4 color;
    void main(){ vec2 uv=gl_FragCoord.xy/size; float x=uv.x+0.12*sin(t*2.0);
    vec3 c=0.5+0.5*cos(6.28318*(vec3(x,uv.y,x+uv.y)+vec3(0,.33,.67)));
    float lines=step(.1,fract((uv.y+t*.1)*32.0)); color=vec4(c*(.45+.55*lines),1); }''')]
    program = create_program()
    for kind, source in sources:
        shader = create_shader(kind); text = C.c_char_p(source)
        shader_source(shader, 1, C.byref(text), None); compile_shader(shader)
        ok = C.c_int(); shader_status(shader, 0x8B81, C.byref(ok))
        if not ok.value: fail('Shader compilation failed'); return
        attach_shader(program, shader)
    link_program(program); ok = C.c_int(); program_status(program, 0x8B82, C.byref(ok))
    if not ok.value: fail('Shader link failed'); return
    vao = C.c_uint(); gen_vaos(1, C.byref(vao)); bind_vao(vao)
    time_location = uniform_location(program, b't'); size_location = uniform_location(program, b'size')

def render(widget, _context):
    global renders
    if not program or failed: return True
    width = widget.get_allocated_width()*widget.get_scale_factor()
    height = widget.get_allocated_height()*widget.get_scale_factor()
    viewport(0, 0, width, height); use_program(program)
    uniform1f(time_location, time.monotonic()-started); uniform2f(size_location, width, height)
    draw_arrays(0x0004, 0, 3); renders += 1
    return True

def tick(widget, _clock):
    global next_frame
    now = time.monotonic()
    if now >= next_frame:
        widget.queue_render(); next_frame += 1/60
        if now-next_frame > 1/60: next_frame = now+1/60
    return True

def report():
    global last_report
    now = time.monotonic(); previous, count = last_report
    print(json.dumps({'elapsed_s': now-started, 'gl_render_fps': (renders-count)/(now-previous),
        'render_callbacks': renders}), flush=True)
    last_report = (now, renders)
    return True

area.connect('realize', realize); area.connect('render', render); area.add_tick_callback(tick)
window.connect('destroy', Gtk.main_quit)
window.fullscreen_on_monitor(window.get_screen(), args.monitor); window.show_all()
GLib.timeout_add(1000, report)
GLib.timeout_add_seconds(args.seconds, lambda: (window.destroy(), False)[1])
Gtk.main()
if failed: raise SystemExit(1)

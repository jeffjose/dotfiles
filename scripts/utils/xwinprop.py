#!/usr/bin/python3
"""xwinprop.py <window id> [--class NAME] [--icon SIZE] — retag an X11 window.

  --class NAME   set WM_CLASS to NAME (instance and class alike)
  --icon SIZE    set _NET_WM_ICON from SIZE*SIZE raw RGBA pixels on stdin
                 (`convert icon.png -resize 64x64! -depth 8 rgba:-`)

xprop can write neither: it stops at 64 elements, which is not one row of an
icon, and cannot put the NUL between the two halves of WM_CLASS. Plain ctypes
over libX11, so there is nothing to install.
"""
import argparse
import ctypes
import ctypes.util
import sys

parser = argparse.ArgumentParser(usage=__doc__)
parser.add_argument("window", type=lambda s: int(s, 0))
parser.add_argument("--class", dest="wm_class")
parser.add_argument("--icon", dest="icon_size", type=int)
args = parser.parse_args()

x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x11.XInternAtom.restype = ctypes.c_ulong
x11.XChangeProperty.argtypes = [
    ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_ulong,
    ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int,
]
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

dpy = x11.XOpenDisplay(None)
if not dpy:
    sys.exit("xwinprop: cannot open the X display")


def replace(prop, kind, fmt, buf, count):
    x11.XChangeProperty(
        dpy, args.window, x11.XInternAtom(dpy, prop, 0), x11.XInternAtom(dpy, kind, 0),
        fmt, 0, buf, count,  # 0 = PropModeReplace
    )


if args.wm_class:
    # Two NUL-terminated strings: the instance name, then the class.
    value = args.wm_class.encode() + b"\0" + args.wm_class.encode() + b"\0"
    replace(b"WM_CLASS", b"STRING", 8, ctypes.create_string_buffer(value, len(value)), len(value))

if args.icon_size:
    size = args.icon_size
    rgba = sys.stdin.buffer.read()
    if len(rgba) != size * size * 4:
        sys.exit(f"xwinprop: expected {size * size * 4} bytes of RGBA, got {len(rgba)}")
    # Width, height, then one ARGB value per pixel. Format-32 properties are
    # handed to Xlib as C longs, which are 64 bits wide here.
    data = [size, size]
    for i in range(0, len(rgba), 4):
        r, g, b, a = rgba[i : i + 4]
        data.append(a << 24 | r << 16 | g << 8 | b)
    replace(b"_NET_WM_ICON", b"CARDINAL", 32, (ctypes.c_ulong * len(data))(*data), len(data))

x11.XFlush(dpy)
x11.XCloseDisplay(dpy)

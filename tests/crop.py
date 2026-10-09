#!/usr/bin/env python3
"""Crop the popup's IPC-reported rectangle from a headless capture."""
import sys
from PIL import Image

if len(sys.argv) != 7:
    raise SystemExit("Usage: crop.py <src> <dst> <x> <y> <width> <height>")
x, y, width, height = map(int, sys.argv[3:])
image = Image.open(sys.argv[1])
if min(x, y) < 0 or min(width, height) <= 0 or x + width > image.width or y + height > image.height:
    raise ValueError("popup rectangle is outside the captured headless output")
image.crop((x, y, x + width, y + height)).save(sys.argv[2])

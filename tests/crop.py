#!/usr/bin/env python3
"""
Crops the OmaSports popup card from a full headless display capture.
Detects the distinctive popup border or card bounds.
"""
import sys
from PIL import Image

def crop_card(src_path, dst_path):
    im = Image.open(src_path).convert("RGB")
    w, h = im.size
    
    # 1. Find the top horizontal border
    top_y = None
    for y in range(20, h // 2):
        # Count bright blue/cyan pixels on this row (border color)
        blue_count = sum(1 for x in range(w) if im.getpixel((x, y))[2] > 200 and im.getpixel((x, y))[1] > 140)
        if blue_count > 300:
            top_y = y
            break
            
    if top_y is None:
        # Fallback: centered default box for 1920x1080
        left, top, right, bottom = 628, 38, 1292, min(h - 50, 750)
    else:
        left = min(x for x in range(w) if im.getpixel((x, top_y))[2] > 190 and im.getpixel((x, top_y))[1] > 130)
        right = max(x for x in range(w) if im.getpixel((x, top_y))[2] > 190 and im.getpixel((x, top_y))[1] > 130)
        
        # Trace down left border to find bottom
        col_x = left
        bottom = top_y
        # Follow the contiguous panel edge, not similarly colored wallpaper.
        for y in range(top_y + 1, h):
            pixel = im.getpixel((col_x, y))
            if pixel[2] <= 190 or pixel[1] <= 130:
                break
            bottom = y
        
    box = (max(0, left - 1), max(0, top_y if top_y else 38), min(w, right + 2), min(h, bottom + 2))
    cropped = im.crop(box)
    cropped.save(dst_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: crop.py <src> <dst>")
        sys.exit(1)
    crop_card(sys.argv[1], sys.argv[2])

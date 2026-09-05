#!/usr/bin/env python3
"""
Perceptual visual regression diffing engine for OmaSports.
Compares a candidate screenshot against an approved baseline image.
Generates a 3-way comparative diff with mismatched pixels highlighted in neon magenta.
"""
import sys
import json
import math
from PIL import Image

def perceptual_diff(baseline_path, candidate_path, diff_path, tolerance_percent=0.5, color_threshold=18):
    try:
        base = Image.open(baseline_path).convert("RGBA")
        cand = Image.open(candidate_path).convert("RGBA")
    except Exception as e:
        res = {
            "error": str(e),
            "status": "ERROR",
            "diffPercent": 100.0,
            "mismatchedPixels": -1,
            "totalPixels": 0
        }
        print(json.dumps(res))
        sys.exit(1)

    w = max(base.width, cand.width)
    h = max(base.height, cand.height)

    # Standardize image canvas sizes if subtle height difference due to scrollbar
    if base.size != (w, h):
        new_base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        new_base.paste(base, (0, 0))
        base = new_base

    if cand.size != (w, h):
        new_cand = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        new_cand.paste(cand, (0, 0))
        cand = new_cand

    diff_img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    base_pixels = base.load()
    cand_pixels = cand.load()
    diff_pixels = diff_img.load()

    mismatched = 0
    total = w * h

    for y in range(h):
        for x in range(w):
            b_r, b_g, b_b, b_a = base_pixels[x, y]
            c_r, c_g, c_b, c_a = cand_pixels[x, y]

            # Color distance (Euclidean in RGB)
            dist = math.sqrt((b_r - c_r) ** 2 + (b_g - c_g) ** 2 + (b_b - c_b) ** 2)

            if dist > color_threshold or abs(b_a - c_a) > 20:
                mismatched += 1
                # Mismatch: Bright neon magenta (#ff007f)
                diff_pixels[x, y] = (255, 0, 127, 255)
            else:
                # Match: Subdued dim gray background from candidate
                gray = int(0.299 * c_r + 0.587 * c_g + 0.114 * c_b) // 3
                diff_pixels[x, y] = (gray, gray, gray, 255)

    diff_percent = round((mismatched / float(total)) * 100.0, 3)
    passed = diff_percent <= tolerance_percent

    diff_img.save(diff_path)

    result = {
        "baseline": baseline_path,
        "candidate": candidate_path,
        "diff": diff_path,
        "diffPercent": diff_percent,
        "mismatchedPixels": mismatched,
        "totalPixels": total,
        "tolerancePercent": tolerance_percent,
        "status": "PASS" if passed else "FAIL"
    }

    print(json.dumps(result))
    sys.exit(0 if passed else 1)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: diff.py <baseline.png> <candidate.png> <diff.png> [tolerance_percent]")
        sys.exit(2)

    baseline = sys.argv[1]
    candidate = sys.argv[2]
    diff_out = sys.argv[3]
    tolerance = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5

    perceptual_diff(baseline, candidate, diff_out, tolerance)

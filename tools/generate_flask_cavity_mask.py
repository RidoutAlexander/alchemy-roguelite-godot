"""Bake score_flask_cavity_mask.png: vertical walls + semicircular floor."""
from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image

GUIDE_TEXTURE_HEIGHT = 1024
GUIDE_TEXTURE_WIDTH = 576
GUIDE_TOP_Y = 133
GUIDE_BOTTOM_Y = 898
GUIDE_CENTER_X = 287.5
GUIDE_BODY_HALF_WIDTH = 56.0


def scale_guide_y(guide_y: int, texture_height: int) -> int:
    scaled = round(guide_y * texture_height / GUIDE_TEXTURE_HEIGHT)
    return max(0, min(texture_height - 1, scaled))


def scale_guide_x(guide_x: float, texture_width: int) -> int:
    scaled = round(guide_x * texture_width / GUIDE_TEXTURE_WIDTH)
    return max(0, min(texture_width - 1, scaled))


def build_mask(img: Image.Image) -> Image.Image:
    width, height = img.size
    top_y = scale_guide_y(GUIDE_TOP_Y, height)
    bottom_y = scale_guide_y(GUIDE_BOTTOM_Y, height)
    center_x = scale_guide_x(GUIDE_CENTER_X, width)
    body_half_w = scale_guide_x(GUIDE_BODY_HALF_WIDTH, width)
    flat_y = max(top_y, bottom_y - round(body_half_w))
    wall_half_w = float(body_half_w)
    sagitta = max(1.0, float(bottom_y - flat_y))
    arc_radius = (wall_half_w * wall_half_w + sagitta * sagitta) / (2.0 * sagitta)
    arc_center_y = float(flat_y) - arc_radius + sagitta
    arc_radius_sq = arc_radius * arc_radius
    body_left = max(0, int(math.floor(center_x - wall_half_w)))
    body_right = min(width - 1, int(math.ceil(center_x + wall_half_w)))

    mask = Image.new("L", (width, height), 0)

    for y in range(top_y, bottom_y + 1):
        for x in range(body_left, body_right + 1):
            dx = float(x) - float(center_x)
            if y <= flat_y:
                if abs(dx) <= wall_half_w:
                    mask.putpixel((x, y), 255)
                continue

            dy = float(y) - arc_center_y
            if dx * dx + dy * dy <= arc_radius_sq:
                mask.putpixel((x, y), 255)

    return mask


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    src = root / "assets" / "sprites" / "score_flask.png"
    dst = root / "assets" / "sprites" / "score_flask_cavity_mask.png"

    if not src.exists():
        print(f"Missing source sprite: {src}", file=sys.stderr)
        return 1

    flask = Image.open(src).convert("RGBA")
    mask = build_mask(flask)
    mask.save(dst)
    print(f"Wrote {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
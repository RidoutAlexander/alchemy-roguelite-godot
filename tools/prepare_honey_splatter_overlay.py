"""Prepare the honey splatter hand overlay — remove exterior white background."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = Path.home() / "Downloads" / "grok-799dcf38-59b3-4532-949f-a37c3370c5d7.jpg"
OUT = ROOT / "assets/cards/ingredients/honey_splatter_overlay.png"

from prepare_score_flask import clear_exterior_white_fringe, flood_exterior_background, zero_transparent_rgb

import numpy as np
from PIL import Image


def prepare(src: Path, out: Path) -> None:
    image = Image.open(src).convert("RGB")
    rgb = np.array(image)
    background = flood_exterior_background(rgb)

    rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(background, 0, 255).astype(np.uint8)

    zeroed = zero_transparent_rgb(rgba)
    fringe_cleared = clear_exterior_white_fringe(rgba)

    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)
    opaque = int((rgba[:, :, 3] > 0).sum())
    print(
        f"Saved {out.relative_to(ROOT)}: opaque={opaque}, "
        f"transparent_rgb_zeroed={zeroed}, fringe_cleared={fringe_cleared}"
    )


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    if not src.exists():
        print(f"Missing source image: {src}")
        return 1
    prepare(src, OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
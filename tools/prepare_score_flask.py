"""Prepare the score flask sprite — remove ONLY exterior white background."""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = (
    Path.home()
    / ".grok/sessions/C%3A%5CUsers%5Cridou%5COneDrive%5CDesktop%5CRPG"
    / "019f0c65-4a6b-7de2-a35a-8d36f667a4c6/assets"
    / "image-e00ad163-275b-4527-933c-44be22468151.jpg"
)
OUT = ROOT / "assets/sprites/score_flask.png"


def is_exterior_background(rgb: tuple[int, int, int]) -> bool:
    """Exterior canvas white — stops before glass interior (~234 RGB)."""
    minimum = min(rgb)
    maximum = max(rgb)
    return minimum >= 243 and (maximum - minimum) < 15


def flood_exterior_background(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    background = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def try_seed(y: int, x: int) -> None:
        if not background[y, x] and is_exterior_background(tuple(rgb[y, x])):
            background[y, x] = True
            queue.append((y, x))

    for x in range(width):
        try_seed(0, x)
        try_seed(height - 1, x)
    for y in range(height):
        try_seed(y, 0)
        try_seed(y, width - 1)

    while queue:
        y, x = queue.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if (
                0 <= ny < height
                and 0 <= nx < width
                and not background[ny, nx]
                and is_exterior_background(tuple(rgb[ny, nx]))
            ):
                background[ny, nx] = True
                queue.append((ny, nx))
    return background


def dilate(mask: np.ndarray, depth: int = 1) -> np.ndarray:
    result = mask.copy()
    for _ in range(depth):
        expanded = result.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                shifted = np.roll(expanded, shift=(dy, dx), axis=(0, 1))
                if dy < 0:
                    shifted[dy:, :] = False
                elif dy > 0:
                    shifted[:dy, :] = False
                if dx < 0:
                    shifted[:, dx:] = False
                elif dx > 0:
                    shifted[:, :dx] = False
                result |= shifted
    return result


def zero_transparent_rgb(data: np.ndarray) -> int:
    transparent = data[:, :, 3] == 0
    changed = int(transparent.sum())
    data[transparent, 0] = 0
    data[transparent, 1] = 0
    data[transparent, 2] = 0
    return changed


def clear_exterior_white_fringe(data: np.ndarray) -> int:
    """Remove opaque white halo pixels that touch transparent exterior only."""
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    alpha = data[:, :, 3]

    transparent = alpha == 0
    fringe = (
        dilate(transparent, 1)
        & (alpha > 0)
        & (minimum >= 236)
        & (delta < 25)
    )
    cleared = int(fringe.sum())
    data[fringe, 0] = 0
    data[fringe, 1] = 0
    data[fringe, 2] = 0
    data[fringe, 3] = 0
    return cleared


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
    trans_white = int(
        ((rgba[:, :, 3] == 0) & (rgba[:, :, :3].max(axis=2) > 0)).sum()
    )
    print(
        f"Saved {out.relative_to(ROOT)}: opaque={opaque}, "
        f"transparent_rgb_zeroed={zeroed}, fringe_cleared={fringe_cleared}, "
        f"trans_with_color_left={trans_white}"
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
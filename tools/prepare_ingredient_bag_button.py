"""Prepare the ingredient bag button sprite from a white-background source image."""
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
    / "image-3cb53d5e-ddd2-4acd-a25b-2045bafa605a.jpg"
)
OUT = ROOT / "assets/sprites/ingredient_bag_button.png"


def is_background_pixel(rgb: tuple[int, int, int]) -> bool:
    minimum = min(rgb)
    maximum = max(rgb)
    return minimum >= 230 and (maximum - minimum) < 20


def is_exterior_fringe_pixel(rgb: tuple[int, int, int]) -> bool:
    minimum = min(rgb)
    maximum = max(rgb)
    return minimum >= 200 and (maximum - minimum) < 20


def flood_mask(rgb: np.ndarray, predicate) -> np.ndarray:
    height, width = rgb.shape[:2]
    background = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def try_seed(y: int, x: int) -> None:
        if not background[y, x] and predicate(tuple(rgb[y, x])):
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
                and predicate(tuple(rgb[ny, nx]))
            ):
                background[ny, nx] = True
                queue.append((ny, nx))
    return background


def flood_background_mask(rgb: np.ndarray) -> np.ndarray:
    return flood_mask(rgb, is_background_pixel)


def flood_exterior_fringe_mask(rgb: np.ndarray) -> np.ndarray:
    return flood_mask(rgb, is_exterior_fringe_pixel)


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


def clean_edges(data: np.ndarray, depth: int = 5) -> None:
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    alpha = data[:, :, 3]

    artifact = (alpha > 0) & (minimum >= 235) & (delta < 12)
    data[artifact, 3] = 0

    transparent = alpha == 0
    border = dilate(transparent, depth) & ~transparent & (alpha > 0)
    neutral = border & (delta < 35)

    dark = neutral & (maximum < 80)
    data[dark, 0] = 0
    data[dark, 1] = 0
    data[dark, 2] = 0
    data[dark, 3] = 255

    to_clear = neutral & (alpha > 0) & (alpha < 140) & (maximum >= 80)
    data[to_clear, 3] = 0

    semi = neutral & (alpha >= 140) & (alpha < 255)
    data[semi, 0] = 0
    data[semi, 1] = 0
    data[semi, 2] = 0
    data[semi, 3] = 255

    light_opaque = neutral & (alpha == 255) & (minimum >= 80)
    data[light_opaque, 0] = 0
    data[light_opaque, 1] = 0
    data[light_opaque, 2] = 0

    neutral_semi = (alpha > 0) & (alpha < 255) & (delta < 20)
    data[neutral_semi & (alpha < 140) & (maximum >= 80), 3] = 0
    to_black = neutral_semi & ((alpha >= 140) | (maximum < 80))
    data[to_black, 0] = 0
    data[to_black, 1] = 0
    data[to_black, 2] = 0
    data[to_black, 3] = 255


def prepare(src: Path, out: Path) -> None:
    image = Image.open(src).convert("RGB")
    rgb = np.array(image)
    background = flood_background_mask(rgb)

    rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(background, 0, 255).astype(np.uint8)

    fringe = flood_exterior_fringe_mask(rgb)
    rgba[fringe, 3] = 0

    clean_edges(rgba, depth=5)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)

    opaque = (rgba[:, :, 3] > 0).sum()
    semi = ((rgba[:, :, 3] > 0) & (rgba[:, :, 3] < 255)).sum()
    print(f"Saved {out.relative_to(ROOT)}: opaque={opaque}, semi={semi}")


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    if not src.exists():
        print(f"Missing source image: {src}")
        return 1
    prepare(src, OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
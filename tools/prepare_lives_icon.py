"""Prepare lives potion icons: transparent exterior matte only.

Uses the bottle outline to separate interior art (glass, glare, liquid) from the
surrounding white JPG background. Never flood-fills the full near-white sheet.
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = Path(
    r"C:\Users\ridou\Downloads\grok-4a92a644-5ca7-40f9-a848-b8d56ec011d3.jpg"
)
DEFAULT_EMPTY_SRC = (
    Path.home()
    / ".grok/sessions/C%3A%5CUsers%5Cridou%5COneDrive%5CDesktop%5CRPG"
    / "019f0c65-4a6b-7de2-a35a-8d36f667a4c6/assets"
    / "image-efa468e9-b164-44ef-913c-acc25b2ad710.jpg"
)
OUT = ROOT / "assets/sprites/lives_icon.png"
OUT_EMPTY = ROOT / "assets/sprites/lives_icon_empty.png"


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


def bottle_colored_mask(rgb: np.ndarray) -> np.ndarray:
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    delta = maximum - minimum
    colored = (delta >= 18) | (maximum < 200)
    labeled, _ = ndimage.label(colored)
    counts = np.bincount(labeled.ravel())
    counts[0] = 0
    return labeled == int(counts.argmax())


def interior_art_mask(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    delta = maximum - minimum

    outline = maximum < 80
    closed_outline = ndimage.binary_closing(outline, iterations=2)
    bottle = bottle_colored_mask(rgb)

    ys, xs = np.where(bottle)
    seed_y, seed_x = int(ys.mean()), int(xs.mean())

    interior = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque([(seed_y, seed_x)])
    interior[seed_y, seed_x] = True
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if (
                0 <= ny < height
                and 0 <= nx < width
                and not interior[ny, nx]
                and not closed_outline[ny, nx]
            ):
                interior[ny, nx] = True
                queue.append((ny, nx))

    return interior | bottle | outline


def build_opaque_mask(rgb: np.ndarray, fringe_px: int = 3) -> np.ndarray:
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    delta = maximum - minimum
    near_white = (minimum >= 240) & (delta < 20)

    bottle = bottle_colored_mask(rgb)
    opaque = interior_art_mask(rgb)

    if fringe_px > 0:
        dist = distance_transform_edt(~bottle)
        opaque |= near_white & (dist < fringe_px)

    return opaque


def clear_image_border_near_white(data: np.ndarray, border_width: int = 8) -> None:
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    height, width = data.shape[:2]

    border = np.zeros((height, width), dtype=bool)
    border[:border_width, :] = True
    border[-border_width:, :] = True
    border[:, :border_width] = True
    border[:, -border_width:] = True

    near_white = (minimum >= 238) & (delta < 20)
    data[border & near_white, 3] = 0


def clean_border_fringe(data: np.ndarray, depth: int = 3) -> None:
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    alpha = data[:, :, 3]

    transparent = alpha == 0
    border = dilate(transparent, depth) & ~transparent & (alpha > 0)
    neutral = border & (delta < 35)

    light_opaque = neutral & (alpha == 255) & (minimum >= 80)
    data[light_opaque, 0] = 0
    data[light_opaque, 1] = 0
    data[light_opaque, 2] = 0

    to_clear = neutral & (minimum >= 235) & (delta < 12)
    data[to_clear, 3] = 0


def crop_to_opaque_bounds(data: np.ndarray, padding: int = 2) -> np.ndarray:
    opaque = data[:, :, 3] > 0
    if not opaque.any():
        return data

    ys, xs = np.where(opaque)
    y0 = max(0, int(ys.min()) - padding)
    y1 = min(data.shape[0], int(ys.max()) + padding + 1)
    x0 = max(0, int(xs.min()) - padding)
    x1 = min(data.shape[1], int(xs.max()) + padding + 1)
    return data[y0:y1, x0:x1].copy()


def prepare(src: Path, out: Path, fringe_px: int = 3) -> None:
    image = Image.open(src).convert("RGB")
    rgb = np.array(image)
    opaque = build_opaque_mask(rgb, fringe_px)

    rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(opaque, 255, 0).astype(np.uint8)

    clear_image_border_near_white(rgba)
    clean_border_fringe(rgba)
    rgba = crop_to_opaque_bounds(rgba)

    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)

    white_opaque = (
        (rgba[:, :, 3] > 0)
        & (rgba[:, :, 0] > 235)
        & (rgba[:, :, 1] > 235)
        & (rgba[:, :, 2] > 235)
    )
    print(
        f"Saved {out.relative_to(ROOT)} ({rgba.shape[1]}x{rgba.shape[0]}): "
        f"white_opaque={int(white_opaque.sum())}, semi=0"
    )


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] in {"--all", "-a"}:
        sources = [
            (DEFAULT_SRC, OUT),
            (DEFAULT_EMPTY_SRC, OUT_EMPTY),
        ]
        for src, out in sources:
            if not src.exists():
                print(f"Missing source image: {src}")
                return 1
            prepare(src, out)
        return 0

    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    if not src.exists():
        print(f"Missing source image: {src}")
        return 1
    prepare(src, out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
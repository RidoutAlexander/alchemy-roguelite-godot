"""Fix only tiny white fringe pixels on sprite borders. Never flood-fill or restore halos.

Do NOT add ingredient card art here. Use tools/prepare_ingredient_art.py instead so
interior highlights and white fills stay opaque.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
UI_ASSETS = [
    ROOT / "assets/sprites/wooden_button_background.png",
    ROOT / "assets/cards/parchment_plate.png",
    ROOT / "assets/cards/icons/points_icon.png",
    ROOT / "assets/cards/icons/explosive_icon.png",
    ROOT / "assets/cards/icons/gold_icon.png",
    ROOT / "assets/cards/ingredients/boom_berry.png",
    ROOT / "assets/cards/ingredients/pumpkin.png",
    ROOT / "assets/cards/ingredients/jackolantern.png",
]

# Buttons have a wide neutral-gray anti-alias ring; other sprites use a thinner pass.
BORDER_DEPTH_BY_ASSET: dict[str, int] = {
    "wooden_button_background.png": 5,
    "parchment_plate.png": 3,
}

# Never clear dark fringe to transparent; restore eaten black outline gaps.
PRESERVE_BLACK_BORDER_ASSETS: frozenset[str] = frozenset(
    {"parchment_plate.png"}
)


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


def remove_neutral_white_artifacts(data: np.ndarray) -> int:
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    artifact = (data[:, :, 3] > 0) & (minimum >= 235) & (delta < 12)
    cleared = int(artifact.sum())
    data[artifact, 3] = 0
    return cleared


def fix_border_white_fringe(data: np.ndarray, depth: int = 2) -> int:
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    alpha = data[:, :, 3]

    transparent = alpha == 0
    border = dilate(transparent, depth) & ~transparent & (alpha > 0)

    white_fringe = border & (minimum >= 180) & (maximum <= 252) & (delta <= 28)
    changed = int(white_fringe.sum())
    data[white_fringe, 0] = 0
    data[white_fringe, 1] = 0
    data[white_fringe, 2] = 0
    data[white_fringe, 3] = 255
    return changed


def is_parchment_interior(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    minimum = rgb.min(axis=2)
    delta = rgb.max(axis=2) - rgb.min(axis=2)
    return (
        (alpha > 0)
        & (delta >= 25)
        & (rgb[:, :, 0] >= rgb[:, :, 2])
        & (minimum > 60)
    )


def restore_eaten_black_border(data: np.ndarray) -> int:
    """Restore border pixels whose alpha was cleared but dark RGB remains."""
    rgb = data[:, :, :3].astype(np.int16)
    alpha = data[:, :, 3]
    maximum = rgb.max(axis=2)

    eaten = (alpha == 0) & (maximum < 80)
    restored = int(eaten.sum())
    data[eaten, 0] = 0
    data[eaten, 1] = 0
    data[eaten, 2] = 0
    data[eaten, 3] = 255
    return restored


def fix_border_neutral_fringe(
    data: np.ndarray,
    depth: int = 2,
    alpha_cutoff: int = 140,
    preserve_black_border: bool = False,
) -> tuple[int, int, int]:
    """Snap neutral anti-alias fringe to transparent or solid black.

    Semi-transparent gray pixels on the border are the main source of white halos
    when Godot linear-filters the texture. Wood tones (delta >= 35) are preserved.
    """
    rgb = data[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    alpha = data[:, :, 3]

    transparent = alpha == 0
    border = dilate(transparent, depth) & ~transparent & (alpha > 0)
    neutral = border & (delta < 35)

    if preserve_black_border:
        dark = neutral & (maximum < 80)
        data[dark, 0] = 0
        data[dark, 1] = 0
        data[dark, 2] = 0
        data[dark, 3] = 255

    to_clear = neutral & (alpha > 0) & (alpha < alpha_cutoff)
    if preserve_black_border:
        to_clear &= maximum >= 80
    cleared = int(to_clear.sum())
    data[to_clear, 3] = 0

    semi = neutral & (alpha >= alpha_cutoff) & (alpha < 255)
    semi_snapped = int(semi.sum())
    data[semi, 0] = 0
    data[semi, 1] = 0
    data[semi, 2] = 0
    data[semi, 3] = 255

    light_opaque = neutral & (alpha == 255) & (minimum >= 80)
    blackened = int(light_opaque.sum())
    data[light_opaque, 0] = 0
    data[light_opaque, 1] = 0
    data[light_opaque, 2] = 0

    return cleared, semi_snapped, blackened


def fix_remaining_neutral_semi(
    data: np.ndarray,
    alpha_cutoff: int = 140,
    preserve_black_border: bool = False,
) -> int:
    """Catch neutral semi-transparent pixels missed by the border zone."""
    rgb = data[:, :, :3].astype(np.int16)
    maximum = rgb.max(axis=2)
    delta = rgb.max(axis=2) - rgb.min(axis=2)
    alpha = data[:, :, 3]

    neutral_semi = (alpha > 0) & (alpha < 255) & (delta < 20)
    changed = int(neutral_semi.sum())

    to_clear = neutral_semi & (alpha < alpha_cutoff)
    if preserve_black_border:
        to_clear &= maximum >= 80
    data[to_clear, 3] = 0

    to_black = neutral_semi & (alpha >= alpha_cutoff)
    data[to_black, 0] = 0
    data[to_black, 1] = 0
    data[to_black, 2] = 0
    data[to_black, 3] = 255

    if preserve_black_border:
        dark_semi = neutral_semi & (maximum < 80)
        data[dark_semi, 0] = 0
        data[dark_semi, 1] = 0
        data[dark_semi, 2] = 0
        data[dark_semi, 3] = 255
    return changed


def border_depth_for(path: Path) -> int:
    return BORDER_DEPTH_BY_ASSET.get(path.name, 2)


def process_image(path: Path) -> None:
    depth = border_depth_for(path)
    preserve_black_border = path.name in PRESERVE_BLACK_BORDER_ASSETS
    image = Image.open(path).convert("RGBA")
    data = np.array(image, copy=True)
    border_restored = 0
    if preserve_black_border:
        border_restored = restore_eaten_black_border(data)
    artifacts_cleared = remove_neutral_white_artifacts(data)
    white_blackened = fix_border_white_fringe(data, depth=depth)
    fringe_cleared, semi_snapped, light_blackened = fix_border_neutral_fringe(
        data, depth=depth, preserve_black_border=preserve_black_border
    )
    remaining_semi = 0
    if path.name in BORDER_DEPTH_BY_ASSET:
        remaining_semi = fix_remaining_neutral_semi(
            data, preserve_black_border=preserve_black_border
        )
    Image.fromarray(data, "RGBA").save(path)
    opaque_ratio = (data[:, :, 3] > 0).mean() * 100.0
    semi_left = int(((data[:, :, 3] > 0) & (data[:, :, 3] < 255)).sum())
    print(
        f"{path.relative_to(ROOT)}: depth={depth}, artifacts_cleared={artifacts_cleared}, "
        f"black_border_restored={border_restored}, white_to_black={white_blackened}, "
        f"fringe_cleared={fringe_cleared}, semi_snapped={semi_snapped}, "
        f"light_opaque_blackened={light_blackened}, remaining_semi={remaining_semi}, "
        f"semi_left={semi_left}, opaque={opaque_ratio:.1f}%"
    )


def main() -> int:
    targets = UI_ASSETS
    if len(sys.argv) > 1:
        targets = [Path(arg) for arg in sys.argv[1:]]
    for asset in targets:
        if not asset.exists():
            print(f"Missing: {asset}")
            return 1
        process_image(asset)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
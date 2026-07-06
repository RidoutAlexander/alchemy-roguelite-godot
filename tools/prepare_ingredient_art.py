"""Prepare user-supplied ingredient art: matte/checkerboard -> transparent PNG.

IMPORTANT: Only the exterior matte/checkerboard background is removed.
Interior art (highlights, white spots, glass glare, veins, etc.) must stay
fully opaque. Never run fix_sprite_transparency.py on ingredient art.

Usage:
  py tools/prepare_ingredient_art.py <source_image> <art_name>
  py tools/prepare_ingredient_art.py <source_image> --out assets/cards/ingredients/foo.png
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
INGREDIENTS_DIR = ROOT / "assets" / "cards" / "ingredients"
GODOT_EXE = Path(
    r"C:\Users\ridou\Downloads\Godot463\Godot_v4.6.3-stable_win64_console.exe"
)

SESSION_ASSETS = Path(
    r"C:\Users\ridou\.grok\sessions\C%3A%5CUsers%5Cridou%5COneDrive%5CDesktop%5CRPG"
    r"\019f0c65-4a6b-7de2-a35a-8d36f667a4c6\assets"
)

# Known-good sources for bundled ingredient art (re-run with --repair-all).
KNOWN_SOURCES: dict[str, Path] = {
    "boom_berry": SESSION_ASSETS / "image-91236c20-6969-46f2-911b-11eeba55272c.jpg",
    "pumpkin": SESSION_ASSETS / "image-e36d8026-d587-498b-9efd-76bf3d3dbf3c.jpg",
    "jackolantern": SESSION_ASSETS / "image-24d502a9-8b00-4abd-b76e-acc458d3c0a2.jpg",
    "chili_pepper": SESSION_ASSETS / "image-515a8cd2-c066-459b-9b2c-94261e6313f2.jpg",
    "red_mushroom": SESSION_ASSETS / "image-cb7e60fc-5112-4829-955d-47a3d091b03b.jpg",
    "lightning_in_a_bottle": SESSION_ASSETS / "image-c3a6102c-994a-49d0-b6c0-fbdec05d4fcb.jpg",
    "eyeball": SESSION_ASSETS / "image-6fe60813-a3a1-4aa2-ba4c-95c7950e23b2.jpg",
    "unicorn_horn": SESSION_ASSETS / "image-654f3e0f-a390-4922-8005-db6794edfc1a.jpg",
    "parrot": SESSION_ASSETS / "image-0f829e60-ead6-46b8-8722-0c76d27a7724.jpg",
    "feather": SESSION_ASSETS / "image-cb551471-17e9-45f7-9306-c7d94b1d024d.jpg",
    "mandrake": SESSION_ASSETS / "image-7506580e-12bb-4253-b677-4790db46c820.jpg",
    "spider": SESSION_ASSETS / "image-92145769-b7a5-4a29-9f5e-5ec47434e2d1.jpg",
    "thorns": SESSION_ASSETS / "image-4a1ad30e-e54c-467e-91cb-e935d8c4de12.jpg",
    "cinnamon": SESSION_ASSETS / "image-7cf657ed-f989-4b9e-8dd0-e94332f42ac0.jpg",
    "eye_of_ender": Path(
        r"C:\Users\ridou\Downloads\grok-cca9a8ef-f4a7-43a2-a2bb-b0069fcb3761.jpg"
    ),
    "lucky_coin": Path(
        r"C:\Users\ridou\Downloads\grok-82488574-8be3-4b6d-9583-8d813230dc83.jpg"
    ),
    "fish_bones": Path(
        r"C:\Users\ridou\Downloads\grok-32fa159a-c20d-487b-bf35-2770d3c03705.jpg"
    ),
}


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


def all_colored_mask(rgb: np.ndarray) -> np.ndarray:
    """Colored subject pixels only. Matte/checkerboard backdrop is never colored."""
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    delta = maximum - minimum
    colored = (delta >= 18) | (maximum < 200)
    return colored & ~is_exterior_matte(rgb)


def subject_colored_mask(rgb: np.ndarray) -> np.ndarray:
    colored = all_colored_mask(rgb)
    labeled, _ = ndimage.label(colored)
    counts = np.bincount(labeled.ravel())
    counts[0] = 0
    if counts.max() == 0:
        return colored
    return labeled == int(counts.argmax())


def interior_art_mask(rgb: np.ndarray) -> np.ndarray:
    """Flood interior from the subject, blocked by the dark outline."""
    height, width = rgb.shape[:2]
    maximum = rgb.max(axis=2)

    outline = maximum < 80
    closed_outline = ndimage.binary_closing(outline, iterations=2)
    subject = subject_colored_mask(rgb)

    ys, xs = np.where(subject)
    if ys.size == 0:
        return subject | outline

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

    return interior | subject | outline


def backdrop_color_from_corners(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    corners = np.array(
        [
            rgb[0, 0],
            rgb[0, width - 1],
            rgb[height - 1, 0],
            rgb[height - 1, width - 1],
        ],
        dtype=np.float32,
    )
    return corners.mean(axis=0)


def is_strict_backdrop_pixel(
    rgb: np.ndarray,
    backdrop: np.ndarray,
    *,
    tolerance: int = 3,
    max_delta: int = 8,
) -> np.ndarray:
    """Match only the flat exterior JPG/checkerboard shade, not bone highlights."""
    dist = np.abs(rgb.astype(np.float32) - backdrop[None, None, :]).max(axis=2)
    delta = rgb.max(axis=2) - rgb.min(axis=2)
    return (dist <= tolerance) & (delta < max_delta)


def build_opaque_mask_fish_bones(rgb: np.ndarray) -> np.ndarray:
    """Keep every interior pixel opaque; clear only edge-connected backdrop matte."""
    backdrop = backdrop_color_from_corners(rgb)
    exterior_matte = is_strict_backdrop_pixel(rgb, backdrop)
    exterior = flood_mask_from_edges(exterior_matte)
    interior = interior_art_mask(rgb)
    return interior | ~exterior


def clean_strict_backdrop_fringe(
    data: np.ndarray,
    source_rgb: np.ndarray,
    *,
    tolerance: int = 5,
    depth: int = 3,
) -> None:
    """Remove backdrop-colored halo pixels touching transparent exterior only."""
    backdrop = backdrop_color_from_corners(source_rgb)
    backdrop_mask = is_strict_backdrop_pixel(
        source_rgb,
        backdrop,
        tolerance=tolerance,
        max_delta=10,
    )
    alpha = data[:, :, 3]
    transparent = alpha == 0
    border = dilate(transparent, depth) & ~transparent & (alpha > 0)
    data[border & backdrop_mask, 3] = 0


def is_exterior_matte(rgb: np.ndarray) -> np.ndarray:
    """Checkerboard / white JPG backdrop only. Never matches colored interior art."""
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    checker_gray = (minimum >= 140) & (minimum <= 225) & (delta < 22)
    near_white = (minimum >= 230) & (delta < 18)
    # Light checker squares (e.g. 226/233 RGB) sit between the ranges above.
    backdrop_neutral = (minimum >= 210) & (delta < 10)
    return checker_gray | near_white | backdrop_neutral


def subject_shell_mask(source_rgb: np.ndarray, dilate_depth: int = 3) -> np.ndarray:
    colored = all_colored_mask(source_rgb)
    outline = source_rgb.max(axis=2) < 80
    subject = subject_colored_mask(source_rgb)
    return dilate(colored | outline | subject, dilate_depth)


def flood_mask_from_edges(seed_mask: np.ndarray) -> np.ndarray:
    height, width = seed_mask.shape
    flooded = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        if seed_mask[0, x]:
            flooded[0, x] = True
            queue.append((0, x))
        if seed_mask[height - 1, x]:
            flooded[height - 1, x] = True
            queue.append((height - 1, x))
    for y in range(height):
        if seed_mask[y, 0]:
            flooded[y, 0] = True
            queue.append((y, 0))
        if seed_mask[y, width - 1]:
            flooded[y, width - 1] = True
            queue.append((y, width - 1))

    while queue:
        y, x = queue.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if (
                0 <= ny < height
                and 0 <= nx < width
                and not flooded[ny, nx]
                and seed_mask[ny, nx]
            ):
                flooded[ny, nx] = True
                queue.append((ny, nx))

    return flooded


def flood_exterior_from_edges(matte_mask: np.ndarray) -> np.ndarray:
    return flood_mask_from_edges(matte_mask)


def build_opaque_mask(
    rgb: np.ndarray,
    fringe_px: int = 5,
    shell_dilate: int = 2,
    interior_guard: float = 0.85,
    aa_delta: int = 55,
) -> np.ndarray:
    """Keep subject shell + interior art opaque; clear only edge-connected exterior matte.

    Spider leg gaps stay transparent because enclosed white/checkerboard never joins the
    dilated subject shell. Back glare and other interior highlights stay opaque via the
    interior flood. Wreath-like art (thorns) skips the interior merge when it would
    flood nearly the entire frame.
    """
    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    delta = maximum - minimum
    outline = maximum < 80
    subject = subject_colored_mask(rgb)
    colored = all_colored_mask(rgb)
    shell = dilate(subject | outline | colored, shell_dilate)
    interior = interior_art_mask(rgb)

    if interior.mean() > interior_guard:
        opaque = shell.copy()
    else:
        opaque = shell | interior

    exterior_matte = is_exterior_matte(rgb)
    near_subject = subject | colored
    dist = distance_transform_edt(~near_subject)
    near_white = (minimum >= 228) & (delta < 22)
    opaque |= near_white & (dist < fringe_px) & ~exterior_matte

    dist_colored = distance_transform_edt(~colored)
    opaque |= (delta < 20) & (dist_colored < 3) & ~exterior_matte

    exterior = flood_exterior_from_edges(exterior_matte)
    opaque &= ~exterior

    enclosed = exterior_matte & ~exterior
    # Enclosed highlights hugging colored art (e.g. spider back glare spots).
    opaque |= (
        enclosed
        & (dist_colored <= 2)
        & (minimum >= 220)
        & (delta < 20)
    )

    ys, xs = np.where(subject)
    if ys.size:
        dist_shell = distance_transform_edt(~shell)
        # Seal only saturated anti-alias hugging colored art, not pale backdrop fringe.
        opaque |= (
            colored
            & (delta >= 28)
            & ~exterior_matte
            & (dist_shell <= 2)
            & (delta < aa_delta)
        )

    return opaque


def clear_image_border_near_white(
    data: np.ndarray,
    border_width: int = 10,
    keep_opaque: np.ndarray | None = None,
) -> None:
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
    to_clear = border & near_white
    if keep_opaque is not None:
        to_clear &= ~keep_opaque
    data[to_clear, 3] = 0


def clean_border_fringe(data: np.ndarray, depth: int = 3) -> None:
    """Touch only pixels adjacent to transparent exterior. Never clear interior art."""
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


def spider_leg_gap_mask(source_rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Split enclosed matte into body glare (opaque white) vs between-leg gaps."""
    exterior_matte = is_exterior_matte(source_rgb)
    exterior = flood_exterior_from_edges(exterior_matte)
    enclosed = exterior_matte & ~exterior

    subject = subject_colored_mask(source_rgb)
    ys, xs = np.where(subject)
    if ys.size == 0:
        return enclosed, np.zeros_like(enclosed)

    sub_height = max(int(ys.max()) - int(ys.min()), 1)
    sub_width = max(int(xs.max()) - int(xs.min()), 1)

    labeled, component_count = ndimage.label(enclosed)
    glare = np.zeros(enclosed.shape, dtype=bool)
    leg_gap = np.zeros(enclosed.shape, dtype=bool)
    for label in range(1, component_count + 1):
        component = labeled == label
        component_ys, component_xs = np.where(component)
        rel_y = (float(component_ys.mean()) - ys.min()) / sub_height
        rel_x = (float(component_xs.mean()) - xs.min()) / sub_width
        center_offset = abs(rel_x - 0.5)
        is_leg_gap = (
            rel_y >= 0.50
            or (rel_y >= 0.32 and center_offset > 0.28)
            or (rel_y >= 0.22 and center_offset > 0.32)
            or (rel_y >= 0.40 and center_offset < 0.12)
            or (rel_y >= 0.26 and center_offset > 0.24)
        )
        if is_leg_gap:
            leg_gap |= component
        else:
            glare |= component

    return leg_gap, dilate(glare, 1)


def spider_glare_mask(source_rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Leg gaps plus all glare regions that should be painted solid white."""
    leg_gap, enclosed_glare = spider_leg_gap_mask(source_rgb)

    colored = all_colored_mask(source_rgb)
    shell = subject_shell_mask(source_rgb)
    maximum = source_rgb.max(axis=2)
    minimum = source_rgb.min(axis=2)
    delta = maximum - minimum
    exterior_matte = is_exterior_matte(source_rgb)
    subject = subject_colored_mask(source_rgb)

    ys, xs = np.where(subject)
    sub_height = max(int(ys.max()) - int(ys.min()), 1)
    y_grid = np.arange(source_rgb.shape[0])[:, None]
    head_band = y_grid < (ys.min() + 0.20 * sub_height)
    dist_colored = distance_transform_edt(~colored)
    head_exterior_glare = (
        exterior_matte
        & shell
        & head_band
        & ~leg_gap
        & (minimum >= 180)
        & (delta < 30)
        & (dist_colored <= 6)
    )

    return leg_gap, enclosed_glare | head_exterior_glare


def silhouette_keep_mask(source_rgb: np.ndarray) -> np.ndarray:
    """Pixels that may stay opaque on the exterior silhouette."""
    maximum = source_rgb.max(axis=2)
    minimum = source_rgb.min(axis=2)
    delta = maximum - minimum
    outline = maximum < 90
    colored = all_colored_mask(source_rgb)
    exterior_matte = is_exterior_matte(source_rgb)
    return outline | (colored & ~exterior_matte & (delta >= 42))


def silhouette_fringe_mask(data: np.ndarray, *, margin: int = 3) -> np.ndarray:
    """Exterior silhouette band on the prepared/cropped image."""
    transparent = data[:, :, 3] == 0
    opaque = data[:, :, 3] > 0
    exterior_transparent = flood_mask_from_edges(transparent)
    silhouette_transparent = exterior_transparent & dilate(opaque, 2)
    return dilate(silhouette_transparent, margin)


def scrub_silhouette_edge(
    data: np.ndarray,
    source_rgb: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
    preserve_opaque: np.ndarray | None = None,
    depths: tuple[int, ...] = (8, 6, 4, 2, 1),
) -> None:
    """Strip edge-connected matte and pale anti-alias hugging the silhouette."""
    exterior_matte = is_exterior_matte(source_rgb)
    edge_matte = exterior_matte & flood_exterior_from_edges(exterior_matte)
    keep_edge = silhouette_keep_mask(source_rgb)
    protected = (
        preserve_opaque.copy()
        if preserve_opaque is not None
        else np.zeros(data.shape[:2], dtype=bool)
    )
    for depth in depths:
        alpha = data[:, :, 3]
        transparent = alpha == 0
        if preserve_transparent is not None:
            outside_transparent = transparent | preserve_transparent
        else:
            outside_transparent = transparent
        border = dilate(outside_transparent, depth) & ~transparent & (alpha > 0)

        rgb = data[:, :, :3].astype(np.int16)
        maximum = rgb.max(axis=2)
        delta = maximum - rgb.min(axis=2)
        pure_white = (
            (data[:, :, 0] == 255)
            & (data[:, :, 1] == 255)
            & (data[:, :, 2] == 255)
        )
        peel = border & ~keep_edge
        peel |= border & edge_matte
        peel |= border & pure_white
        peel |= border & (maximum >= 185) & (delta < 48)
        peel &= ~protected
        if preserve_transparent is not None:
            peel &= ~preserve_transparent
        data[peel, 3] = 0


def solidify_subject(
    data: np.ndarray,
    source_rgb: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
) -> None:
    """Keep the subject shell opaque; backdrop matte and leg gaps stay transparent."""
    exterior_matte = is_exterior_matte(source_rgb)
    exterior = flood_exterior_from_edges(exterior_matte)
    shell = subject_shell_mask(source_rgb)
    interior = interior_art_mask(source_rgb)
    body = (shell | interior) & ~exterior_matte
    if preserve_transparent is not None:
        body &= ~preserve_transparent

    data[body, 3] = 255
    if preserve_transparent is not None:
        data[preserve_transparent, 3] = 0
    data[exterior & ~shell, 3] = 0


def interior_matte_fill_mask(
    source_rgb: np.ndarray,
    data: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
    *,
    skip_near_silhouette: bool = True,
) -> np.ndarray:
    """Enclosed matte holes that should be solid white, never silhouette fringe."""
    exterior_matte = is_exterior_matte(source_rgb)
    exterior = flood_exterior_from_edges(exterior_matte)
    edge_matte = exterior_matte & exterior
    enclosed = exterior_matte & ~exterior
    shell = subject_shell_mask(source_rgb)

    fill = np.zeros(enclosed.shape, dtype=bool)
    labeled, component_count = ndimage.label(enclosed)
    for label in range(1, component_count + 1):
        component = labeled == label
        if not (dilate(component, 2) & edge_matte).any():
            fill |= component

    fill &= shell
    if skip_near_silhouette:
        transparent = data[:, :, 3] == 0
        opaque_shell = (data[:, :, 3] > 0) & shell
        exterior_transparent = flood_mask_from_edges(transparent)
        silhouette_transparent = exterior_transparent & dilate(opaque_shell, 2)
        near_silhouette = dilate(silhouette_transparent, 4)
        fill &= ~near_silhouette
    if preserve_transparent is not None:
        fill &= ~preserve_transparent
    return fill


def fill_interior_matte(
    data: np.ndarray,
    source_rgb: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
    *,
    only_transparent: bool = False,
    skip_near_silhouette: bool = True,
) -> None:
    fill = interior_matte_fill_mask(
        source_rgb,
        data,
        preserve_transparent,
        skip_near_silhouette=skip_near_silhouette,
    )
    if only_transparent:
        fill &= data[:, :, 3] == 0
    data[fill, 0] = 255
    data[fill, 1] = 255
    data[fill, 2] = 255
    data[fill, 3] = 255
    if preserve_transparent is not None:
        data[preserve_transparent, 3] = 0


def deep_interior_fill_mask(
    source_rgb: np.ndarray,
    data: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
    *,
    min_component_exterior_distance: float = 88.0,
) -> np.ndarray:
    """Fillable matte components far from the cropped exterior silhouette."""
    fillable = interior_matte_fill_mask(
        source_rgb,
        data,
        preserve_transparent,
        skip_near_silhouette=False,
    )
    fillable &= data[:, :, 3] == 0
    if not fillable.any():
        return fillable

    transparent = data[:, :, 3] == 0
    exterior_transparent = flood_mask_from_edges(transparent)
    dist_exterior = distance_transform_edt(~exterior_transparent)

    fill = np.zeros(fillable.shape, dtype=bool)
    labeled, component_count = ndimage.label(fillable)
    for label in range(1, component_count + 1):
        component = labeled == label
        if float(dist_exterior[component].mean()) >= min_component_exterior_distance:
            fill |= component
    return fill


def fill_remaining_interior_matte(
    data: np.ndarray,
    source_rgb: np.ndarray,
    preserve_transparent: np.ndarray | None = None,
) -> np.ndarray:
    """Fill deep enclosed matte holes after crop without repainting the silhouette."""
    fill = deep_interior_fill_mask(source_rgb, data, preserve_transparent)
    data[fill, 0] = 255
    data[fill, 1] = 255
    data[fill, 2] = 255
    data[fill, 3] = 255
    if preserve_transparent is not None:
        data[preserve_transparent, 3] = 0
    return fill


def fill_spider_glare(data: np.ndarray, source_rgb: np.ndarray) -> None:
    """Paint spider glare solid white after matte fringe cleanup."""
    leg_gap, glare = spider_glare_mask(source_rgb)
    _, enclosed_glare = spider_leg_gap_mask(source_rgb)
    transparent = data[:, :, 3] == 0
    exterior_touch = dilate(transparent & ~leg_gap, 1) & ~transparent
    head_exterior = glare & ~enclosed_glare
    safe_glare = enclosed_glare | (head_exterior & ~exterior_touch)

    data[safe_glare, 3] = 255
    data[safe_glare, 0] = 255
    data[safe_glare, 1] = 255
    data[safe_glare, 2] = 255
    data[leg_gap, 3] = 0


def seal_subject_interior(data: np.ndarray, source_rgb: np.ndarray) -> None:
    """Restore saturated enclosed interior highlights cleared by border cleanup."""
    interior = interior_art_mask(source_rgb) & ~is_exterior_matte(source_rgb)
    transparent = data[:, :, 3] == 0
    exterior_transparent = flood_mask_from_edges(transparent)
    enclosed_transparent = transparent & ~exterior_transparent
    maximum = source_rgb.max(axis=2)
    delta = maximum - source_rgb.min(axis=2)
    colored = all_colored_mask(source_rgb) & (delta >= 50)
    cleared = interior & enclosed_transparent & colored
    data[cleared, 3] = 255
    blacked = (
        cleared
        & (data[:, :, 0] == 0)
        & (data[:, :, 1] == 0)
        & (data[:, :, 2] <= 20)
    )
    data[blacked, :3] = source_rgb[blacked]


def build_rgba(image: Image.Image, art_name: str = "") -> np.ndarray:
    rgb = np.array(image.convert("RGB"))
    if art_name == "fish_bones":
        opaque = build_opaque_mask_fish_bones(rgb)
        rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
        rgba[:, :, :3] = rgb
        rgba[:, :, 3] = np.where(opaque, 255, 0).astype(np.uint8)
        clean_strict_backdrop_fringe(rgba, rgb)
        return rgba

    opaque = build_opaque_mask(rgb)

    rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(opaque, 255, 0).astype(np.uint8)

    leg_gap: np.ndarray | None = None
    if art_name == "spider":
        leg_gap, _ = spider_leg_gap_mask(rgb)

    clear_image_border_near_white(rgba, keep_opaque=opaque)
    solidify_subject(rgba, rgb, preserve_transparent=leg_gap)
    scrub_silhouette_edge(rgba, rgb, preserve_transparent=leg_gap)
    fill_interior_matte(rgba, rgb, preserve_transparent=leg_gap)
    if art_name == "spider":
        fill_spider_glare(rgba, rgb)
    scrub_silhouette_edge(rgba, rgb, preserve_transparent=leg_gap)
    seal_subject_interior(rgba, rgb)
    return rgba


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


def crop_to_subject_bounds(
    data: np.ndarray,
    source_rgb: np.ndarray,
    padding: int = 6,
) -> np.ndarray:
    """Tight crop around the colored subject, ignoring distant edge fringe."""
    subject = subject_colored_mask(source_rgb)
    ys, xs = np.where(subject)
    if ys.size == 0:
        return crop_to_opaque_bounds(data, padding)

    y0 = max(0, int(ys.min()) - padding)
    y1 = min(data.shape[0], int(ys.max()) + padding + 1)
    x0 = max(0, int(xs.min()) - padding)
    x1 = min(data.shape[1], int(xs.max()) + padding + 1)
    return data[y0:y1, x0:x1].copy()


def ensure_ingredient_import_settings(output: Path) -> None:
    """Godot's fix_alpha_border rewrites alpha and breaks ingredient art."""
    import_path = output.with_suffix(output.suffix + ".import")
    if not import_path.exists():
        return
    text = import_path.read_text(encoding="utf-8")
    text = text.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
    text = text.replace("process/premult_alpha=true", "process/premult_alpha=false")
    if "compress/mode=" in text:
        text = re.sub(r"compress/mode=\d+", "compress/mode=0", text)
    import_path.write_text(text, encoding="utf-8")


def prepare_ingredient_art(source: Path, output: Path, import_godot: bool = True) -> Path:
    if not source.exists():
        raise FileNotFoundError(source)

    output.parent.mkdir(parents=True, exist_ok=True)
    source_rgb = np.array(Image.open(source).convert("RGB"))
    art_name = output.stem
    full_rgba = build_rgba(Image.fromarray(source_rgb, "RGB"), art_name=art_name)
    data = crop_to_subject_bounds(full_rgba, source_rgb)
    cropped_rgb = _crop_rgb(source_rgb, data.shape[:2])
    leg_gap: np.ndarray | None = None
    spider_glare: np.ndarray | None = None
    if art_name == "fish_bones":
        clean_strict_backdrop_fringe(data, cropped_rgb)
    elif art_name == "spider":
        leg_gap, _ = spider_leg_gap_mask(cropped_rgb)
        _, spider_glare = spider_glare_mask(cropped_rgb)
        scrub_silhouette_edge(
            data,
            cropped_rgb,
            preserve_transparent=leg_gap,
            preserve_opaque=spider_glare,
            depths=(3, 2, 1),
        )
        fill_interior_matte(
            data,
            cropped_rgb,
            preserve_transparent=leg_gap,
            only_transparent=True,
            skip_near_silhouette=False,
        )
        fill_spider_glare(data, cropped_rgb)
    else:
        scrub_silhouette_edge(
            data,
            cropped_rgb,
            preserve_transparent=leg_gap,
            preserve_opaque=spider_glare,
            depths=(3, 2, 1),
        )
        fill_interior_matte(
            data,
            cropped_rgb,
            preserve_transparent=leg_gap,
            only_transparent=True,
            skip_near_silhouette=False,
        )
    Image.fromarray(data, "RGBA").save(output)
    ensure_ingredient_import_settings(output)

    opaque_ratio = (data[:, :, 3] > 0).mean() * 100.0
    interior_holes = _interior_hole_count(
        data,
        cropped_rgb,
        art_name=art_name,
    )
    print(
        f"Prepared {output.relative_to(ROOT)} from {source.name} "
        f"({data.shape[1]}x{data.shape[0]}, opaque={opaque_ratio:.1f}%, "
        f"interior_holes={interior_holes})"
    )
    if interior_holes > 0:
        print(
            "WARNING: transparent pixels remain inside the subject interior. "
            "Check the source image or outline gaps."
        )

    if import_godot and GODOT_EXE.exists():
        subprocess.run(
            [str(GODOT_EXE), "--path", str(ROOT), "--import"],
            check=False,
            capture_output=True,
            text=True,
        )
        print("Godot import triggered.")
    elif import_godot:
        print("Godot executable not found; re-import assets in the editor.")

    return output


def _crop_rgb(source_rgb: np.ndarray, cropped_shape: tuple[int, int], padding: int = 6) -> np.ndarray:
    subject = subject_colored_mask(source_rgb)
    ys, xs = np.where(subject)
    if ys.size == 0:
        return source_rgb[: cropped_shape[0], : cropped_shape[1]]
    y0 = max(0, int(ys.min()) - padding)
    y1 = min(source_rgb.shape[0], int(ys.max()) + padding + 1)
    x0 = max(0, int(xs.min()) - padding)
    x1 = min(source_rgb.shape[1], int(xs.max()) + padding + 1)
    cropped = source_rgb[y0:y1, x0:x1]
    if cropped.shape[0] != cropped_shape[0] or cropped.shape[1] != cropped_shape[1]:
        return cropped[: cropped_shape[0], : cropped_shape[1]]
    return cropped


def _interior_hole_count(
    data: np.ndarray,
    source_rgb: np.ndarray,
    art_name: str = "",
) -> int:
    fill_all = interior_matte_fill_mask(
        source_rgb, data, skip_near_silhouette=False
    )
    holes = (
        fill_all
        & (data[:, :, 3] == 0)
        & ~silhouette_fringe_mask(data)
    )
    if art_name == "spider":
        leg_gap, _ = spider_leg_gap_mask(source_rgb)
        holes &= ~leg_gap
    return int(holes.sum())


def repair_known_ingredients(import_godot: bool = True) -> int:
    for art_name, source in KNOWN_SOURCES.items():
        output = INGREDIENTS_DIR / f"{art_name}.png"
        if not source.exists():
            print(f"Missing source for {art_name}: {source}")
            return 1
        prepare_ingredient_art(source, output, import_godot=False)
    if import_godot and GODOT_EXE.exists():
        subprocess.run(
            [str(GODOT_EXE), "--path", str(ROOT), "--import"],
            check=False,
            capture_output=True,
            text=True,
        )
        print("Godot import triggered.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, help="User-supplied image.")
    parser.add_argument(
        "art_name",
        nargs="?",
        help="Ingredient art filename without extension (e.g. chili_pepper).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        help="Explicit output path. Overrides art_name.",
    )
    parser.add_argument(
        "--no-import",
        action="store_true",
        help="Skip automatic Godot import.",
    )
    parser.add_argument(
        "--repair-all",
        action="store_true",
        help="Reprocess bundled recent ingredient art from known sources.",
    )
    args = parser.parse_args()

    if args.repair_all:
        return repair_known_ingredients(import_godot=not args.no_import)

    if args.source is None:
        parser.error("Provide source image or --repair-all.")
    if args.out is None and not args.art_name:
        parser.error("Provide art_name or --out.")
    output = args.out or (INGREDIENTS_DIR / f"{args.art_name}.png")
    prepare_ingredient_art(args.source, output, import_godot=not args.no_import)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
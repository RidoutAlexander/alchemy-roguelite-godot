"""Prepare the shop reroll dice button from a checkerboard-backed source image."""
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
    / "image-4d52ac50-9a63-4258-8b7d-be7ce44f742b.jpg"
)
OUT = ROOT / "assets/sprites/shop_reroll_button.png"


def is_checkerboard_exterior_pixel(rgb: tuple[int, int, int]) -> bool:
	minimum = min(rgb)
	maximum = max(rgb)
	return (maximum - minimum) < 28 and minimum >= 155


def flood_exterior_mask(rgb: np.ndarray, predicate) -> np.ndarray:
	height, width = rgb.shape[:2]
	exterior = np.zeros((height, width), dtype=bool)
	queue: deque[tuple[int, int]] = deque()

	def try_seed(y: int, x: int) -> None:
		if not exterior[y, x] and predicate(tuple(rgb[y, x])):
			exterior[y, x] = True
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
				and not exterior[ny, nx]
				and predicate(tuple(rgb[ny, nx]))
			):
				exterior[ny, nx] = True
				queue.append((ny, nx))
	return exterior


def prepare(src: Path, out: Path) -> None:
	image = Image.open(src).convert("RGB")
	rgb = np.array(image)
	exterior = flood_exterior_mask(rgb, is_checkerboard_exterior_pixel)

	rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
	rgba[:, :, :3] = rgb
	rgba[:, :, 3] = np.where(exterior, 0, 255).astype(np.uint8)

	out.parent.mkdir(parents=True, exist_ok=True)
	Image.fromarray(rgba, "RGBA").save(out)

	opaque = int((rgba[:, :, 3] > 0).sum())
	transparent = int((rgba[:, :, 3] == 0).sum())
	print(
		f"Saved {out.relative_to(ROOT)}: opaque={opaque}, transparent={transparent}, "
		f"corners={[int(rgba[0, 0, 3]), int(rgba[0, -1, 3]), int(rgba[-1, 0, 3])]}"
	)


def main() -> int:
	src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
	out = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
	if not src.exists():
		print(f"Missing source image: {src}")
		return 1
	prepare(src, out)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
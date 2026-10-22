"""Derive the ELYTRIVA mark-only asset (no navy tile) for the splash.

The shipped brand PNG is a rounded-square navy TILE (designed for the
launcher icon and for use on light surfaces). Inside the app's navy canvas
the tile edge is visible and the mark reads as a picture pasted onto the
scanner artwork.

This generator extracts the artwork only: it keeps the bright brand
colours (cyan / teal / orange) and makes the dark navy tile transparent,
so the mark can sit directly on the scanner canvas and share its surface.

Deterministic and reproducible:  venv\\Scripts\\python.exe tool\\generate_brand_mark.py
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE = REPO_ROOT / "ELYTRIVA_Brand_Kit_Flutter" / "flutter_assets" / "elytriva_icon_512.png"
TARGET = REPO_ROOT / "flutter_app" / "assets" / "branding" / "elytriva_mark.png"

# The tile navy is near-black with a blue cast; the artwork is saturated and
# bright. Keeping any pixel whose brightest channel is above this threshold
# keeps the whole artwork (cyan/teal/orange) and drops the tile.
ARTWORK_MIN_CHANNEL = 60


def main() -> int:
    if not SOURCE.exists():
        print(f"source asset missing: {SOURCE}")
        return 1

    image = Image.open(SOURCE).convert("RGBA")
    pixels = image.load()
    kept = 0
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if max(r, g, b) >= ARTWORK_MIN_CHANNEL:
                kept += 1
                continue
            # Tile pixel -> fully transparent.
            pixels[x, y] = (r, g, b, 0)

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    image.save(TARGET)
    print(f"wrote {TARGET} ({image.width}x{image.height}, {kept} artwork pixels kept)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

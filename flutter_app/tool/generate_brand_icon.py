"""Generates the Drishti-AI launcher icon (retinal-eye brand mark).

Outputs ONLY the two source PNGs consumed by flutter_launcher_icons:
  assets/branding/drishti_icon.png            1024x1024 full-bleed icon
  assets/branding/drishti_icon_foreground.png 1024x1024 adaptive foreground
                                              (eye art inset to the 66% safe zone)

Art follows the app's brand mark (neon_nav_rail / splash):
  dark slate background, cyan glow ring, lighter cyan iris + white pupil,
  retina highlight. No text (readability at 48px)."""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BG = (2, 6, 23)  # #020617 slate-950
RING = (6, 182, 212)  # #06B6D4 cyan-500 (neonCyan)
GLOW = (8, 145, 178)  # cyan-600 (primaryCyan)
WHITE = (240, 253, 255)

OUT_DIR = os.path.join("assets", "branding")


def radial_gradient(size: int, inner, outer) -> Image.Image:
    """Smooth radial ramp as an RGB mask-driven gradient."""
    grad = Image.new("RGB", (size, size), outer)
    small = 256
    ramp = Image.new("L", (small, small))
    px = ramp.load()
    cx = (small - 1) / 2
    cy = (small - 1) / 2
    max_r = (small**2 / 2) ** 0.5
    for y in range(small):
        for x in range(small):
            d = min(1.0, (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / max_r)
            px[x, y] = int(255 * (1 - d))
    ramp = ramp.resize((size, size), Image.BILINEAR)
    outer_img = Image.new("RGB", (size, size), outer)
    inner_img = Image.new("RGB", (size, size), inner)
    return Image.composite(inner_img, outer_img, ramp)


def eye_layer(canvas: Image.Image, scale: float) -> Image.Image:
    """Draws the brand eye centered on `canvas` with parameters scaled."""
    d = ImageDraw.Draw(canvas)
    cx = cy = SIZE / 2

    # Outer glow halo (soft, eased falloff).
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse(
        [cx - 360 * scale, cy - 360 * scale, cx + 360 * scale, cy + 360 * scale],
        fill=RING + (56,),
    )
    halo = halo.filter(ImageFilter.GaussianBlur(90))
    canvas.alpha_composite(halo)

    # Retina ring: crisp cyan annulus.
    d.ellipse(
        [cx - 310 * scale, cy - 310 * scale, cx + 310 * scale, cy + 310 * scale],
        outline=RING + (235,),
        width=52,
    )

    # Iris: filled disc in cyan with a vertical highlight arc.
    d.ellipse(
        [cx - 205 * scale, cy - 205 * scale, cx + 205 * scale, cy + 205 * scale],
        fill=(8, 110, 138, 255),
        outline=GLOW + (255,),
        width=10,
    )
    # Highlight: small white arc upper-left of the iris.
    d.arc(
        [
            cx - 150 * scale,
            cy - 150 * scale,
            cx + 150 * scale,
            cy + 150 * scale,
        ],
        start=200,
        end=250,
        fill=(255, 255, 255, 190),
        width=26,
    )

    # Pupil: white core with dark center bloom (reads as "vision").
    d.ellipse(
        [cx - 62 * scale, cy - 62 * scale, cx + 62 * scale, cy + 62 * scale],
        fill=WHITE + (255,),
    )
    d.ellipse(
        [cx - 34 * scale, cy - 34 * scale, cx + 34 * scale, cy + 34 * scale],
        fill=BG + (255,),
    )
    return canvas


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    # 1. Full-bleed 1024 icon: subtle radial background + eye mark.
    full = radial_gradient(SIZE, (10, 39, 61), BG).convert("RGBA")
    full = eye_layer(full, 1.0)
    full.convert("RGB").save(os.path.join(OUT_DIR, "drishti_icon.png"))

    # 2. Adaptive foreground: eye art INSET to the 66% safe zone on a fully
    #    transparent canvas (system masks into any shape without clipping art).
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # The adaptive layer is scaled up ~1.5x by the system egg, so the art
    # itself must occupy the inner 0.66*0.66 window to stay unclipped.
    fg = eye_layer(fg, 0.6)
    fg.save(os.path.join(OUT_DIR, "drishti_icon_foreground.png"))

    print("written:", OUT_DIR)


if __name__ == "__main__":
    main()

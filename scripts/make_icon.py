#!/usr/bin/env python3
"""
Generate Solo Lock's 1024x1024 App Icon.

Heavy brass padlock on the vault-gray palette from UI.md. No alpha channel,
no rounded corners (Apple applies the squircle mask automatically).

Output: SoloLock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# Palette (UI.md)
VAULT      = (0x22, 0x27, 0x2B)
VAULT_DEEP = (0x14, 0x17, 0x1A)
BRASS      = (0xB5, 0x92, 0x52)
BRASS_HI   = (0xC9, 0xA6, 0x69)
BRASS_LO   = (0x9A, 0x7A, 0x41)
KEYHOLE    = (0x14, 0x17, 0x1A)


def make_icon() -> Image.Image:
    # Smooth radial vignette painted as a separate image, blurred, then composited.
    img = Image.new("RGB", (SIZE, SIZE), VAULT)
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    cx, cy = SIZE // 2, SIZE // 2
    max_r = SIZE // 2
    for r in range(max_r, 0, -8):
        # Darker toward edges, transparent at center.
        t = r / max_r
        alpha = int(170 * (t ** 2.2))
        vd.ellipse((cx - r, cy - r, cx + r, cy + r),
                   fill=(*VAULT_DEEP, alpha))
    vignette = vignette.filter(ImageFilter.GaussianBlur(40))
    img.paste(vignette, (0, 0), vignette)

    draw = ImageDraw.Draw(img, "RGBA")

    # Geometry of the lock — the body fills roughly the lower 60% of the icon,
    # the shackle rises above. Centred horizontally.
    body_w = int(SIZE * 0.62)
    body_h = int(SIZE * 0.46)
    body_x = (SIZE - body_w) // 2
    body_y = int(SIZE * 0.42)
    body_r = int(body_h * 0.18)

    shackle_outer_w = int(body_w * 0.62)
    shackle_outer_h = int(SIZE * 0.36)
    shackle_thickness = int(body_h * 0.16)
    shackle_x = (SIZE - shackle_outer_w) // 2
    shackle_y = int(SIZE * 0.18)

    # --- Shackle (drawn before body so the body overlaps the legs cleanly) ---
    # Outer arc + legs as a single thick rounded path: draw an outer rounded
    # rect, then mask the lower middle to leave a U-shape.
    shackle_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shackle_layer)
    # Outer rounded rect
    sd.rounded_rectangle(
        (shackle_x, shackle_y,
         shackle_x + shackle_outer_w, shackle_y + shackle_outer_h),
        radius=shackle_outer_w // 2,
        fill=BRASS,
    )
    # Knock out the inner U so it becomes a hoop.
    inner_w = shackle_outer_w - 2 * shackle_thickness
    inner_x = shackle_x + shackle_thickness
    sd.rounded_rectangle(
        (inner_x, shackle_y + shackle_thickness,
         inner_x + inner_w, shackle_y + shackle_outer_h + shackle_thickness),
        radius=inner_w // 2,
        fill=(0, 0, 0, 0),
    )
    # Add a subtle highlight along the upper-left of the shackle for depth.
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.rounded_rectangle(
        (shackle_x + 8, shackle_y + 8,
         shackle_x + shackle_outer_w - 8, shackle_y + shackle_outer_h - 8),
        radius=(shackle_outer_w - 16) // 2,
        outline=BRASS_HI, width=int(shackle_thickness * 0.18),
    )
    shackle_layer = Image.alpha_composite(shackle_layer, highlight)
    img.paste(shackle_layer, (0, 0), shackle_layer)

    # --- Body ---
    # Drop shadow underneath the body.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shd = ImageDraw.Draw(shadow)
    shd.rounded_rectangle(
        (body_x - 6, body_y + 18, body_x + body_w + 6, body_y + body_h + 28),
        radius=body_r, fill=(0, 0, 0, 140),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))
    img.paste(shadow, (0, 0), shadow)

    # Vertical brass gradient on the body for depth.
    body_layer = Image.new("RGBA", (body_w, body_h), BRASS)
    grd = ImageDraw.Draw(body_layer)
    for y in range(body_h):
        t = y / body_h
        r = int(BRASS_HI[0] * (1 - t) + BRASS_LO[0] * t)
        g = int(BRASS_HI[1] * (1 - t) + BRASS_LO[1] * t)
        b = int(BRASS_HI[2] * (1 - t) + BRASS_LO[2] * t)
        grd.line([(0, y), (body_w, y)], fill=(r, g, b))
    # Mask to rounded rect
    mask = Image.new("L", (body_w, body_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, body_w, body_h), radius=body_r, fill=255)
    img.paste(body_layer, (body_x, body_y), mask)

    # Keyhole — circle + slot.
    kh_radius = int(body_h * 0.13)
    kh_cx = SIZE // 2
    kh_cy = body_y + int(body_h * 0.42)
    draw.ellipse(
        (kh_cx - kh_radius, kh_cy - kh_radius,
         kh_cx + kh_radius, kh_cy + kh_radius),
        fill=KEYHOLE,
    )
    slot_w = int(kh_radius * 0.55)
    slot_h = int(kh_radius * 1.5)
    draw.rectangle(
        (kh_cx - slot_w // 2, kh_cy,
         kh_cx + slot_w // 2, kh_cy + slot_h),
        fill=KEYHOLE,
    )

    return img


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..",
                       "SoloLock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
    out = os.path.abspath(out)
    icon = make_icon()
    # Save WITHOUT alpha channel — Apple rejects icons with transparency.
    icon.convert("RGB").save(out, "PNG", optimize=True)
    print(f"  ✓ {out}  ({icon.size[0]}×{icon.size[1]})")


if __name__ == "__main__":
    main()

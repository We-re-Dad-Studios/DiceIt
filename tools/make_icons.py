"""Generates the icon set and social thumbnail from the "Felt & Brass" tokens.

The mark is a locked die - gold body, dark pips - because that is the one
image the whole design hangs on: gold means money, and a locked die is money
you have kept. Full-bleed rather than a die sitting on a felt tile, so it
still reads at 16px in a browser tab.

Run from the repo root:  python tools/make_icons.py
"""

from PIL import Image, ImageDraw, ImageFont

# --- Felt & Brass tokens ---------------------------------------------------
GOLD = (216, 162, 58)
GOLD_LIGHT = (242, 206, 120)
PIP_DARK = (59, 42, 8)
FELT = (15, 34, 26)
PANEL = (23, 46, 37)
BORDER = (42, 70, 58)
INK = (242, 239, 230)

# Die geometry, as fractions of the body - matches DiceFace.gd (88px body,
# radius 16, border 3, pip 12, inset 13, gutter 5).
RADIUS_F = 16 / 88
BORDER_F = 3 / 88
PIP_F = 12 / 88
INSET_F = 13 / 88
GUTTER_F = 5 / 88

PIP_LAYOUT = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
}

SUPERSAMPLE = 8
FONT_DIR = "godot/assets/fonts"


BUST_BODY = (56, 19, 15)
BUST_LINE = (179, 55, 47)


def draw_die(size, face=5, body=GOLD, border=GOLD_LIGHT, pip=PIP_DARK,
             bleed=True, busted=False):
    """Renders a single die at `size` px, supersampled for clean edges."""
    if busted:
        body, border = BUST_BODY, BUST_LINE
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = 0 if bleed else s * 0.06
    box = (pad, pad, s - pad - 1, s - pad - 1)
    body_size = s - pad * 2

    draw.rounded_rectangle(
        box,
        radius=body_size * RADIUS_F,
        fill=body,
        outline=border,
        width=max(1, int(body_size * BORDER_F)),
    )

    inset = body_size * INSET_F
    gutter = body_size * GUTTER_F
    pip_d = body_size * PIP_F
    inner = body_size - inset * 2
    cell = (inner - gutter * 2) / 3
    first = pad + inset + cell / 2

    if busted:
        # Same cross as the in-game busted die: 6px stroke, 14px inset at 88.
        c = pad + body_size * (14 / 88)
        far = pad + body_size - body_size * (14 / 88)
        width = max(1, int(body_size * (6 / 88)))
        draw.line((c, c, far, far), fill=BUST_LINE, width=width)
        draw.line((far, c, c, far), fill=BUST_LINE, width=width)
        return img.resize((size, size), Image.LANCZOS)

    for index in PIP_LAYOUT[face]:
        col, row = index % 3, index // 3
        cx = first + col * (cell + gutter)
        cy = first + row * (cell + gutter)
        draw.ellipse(
            (cx - pip_d / 2, cy - pip_d / 2, cx + pip_d / 2, cy + pip_d / 2),
            fill=pip,
        )

    return img.resize((size, size), Image.LANCZOS)


def font(name, size):
    return ImageFont.truetype(f"{FONT_DIR}/{name}", size)


def spaced(text, gap=" "):
    return gap.join(text)


def make_social_card(path, width=1200, height=630):
    """Link preview card: the mark, the name, and what the game is."""
    img = Image.new("RGB", (width, height), FELT)
    draw = ImageDraw.Draw(img)

    # A panel edge, so the card reads as a card laid on the table.
    draw.rounded_rectangle((40, 40, width - 41, height - 41), radius=28,
                           fill=PANEL, outline=BORDER, width=2)

    die = draw_die(240, face=5)
    img.paste(die, (110, (height - 240) // 2), die)

    text_x = 410
    title = font("Archivo-800.ttf", 96)
    tagline = font("Archivo-500.ttf", 26)
    body = font("Archivo-400.ttf", 30)

    draw.text((text_x, 232), "Bank or Bust", font=title, fill=INK)
    draw.text((text_x, 200), spaced("PUSH YOUR LUCK"), font=tagline, fill=GOLD)
    draw.text((text_x, 356), "Multiplayer push-your-luck dice.", font=body, fill=(201, 214, 205))
    draw.text((text_x, 398), "No signup - just a room code.", font=body, fill=(143, 166, 154))

    # A short run of dice along the bottom, ending in a bust - the whole game
    # in one line.
    x = text_x
    for face, busted in ((3, False), (6, False), (1, True)):
        small = draw_die(56, face=face, busted=busted)
        img.paste(small, (x, 470), small)
        x += 68

    img.save(path)
    return path


def main():
    out = "build/web"
    master = draw_die(1024, face=5)
    master.save("godot/assets/icons/icon-1024.png")

    for size in (192, 512):
        draw_die(size, face=5).save(f"{out}/icon-{size}.png")
    draw_die(180, face=5).save(f"{out}/apple-touch-icon.png")

    # Multi-resolution .ico so Windows and older browsers pick their best fit.
    draw_die(256, face=5).save(
        f"{out}/favicon.ico",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    make_social_card(f"{out}/social-card.png")
    print("wrote icons + social card to", out)


if __name__ == "__main__":
    main()

"""Puts the label of a game on the blank SpiffBoy cartridge: writes the texture of the 3D model and the inventory icon of the cartridge, and on request the picture of the mod.

The blank cartridge comes with this tool, in tools/cartridge/: blank_texture.png, the texture of the cartridge model with an
empty label, and blank_front.png, the front of the cartridge seen straight on, from which the icon is made.

Usage:
    python cartridge_label.py <label.png> <texture.png> <icon.png> [<poster.png>]

The label is the colour picture of the game, 388x212 (any picture in the same proportions works; a picture in other
proportions is refused, nothing written). The texture goes to
media/textures/<Namespace>/<Namespace>Cartridge_<Id>.png, the name the model of the item script gives, and the icon to
media/textures/Item_<Module>_Cartridge_<Id>.png, the name the Icon line of the item script gives. The poster, when asked for, is
the cartridge wearing the label on a transparent square of 256x256: copy it as poster.png next to each mod.info of the mod and as
preview.png, the picture of its Workshop page.

Example:
    python cartridge_label.py ".../ui/MyMod/Games/SpaceRace/label.png"
        ".../textures/MyMod/MyModCartridge_SpaceRace.png" ".../textures/Item_MyMod_Cartridge_SpaceRace.png"
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter

BLANK = Path(__file__).resolve().parent / "cartridge"
TEXTURE_LABEL = (437, 456, 506, 507)
FRONT_LABEL = (43, 142, 595, 453)
ICON_SIZE = 64
POSTER_SIZE = 256
OUTLINE = (96, 62, 116, 255)
LABEL_SIZE = (388, 212)
PROPORTION_TOLERANCE = 0.02


def size_of(box):
    """Returns the width and height of a box given as left, top, right and bottom."""
    return box[2] - box[0], box[3] - box[1]


def framed(front, size):
    """Returns the front of the cartridge shrunk to fit a transparent square of the given size, centred, with a dark outline."""
    fit = size - 2
    shrunk = front.resize((fit, round(front.height * fit / front.width)), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = ((size - shrunk.width) // 2, (size - shrunk.height) // 2)
    mask = shrunk.getchannel("A").point(lambda a: 255 if a >= 128 else 0).filter(ImageFilter.MaxFilter(3))
    out.paste(Image.new("RGBA", shrunk.size, OUTLINE), origin, mask)
    out.alpha_composite(shrunk, origin)
    return out


def main():
    """Writes the texture and the icon of the cartridge wearing the given label, and its poster when a fourth path is given."""
    if len(sys.argv) not in (4, 5):
        print(__doc__, file=sys.stderr)
        return 1
    label_path, texture_path, icon_path = (Path(arg) for arg in sys.argv[1:4])
    picture = Image.open(label_path)
    expected = LABEL_SIZE[0] / LABEL_SIZE[1]
    if abs(picture.width / picture.height - expected) > expected * PROPORTION_TOLERANCE:
        print(f"cartridge_label: {label_path.name} is {picture.width}x{picture.height}; a label is {LABEL_SIZE[0]}x{LABEL_SIZE[1]} "
              f"or any picture in the same proportions, {expected:.2f} times as wide as high, so it is not stretched on the cartridge. "
              "Nothing written.", file=sys.stderr)
        return 1
    label = picture.convert("RGB").resize(size_of(TEXTURE_LABEL), Image.LANCZOS)
    texture = Image.open(BLANK / "blank_texture.png").convert("RGB")
    texture.paste(label, TEXTURE_LABEL[:2])
    front = Image.open(BLANK / "blank_front.png").convert("RGBA")
    front.paste(label.resize(size_of(FRONT_LABEL), Image.NEAREST), FRONT_LABEL[:2])
    texture_path.parent.mkdir(parents=True, exist_ok=True)
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    texture.save(texture_path, optimize=True)
    framed(front, ICON_SIZE).save(icon_path, optimize=True)
    print(f"written {texture_path} and {icon_path}")
    if len(sys.argv) == 5:
        poster_path = Path(sys.argv[4])
        poster_path.parent.mkdir(parents=True, exist_ok=True)
        framed(front, POSTER_SIZE).save(poster_path, optimize=True)
        print(f"written {poster_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

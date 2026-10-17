"""Puts the label of a game on the blank SpiffBoy cartridge: writes the texture of the 3D model and the inventory icon of the cartridge.

The blank cartridge comes with this tool, in tools/cartridge/: blank_texture.png, the texture of the cartridge model with an
empty label, and blank_front.png, the front of the cartridge seen straight on, from which the icon is made.

Usage:
    python cartridge_label.py <label.png> <texture.png> <icon.png>

The label is the colour picture of the game, 388x212 (any picture in the same proportions works). The texture goes to
media/textures/<Namespace>/<Namespace>Cartridge_<Id>.png, the name the model of the item script gives, and the icon to
media/textures/Item_<Module>_Cartridge_<Id>.png, the name the Icon line of the item script gives.

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
OUTLINE = (96, 62, 116, 255)


def size_of(box):
    """Returns the width and height of a box given as left, top, right and bottom."""
    return box[2] - box[0], box[3] - box[1]


def icon(front):
    """Returns the 64x64 inventory icon: the front of the cartridge shrunk to fit, centred, with a dark outline."""
    fit = ICON_SIZE - 2
    shrunk = front.resize((fit, round(front.height * fit / front.width)), Image.LANCZOS)
    out = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    origin = ((ICON_SIZE - shrunk.width) // 2, (ICON_SIZE - shrunk.height) // 2)
    mask = shrunk.getchannel("A").point(lambda a: 255 if a >= 128 else 0).filter(ImageFilter.MaxFilter(3))
    out.paste(Image.new("RGBA", shrunk.size, OUTLINE), origin, mask)
    out.alpha_composite(shrunk, origin)
    return out


def main():
    """Writes the texture and the icon of the cartridge wearing the given label."""
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 1
    label_path, texture_path, icon_path = (Path(arg) for arg in sys.argv[1:])
    label = Image.open(label_path).convert("RGB").resize(size_of(TEXTURE_LABEL), Image.LANCZOS)
    texture = Image.open(BLANK / "blank_texture.png").convert("RGB")
    texture.paste(label, TEXTURE_LABEL[:2])
    front = Image.open(BLANK / "blank_front.png").convert("RGBA")
    front.paste(label.resize(size_of(FRONT_LABEL), Image.NEAREST), FRONT_LABEL[:2])
    texture_path.parent.mkdir(parents=True, exist_ok=True)
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    texture.save(texture_path, optimize=True)
    icon(front).save(icon_path, optimize=True)
    print(f"written {texture_path} and {icon_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Turns pictures drawn for the SpiffBoy screen into a layered sheet for screen:layers and reports the draw calls each cell costs.

A layered sheet holds every cell side by side in one strip, repeated in four rows of the cell height, one row per shade of
the screen, darkest first, white where the cell has that shade and transparent elsewhere. The game draws cell n with
screen:layers(texture, n * width, width, height, x, y[, shades]): one draw call per shade drawn, four without a shades list.

The pictures are drawn in the four shades of SpiffBoy.Cartridges.SHADES, RGB 28,36,32 / 72,86,78 / 112,128,118 / 156,168,160,
on a transparent background. With --grey they are greyscale instead: grey 0-63 is shade 1, 64-127 shade 2, 128-191 shade 3
and 192-255 shade 4. Every pixel is either fully transparent or fully opaque; anything else is refused.

Usage:
    python shade_layers.py <picture> [<picture> ...] -o <sheet.png> [--cell WxH] [--grey]

Several pictures of the same cell height are laid side by side in the order given. With --cell, each picture is cut into
cells of W x H pixels, read left to right then top to bottom; without it, each picture is one cell.

Examples:
    python shade_layers.py hero.png -o media/ui/MyMod/Games/MyGame/hero_layers.png
    python shade_layers.py walk.png jump.png --cell 16x16 -o media/ui/MyMod/Games/MyGame/hero_layers.png
    python shade_layers.py tiles_grey.png --grey --cell 8x8 -o media/ui/MyMod/Games/MyGame/tiles_layers.png
"""

import argparse
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SHADES = np.array([(28, 36, 32), (72, 86, 78), (112, 128, 118), (156, 168, 160)], dtype=np.int32)
GREY_STEP = 64
CELL = re.compile(r"^(\d+)x(\d+)$")


class SheetError(Exception):
    """Reports a picture that cannot become a layered sheet."""


def shade_indexes(path, grey):
    """Returns the shade index of every pixel of a picture, 0 where it is transparent and 1 to 4 from darkest to lightest."""
    pixels = np.asarray(Image.open(path).convert("RGBA")).astype(np.int32)
    alpha = pixels[:, :, 3]
    partial = (alpha > 0) & (alpha < 255)
    if partial.any():
        y, x = np.argwhere(partial)[0]
        raise SheetError(f"{path}: {int(partial.sum())} half transparent pixels, the first at {x},{y}")
    opaque = alpha == 255
    rgb = pixels[:, :, :3]
    indexes = np.zeros(alpha.shape, dtype=np.int32)
    if grey:
        coloured = opaque & ((rgb[:, :, 0] != rgb[:, :, 1]) | (rgb[:, :, 1] != rgb[:, :, 2]))
        if coloured.any():
            y, x = np.argwhere(coloured)[0]
            raise SheetError(f"{path}: {int(coloured.sum())} pixels are not grey, the first at {x},{y}")
        indexes[opaque] = rgb[:, :, 0][opaque] // GREY_STEP + 1
        return indexes
    matches = np.all(rgb[:, :, None, :] == SHADES[None, None, :, :], axis=3)
    stray = opaque & ~matches.any(axis=2)
    if stray.any():
        y, x = np.argwhere(stray)[0]
        raise SheetError(f"{path}: {int(stray.sum())} pixels are not one of the four shades, the first at {x},{y} is {tuple(int(v) for v in rgb[y, x])}")
    indexes[opaque] = matches.argmax(axis=2)[opaque] + 1
    return indexes


def parse_cell(text):
    """Returns the width and height of a cell given as WxH."""
    match = CELL.match(text)
    if not match or int(match.group(1)) == 0 or int(match.group(2)) == 0:
        raise SheetError(f"--cell must be WxH with whole numbers above zero, not {text}")
    return int(match.group(1)), int(match.group(2))


def cut(indexes, path, cell):
    """Returns the cells of a picture, left to right then top to bottom, or the whole picture as one cell without a cell size."""
    if cell is None:
        return [indexes]
    width, height = cell
    rows, columns = indexes.shape
    if columns % width or rows % height:
        raise SheetError(f"{path}: {columns}x{rows} is not a whole number of {width}x{height} cells")
    return [indexes[top:top + height, left:left + width] for top in range(0, rows, height) for left in range(0, columns, width)]


def layered_sheet(cells):
    """Builds the layered sheet of cells of equal height: the cells side by side, one row of white masks per shade, darkest first."""
    height = cells[0].shape[0]
    strip = np.concatenate(cells, axis=1)
    sheet = np.zeros((height * len(SHADES), strip.shape[1], 4), dtype=np.uint8)
    for shade in range(len(SHADES)):
        sheet[shade * height:(shade + 1) * height][strip == shade + 1] = 255
    return Image.fromarray(sheet, "RGBA")


def report(cells):
    """Prints, for every cell, its left edge in the sheet, the shades it uses and the draw calls it costs."""
    left = 0
    for number, cell in enumerate(cells):
        used = [shade for shade in range(1, len(SHADES) + 1) if (cell == shade).any()]
        listed = "{ " + ", ".join(str(shade) for shade in used) + " }" if used else "none"
        print(f"cell {number:>3}  sx {left:>5}  {cell.shape[1]}x{cell.shape[0]}  shades {listed:<16} {len(used)} calls with that list, {len(SHADES)} without")
        left += cell.shape[1]


def main():
    """Reads the pictures, writes their layered sheet and prints the cost of every cell, or prints the first problem found."""
    parser = argparse.ArgumentParser(description="Builds a layered sheet for screen:layers from pictures in the four SpiffBoy shades.")
    parser.add_argument("pictures", nargs="+", type=Path)
    parser.add_argument("-o", "--output", required=True, type=Path)
    parser.add_argument("--cell", help="cut each picture into cells of WxH pixels")
    parser.add_argument("--grey", action="store_true", help="read greyscale pictures instead of pictures in the four shades")
    args = parser.parse_args()
    try:
        cell = parse_cell(args.cell) if args.cell else None
        cells = [piece for path in args.pictures for piece in cut(shade_indexes(path, args.grey), path, cell)]
        heights = sorted({piece.shape[0] for piece in cells})
        if len(heights) > 1:
            raise SheetError(f"the cells must share one height, found {', '.join(str(h) for h in heights)}")
    except (SheetError, OSError) as error:
        print(f"shade_layers: {error}", file=sys.stderr)
        return 1
    sheet = layered_sheet(cells)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, optimize=True)
    report(cells)
    print(f"{args.output}: {sheet.width}x{sheet.height}, {len(cells)} cells of height {heights[0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

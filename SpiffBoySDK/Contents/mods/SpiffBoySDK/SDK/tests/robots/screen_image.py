"""Turns the draw calls of one frame of the console screen into a PNG picture, as the game draws them: rectangles, whole pictures, cells of a sheet and turned pictures, each picture a mask painted in its colour.

The tests call image_size to give the pictures of a mod their real size, and render to write a frame; see tests/lib/test_console.lua.
"""

import math
from pathlib import Path

from PIL import Image

SCREEN_SIZE = (180, 120)
ZOOM = 4
BACKGROUND = (0, 0, 0, 255)

pictures = {}


def picture(file):
    """Returns the picture of a file as RGBA, read once."""
    if file not in pictures:
        pictures[file] = Image.open(file).convert("RGBA")
    return pictures[file]


def image_size(file):
    """Returns the width and height of the picture of a file."""
    image = picture(file)
    return image.width, image.height


def painted(image, r, g, b, a):
    """Returns a picture painted in a colour: the colour where the picture is white, its opacity times the given one."""
    red, green, blue, alpha = image.split()
    red = red.point(lambda v: round(v * r))
    green = green.point(lambda v: round(v * g))
    blue = blue.point(lambda v: round(v * b))
    alpha = alpha.point(lambda v: round(v * a))
    return Image.merge("RGBA", (red, green, blue, alpha))


def place(canvas, image, x, y):
    """Paints a picture on the canvas with its top left corner at the given point, cut at the edges."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(image, (round(x), round(y)))
    canvas.alpha_composite(layer)


def sized(image, width, height):
    """Returns a picture stretched to the given size with hard pixel edges, at least one pixel each way."""
    return image.resize((max(1, round(width)), max(1, round(height))), Image.NEAREST)


def draw(canvas, call):
    """Paints one draw call on the canvas."""
    kind = call[0]
    if kind == "R":
        _, x, y, w, h, a, r, g, b = call
        place(canvas, Image.new("RGBA", (max(1, round(w)), max(1, round(h))), (round(r * 255), round(g * 255), round(b * 255), round(a * 255))), x, y)
    elif kind == "T":
        _, file, x, y, w, h, a, r, g, b = call
        place(canvas, painted(sized(picture(file), w, h), r, g, b, a), x, y)
    elif kind == "S":
        _, file, sx, sy, sw, sh, x, y, w, h, a, r, g, b = call
        cell = picture(file).crop((round(sx), round(sy), round(sx + sw), round(sy + sh)))
        place(canvas, painted(sized(cell, w, h), r, g, b, a), x, y)
    elif kind == "P":
        _, file, x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a = call
        width = math.hypot(x2 - x1, y2 - y1)
        height = math.hypot(x4 - x1, y4 - y1)
        degrees = math.degrees(math.atan2(y2 - y1, x2 - x1))
        turned = painted(sized(picture(file), width, height), r, g, b, a).rotate(-degrees, resample=Image.NEAREST, expand=True)
        centre_x, centre_y = (x1 + x2 + x3 + x4) / 4, (y1 + y2 + y3 + y4) / 4
        place(canvas, turned, centre_x - turned.width / 2, centre_y - turned.height / 2)


def render(calls, out):
    """Writes the draw calls of one frame as a PNG picture of the screen, four times its size so the pixels show."""
    canvas = Image.new("RGBA", SCREEN_SIZE, BACKGROUND)
    for call in calls:
        draw(canvas, call)
    target = Path(out)
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.resize((SCREEN_SIZE[0] * ZOOM, SCREEN_SIZE[1] * ZOOM), Image.NEAREST).save(target)
    return str(target)

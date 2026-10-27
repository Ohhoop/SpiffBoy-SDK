# 3. Screen and art

## The screen

The screen is **180 pixels wide and 120 pixels high**. Every position and size you give is in these pixels; the console scales them up to the window.

- `x` goes from 0 at the left edge to 179 at the right edge, `y` from 0 at the top to 119 at the bottom.
- Positions and sizes are taken down to the whole pixel: drawing at `x = 10.7` draws at 10. The source rectangle of `sheet` and `layers` and the size of `rotated` are used as given: give them whole numbers.
- Anything drawn outside the 180x120 area is cut off.
- Your game fills the whole area itself, on every screen, usually with a `clear` at the start of `draw`.

`screen.width` and `screen.height` give 180 and 120, and `screen.calls` the number of draw calls of the current frame ([the limit](#the-draw-call-limit)). The screen is read only: a game that writes a field on it raises an error.

## The four shades

The screen shows four green-grey shades and nothing else. They are numbered from 1, the darkest, to 4, the lightest. `SpiffBoy.Cartridges.SHADES` holds them in that order, each a table with `r`, `g` and `b` from 0 to 1:

| Shade | RGB (0 to 255) | Typical use |
|---|---|---|
| 1 | 28, 36, 32 | ink: outlines, text, main shapes |
| 2 | 72, 86, 78 | dark details, secondary text |
| 3 | 112, 128, 118 | light details, disabled entries |
| 4 | 156, 168, 160 | paper: the background |

Any colour you ask for is replaced by the nearest of the four, at full opacity. The `a` (alpha) arguments of the drawing methods have no visible effect. Draw your art in these four shades from the start.

Hello SpiffBoy turns a shade number into the three values the methods take with a small helper:

```lua
local SHADES = SpiffBoy.Cartridges.SHADES

local function ink(index)
    local shade = SHADES[index]
    return shade.r, shade.g, shade.b
end

screen:clear(ink(4))
screen:rect(0, 17, 180, 1, ink(2))
```

## Textures are masks

A picture for the screen is a **mask**: plain white on a transparent background. The console paints the white in the shade you ask for. Every pixel must be either fully white or fully transparent; a grey or coloured pixel would be multiplied by the shade and come out as a colour the screen does not have.

`screen:sprite`, `screen:sheet`, `screen:rotated` and `screen:number` take a `shade` argument from 1 to 4, the darkest (1) when you leave it out. Any other shade number is an error.

## Layered sheets: sprites in several shades

A mask has one shade. A sprite in several shades, like the head of Spiffo, is a **layered sheet**: the picture is split into one mask per shade, and the four masks are stacked as four rows of the same height, darkest first. The console draws the rows on top of each other, each in its shade, and the picture comes back.

Several cells (animation frames, tiles, letters) sit side by side in the same sheet. `spiffo.png` of Hello SpiffBoy is 48x64: three cells of 16x16 (idle, blinking, saying hello) side by side, and four rows of 16 pixels.

```
         cell 0    cell 1    cell 2
         (idle)    (blink)   (hello)
row 1   [shade 1] [shade 1] [shade 1]    y 0 to 15
row 2   [shade 2] [shade 2] [shade 2]    y 16 to 31
row 3   [shade 3] [shade 3] [shade 3]    y 32 to 47
row 4   [shade 4] [shade 4] [shade 4]    y 48 to 63
```

`screen:layers(texture, sx, sw, sh, x, y, shades)` draws the cell whose left edge in the sheet is `sx`, `sw` wide and `sh` high (the height of one row), at `x, y` on the screen:

```lua
local CELL = 16
local HEAD_SHADES = { 1, 2, 3 }

function SpiffBoySDKHelloGame:drawSpiffo(screen, frame, x, y)
    screen:layers(self.spiffo, frame * CELL, CELL, CELL, x, y, HEAD_SHADES)
end
```

Each row drawn costs one draw call. Without the `shades` list all four rows are drawn. The fur of Spiffo is shade 4, the shade of the background, so Hello SpiffBoy skips that row and pays three calls per head instead of four. Skip a shade only where the background really is that shade: elsewhere, the skipped pixels show whatever lies behind.

The console cannot flip a picture. A character that faces both ways needs its frames drawn both ways in the sheet.

## The drawing methods

All of these are called on the `screen` given to `draw`. Each costs one draw call unless said otherwise.

### clear and rect

`screen:clear(r, g, b)` fills the whole screen. `screen:rect(x, y, w, h, r, g, b, a)` fills a rectangle.

```lua
screen:rect(0, PLAY_TOP - 1, width, 1, ink(2))
```

A box with a one pixel border is two calls, a dark rectangle and a light one inside it, as in `drawBubble` of Hello SpiffBoy:

```lua
screen:rect(x, y, w, h, ink(1))
screen:rect(x + 1, y + 1, w - 2, h - 2, ink(4))
```

### sprite and tinted

`screen:sprite(texture, x, y[, w, h, a, shade])` draws a whole mask with its top left corner at `x, y`. Without `w` and `h` it keeps the size of the texture; with them it is stretched.

```lua
screen:sprite(self.star, 40, 20)
screen:sprite(self.star, 40, 20, nil, nil, 1, 3)
```

The second line draws the same star in shade 3.

`screen:tinted(texture, x, y, w, h, r, g, b, a)` does the same with a colour in place of a shade number, taken to the nearest shade. `w` and `h` may be nil.

### sheet

`screen:sheet(texture, sx, sy, sw, sh, x, y[, a, shade])` draws a region of a texture at its own size: the rectangle at `sx, sy`, `sw` wide and `sh` high, in pixels of the texture, placed at `x, y` on the screen.

```lua
local TILE = 8
screen:sheet(self.tiles, tileIndex * TILE, 0, TILE, TILE, column * TILE, row * TILE, 1, 1)
```

It suits a strip of tiles or frames in one shade. For several shades, use `layers`.

### layers

`screen:layers(texture, sx, sw, sh, x, y[, shades])` draws one cell of a layered sheet ([above](#layered-sheets-sprites-in-several-shades)): one call per shade drawn, four without a list.

```lua
screen:layers(self.logo, 0, LOGO_W, LOGO_H, math.floor((180 - LOGO_W) / 2), LOGO_Y, { 1, 3 })
```

### rotated

`screen:rotated(texture, cx, cy, degrees, w, h[, a, shade])` draws a whole mask turned around its centre, placed at `cx, cy`, stretched to `w` by `h`; `w` and `h` are required. The texture is turned as a whole, so at angles other than multiples of 90 degrees its square pixels are drawn slanted. Frames drawn at each angle keep the pixels square.

```lua
screen:rotated(self.arrow, 90, 60, self.angle, 8, 8, 1, 1)
```

### number

`screen:number(value, x, y, digits, align, minDigits[, shade])` draws a whole number with your own digits. `digits` is a strip texture of the ten digits 0 to 9 side by side, every cell the same width (the width of the strip divided by ten). One call per digit.

- `value` is taken down to a whole number. Give zero or more: a minus sign has no cell in the strip.
- `align` is `"left"` (x is the left edge), `"right"` (x is the right edge) or `"centre"`.
- `minDigits` pads with zeros: 3 draws 7 as `007`. Give 1 or nil for no padding.

From Spiff-Pong, whose `digits.png` is 80x10, ten cells of 8x10:

```lua
screen:number(match.score[1], View.CENTRE - SCORE_GAP, SCORE_Y, digits, "right", 1, View.DIM)
screen:number(match.score[2], View.CENTRE + SCORE_GAP, SCORE_Y, digits, "left", 1, View.DIM)
```

### text, textCentre and textRight

`screen:text(str, x, y, r, g, b, a)` writes a line with the pixel font of the screen, `x` being its left edge and `y` its top. `screen:textCentre` centres the line on `x`; `screen:textRight` ends it at `x`. They take the same arguments. Without a colour the text is drawn in the lightest shade.

```lua
screen:textCentre(gameText("Title"), centre, 6, ink(1))
screen:text(gameText("Count", self.count), 2, 1, ink(1))
screen:textRight(gameText("Best", self.best), width - 2, 1, ink(1))
```

**Each visible letter is one draw call.** A line of 20 letters costs 20 calls; texts are the biggest spenders of most games.

### textWidth, lineHeight and wrapText

These three cost no draw call.

- `screen:textWidth(str)` returns the width of a line in pixels. `drawBubble` sizes its box with it: `local w = screen:textWidth(text) + 6`.
- `screen:lineHeight()` returns the height of a line in the language of the player: 14 pixels, 16 in Thai. Step lines by it.
- `screen:wrapText(str, width)` returns the lines of a text that fit a width, breaking after spaces, beside Chinese, Japanese and Korean characters, and between Thai syllables.

```lua
local lines = screen:wrapText(gameText("Story"), 170)
for i = 1, #lines do
    screen:text(lines[i], 5, 10 + (i - 1) * screen:lineHeight(), ink(1))
end
```

## The pixel font

The font of the screen covers the 29 languages of Project Zomboid: Latin, Cyrillic, Greek, Thai, Chinese, Japanese and Korean. Its letters have their own widths. The widths below are in pixels and include the gap before the next letter, so the width of a line is the sum of the widths of its characters:

| Characters | Width |
|---|---|
| Latin capitals | 6, except I (4), J and L (5), M and W (8) |
| Latin small letters | 5, except i, j, l and r (4), m, v, w, x and y (6) |
| Accented Latin letters | 4 to 8, mostly 5 or 6 |
| Digits and the space | 5 |
| `.` `,` `:` `!` `'` | 4 |
| `?` `-` `(` `)` | 6 |
| Cyrillic and Greek | 4 to 9, mostly 5 or 6 |
| Thai | 6 to 10 |
| Chinese and Japanese | 12 |
| Korean | 10 |

The 180 pixels of the screen hold about 30 Latin capitals or 15 Chinese characters. A translation is often longer than the English text: measure with `textWidth` and leave room.

A character the font lacks is left out and named once in the log: `SpiffBoy: [SB-GLYPH] pixel font has no glyph for code point 128512`, here for the emoji 😀. The font holds the letters of every language of the game and many symbols, such as `€`, `★` or `↑`; emojis are not among them.

The font is loaded a page of 256 characters at a time, the first time a text needs it. Until a page is loaded its letters are left out, so a text can be missing on its very first frame.

## The draw call limit

Every `clear`, `rect`, `sprite`, `tinted`, `sheet` and `rotated`, each row of `layers`, each digit of `number` and each letter of a text is one **draw call**. The console allows **300 draw calls per frame**. The 301st raises an error and the game crashes:

```
SpiffBoy: the cartridge SpaceRace (class MyModSpaceRaceGame) crashed in draw at tick 1520
SpiffBoy: [SB-DRAW-LIMIT] a frame went past 300 draw calls. Fix: draw less in one frame and count the calls with screen.calls. See: SDK docs/03-screen-and-art.md, The draw call limit.
```

Your game must stay under the limit in its worst frame, not only in a usual one: the busiest menu, the screen with the most enemies, the longest translation.

### Measuring

- `screen.calls` gives the calls of the frame so far. While you develop, you can write it in a corner at the end of `draw`, then remove the line:

  ```lua
  screen:textRight(tostring(screen.calls), 178, 104, ink(1))
  ```

- The [robot](09-testing.md#the-robot) plays your game offline and prints `most calls`, the busiest frame it saw. It reports about 40 for Hello SpiffBoy and 50 for Spiff-Pong.

### Staying under it

- One big shape costs less than many small ones. A dashed line of 14 dashes is 14 calls; the same line drawn as one texture is 1.
- Draw layered sheets only in the shades they use. A logo in two shades costs 2 calls with `{ 1, 3 }`, 4 without.
- Keep texts short, and remember that translations are often longer than English.
- Build static parts as one picture. A frame, a wall or a background that never changes is one texture, one call. For a grid, a picture holding a whole row costs one call per row instead of one per cell.
- Do not clear a part you are about to cover.

## The art folder

Your pictures go in the `art` folder of your definition, usually `media/ui/<Ns>/Games/<Id>/`. Load them in `init` with `self.context.art(name)`, which reads `name.png` from that folder:

```lua
function Game:init()
    local art = self.context.art
    self.logo = art("logo")
    self.digits = art("digits")
    ...
```

- Load once, in `init`, never in `draw`: the robot warns when `art` is called while the game draws.
- Write the sizes of your art as constants, as Spiff-Pong does with `LOGO_W = 119`. A texture can still be loading during the first frames; the screen skips a texture until it is ready, so a size read from it in `init` cannot be trusted.
- A missing file gives nil and is named once in the log, `SpiffBoy: [SB-ART-MISSING] missing texture <path>`. Drawing nil draws nothing, so a misspelled name shows as an empty spot, not as a crash.
- Give the name with the letter case of the file: `art("basket")` for `basket.png`. Windows finds `art("Basket")` too, but Linux and the Steam Deck do not, so the picture is missing for those players. The [robot](09-testing.md#the-robot) treats a name whose case differs from the file as a missing picture.
- Never load your art with `getTexture` or `Texture.getSharedTexture` and a relative path. The game looks such names up by their short file name in its own pictures first, so your `logo.png` could show a picture of the game. `context.art` loads your file by its full path. The robot warns when your game calls `getTexture`, `Texture.getSharedTexture` or `Texture.new`.

## label.png: the picture on the cartridge

The console shows the cartridge in its slot with a label. Put `label.png` in your art folder and the console shows it; without it, the console prints the `title` of your definition on a paper label.

The label is not drawn on the screen, so it is a full colour picture with no limit of shades. The console draws it 97x53 of its own pixels, stretched; draw it at **388x212** (four times that size). [cartridge_label.py](08-the-cartridge-item.md#the-label-the-icon-and-the-3d-model) puts the same picture on the 3D model and the icon of the item.

## Making art with shade_layers.py

`tools/shade_layers.py` turns your drawings into a layered sheet and tells you what each cell costs.

1. Draw your sprite in any editor, in the four exact shades of the table above, on a transparent background, with no anti-aliasing and no half transparent pixel. With `--grey` you may draw in greys instead: 0 to 63 is shade 1, 64 to 127 shade 2, 128 to 191 shade 3, 192 to 255 shade 4.
2. Run the tool. With several frames in one picture, give the size of a cell:

   ```
   python tools/shade_layers.py walk.png jump.png --cell 16x16 -o ".../media/ui/MyMod/Games/SpaceRace/hero.png"
   ```

3. Read the report: one line per cell, with its `sx` (the left edge to give `layers`), its size, the shades it uses and its cost.

The tool refuses a picture with a pixel outside the four shades, or half transparent, and names the first one it finds. [Tools reference](13-tools-reference.md#shade_layerspy) lists every option.

### Start from the example drawing

`tools/examples/spiffo_drawing.png` is the drawing of Spiffo in Hello SpiffBoy: three frames of 16x16 side by side (eyes open, eyes shut, mouth open), in the four shades on a transparent background. Turn it into the sheet of the game:

```
python tools/shade_layers.py tools/examples/spiffo_drawing.png --cell 16x16 -o spiffo.png
```

```
cell   0  sx     0  16x16  shades { 1, 2, 3, 4 }   4 calls with that list, 4 without
cell   1  sx    16  16x16  shades { 1, 2, 3, 4 }   4 calls with that list, 4 without
cell   2  sx    32  16x16  shades { 1, 2, 3, 4 }   4 calls with that list, 4 without
spiffo.png: 48x64, 3 cells of height 16
```

The result is exactly `media/ui/SpiffBoySDK/Games/HelloSpiffBoy/spiffo.png` of the SDK. The report lists shade 4 because the fur uses it; the game skips that row on its plain background, as explained [above](#layered-sheets-sprites-in-several-shades).

A picture in a single shade (a strip of digits, a set of one shade tiles) needs no layered sheet: draw it in white and use `sprite`, `sheet` or `number`.

Next: [Sound and music](04-sound-and-music.md).

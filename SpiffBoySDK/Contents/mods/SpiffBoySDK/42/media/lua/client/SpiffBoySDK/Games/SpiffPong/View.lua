-- Drawing helpers of Spiff-Pong and the drawing of the field.
--
-- The handheld screen is 180x120 logical pixels and shows only four
-- green-grey shades, numbered 1 (darkest) to 4 (lightest). Rects and texts
-- take a colour, so these helpers pass the colour of a shade; textures are
-- white masks painted in the shade given to sprite, sheet, number or layers.
-- The summary of each helper gives the draw calls it costs.

require "SpiffBoySDK/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoySDK/Games/SpiffPong/Match"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Match = SpiffBoySDK.SpiffPong.Match

local View = {}
SpiffBoySDK.SpiffPong.View = View

local SHADES = SpiffBoy.Cartridges.SHADES
local SUB = Match.SUB

View.INK = 1
View.DIM = 2
View.SOFT = 3
View.PAPER = 4
View.WIDTH = Match.WIDTH
View.HEIGHT = Match.HEIGHT
View.CENTRE = Match.WIDTH / 2

local DASH_X = 89
local DASH_W = 2
local DASH_H = 4
local DASH_STEP = 8
local SCORE_Y = 6
local SCORE_GAP = 10
local CURSOR_SIZE = 4

--- Fills the whole screen with a shade: one call.
function View.clear(screen, shade)
    local c = SHADES[shade]
    screen:clear(c.r, c.g, c.b)
end

--- Fills a rectangle with a shade: one call.
function View.rect(screen, x, y, w, h, shade)
    local c = SHADES[shade]
    screen:rect(x, y, w, h, c.r, c.g, c.b, 1)
end

--- Writes a text from its left edge in a shade: one call per glyph.
function View.text(screen, str, x, y, shade)
    local c = SHADES[shade]
    screen:text(str, x, y, c.r, c.g, c.b, 1)
end

--- Writes a text centred on x in a shade: one call per glyph.
function View.centre(screen, str, x, y, shade)
    local c = SHADES[shade]
    screen:textCentre(str, x, y, c.r, c.g, c.b, 1)
end

--- Writes a text ending at x in a shade: one call per glyph.
function View.right(screen, str, x, y, shade)
    local c = SHADES[shade]
    screen:textRight(str, x, y, c.r, c.g, c.b, 1)
end

--- Draws a framed box in the lightest shade with a dark border: two calls.
function View.box(screen, x, y, w, h)
    View.rect(screen, x, y, w, h, View.INK)
    View.rect(screen, x + 1, y + 1, w - 2, h - 2, View.PAPER)
end

--- Draws the menu cursor, a small ball, in front of an entry whose text starts at x on line y: one call.
function View.cursor(screen, x, y)
    View.rect(screen, x - CURSOR_SIZE - 4, y + 6, CURSOR_SIZE, CURSOR_SIZE, View.INK)
end

--- Draws the field of a match: background, walls, the dashed middle line, both scores with the digit strip, both paddles and the ball while it is in play; about 25 calls.
function View.field(screen, match, digits)
    View.clear(screen, View.PAPER)
    View.rect(screen, 0, 0, View.WIDTH, Match.TOP, View.DIM)
    View.rect(screen, 0, Match.BOTTOM, View.WIDTH, View.HEIGHT - Match.BOTTOM, View.DIM)
    -- Fourteen dashes, one draw call each. A dotted line of single pixels one
    -- row apart would cost more than fifty; a texture of the whole line drawn
    -- with sprite would cost one.
    for y = Match.TOP + 2, Match.BOTTOM - DASH_H, DASH_STEP do
        View.rect(screen, DASH_X, y, DASH_W, DASH_H, View.SOFT)
    end
    -- screen:number draws a number with the strip of ten digits of the art,
    -- one call per digit, painted in the shade given last.
    screen:number(match.score[1], View.CENTRE - SCORE_GAP, SCORE_Y, digits, "right", 1, View.DIM)
    screen:number(match.score[2], View.CENTRE + SCORE_GAP, SCORE_Y, digits, "left", 1, View.DIM)
    for side = 1, 2 do
        View.rect(screen, Match.PADDLE_X[side], math.floor(match.paddles[side].y / SUB), Match.PADDLE_W, Match.PADDLE_H, View.INK)
    end
    if match.phase == Match.PHASE_PLAY then
        local ball = match.ball
        View.rect(screen, math.floor(ball.x / SUB), math.floor(ball.y / SUB), Match.BALL, Match.BALL, View.INK)
    end
end

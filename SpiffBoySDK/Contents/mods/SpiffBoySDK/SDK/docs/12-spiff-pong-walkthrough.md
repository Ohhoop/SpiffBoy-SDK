# 12. Spiff-Pong walkthrough

Spiff-Pong puts the pieces of Hello SpiffBoy together in a complete game: a title, a match against the console, a match against a second player on the link cable, options, best scores with initials, music and sound effects. It is about 1800 lines in small files, each starting with a comment that explains its role. Open them next to this page.

## The files

Under `42/media/` of the SDK mod, the SDK media folder (`../42/media` from the `SDK` folder):

| File | Role |
|---|---|
| `lua/shared/SpiffBoySDK/Games/SpiffPong/Definition.lua` | Registers the cartridge. |
| `lua/shared/SpiffBoySDK/Games/SpiffPong/Translate/*.json` | The texts. |
| `lua/client/SpiffBoySDK/Games/SpiffPong/Game.lua` | The class, the table of screens, `tick` and `draw`. |
| `.../Match.lua` | The rules: paddles, ball, score. A pure simulation. |
| `.../Brain.lua` | The console player. |
| `.../Link.lua` | The two player protocol over the cable. |
| `.../Play.lua` | Running a match, alone or in lockstep on the cable. |
| `.../Menus.lua` | Title, options, best scores and the waiting screen. |
| `.../Results.lua` | The end of a match and the initials entry. |
| `.../View.lua` | Drawing helpers and the drawing of the field. |
| `.../Records.lua` | The best scores in the save. |
| `.../Options.lua` | The options in the save. |
| `.../Music.lua` | The tunes and the sound effects. |
| `ui/SpiffBoySDK/Games/SpiffPong/logo.png` | The title, a layered sheet of one 119x15 cell. |
| `ui/SpiffBoySDK/Games/SpiffPong/digits.png` | The ten score digits, a white mask strip of 80x10. |
| `ui/SpiffBoySDK/Games/SpiffPong/label.png` | The colour label of the cartridge, 388x212. |
| `scripts/SpiffBoySDK/SpiffPong.txt` | The cartridge item, with the `spiffboy:cartridge` tag. |

Each file has one job. The rules (`Match`) know nothing about the screen, the screen (`View`) nothing about the cable, the cable (`Link`) nothing about the rules, so you can change one without reading the others. Each file also stays far from the [limit of 200 local variables](10-kahlua-and-pitfalls.md#at-most-200-local-variables-per-function).

## Game.lua: the class and its screens

```lua
SpiffBoySDKPongGame = SpiffBoyGameBase:derive("SpiffBoySDKPongGame")

local Game = SpiffBoySDKPongGame
Game.text = SpiffBoy.GameTexts.of("SpiffPong")

Game.MODE_TITLE = "title"
Game.MODE_OPTIONS = "options"
Game.MODE_RECORDS = "records"
Game.MODE_WAITING = "waiting"
Game.MODE_PLAY = "play"
Game.MODE_RESULT = "result"
Game.MODE_INITIALS = "initials"

local SCREENS = {
    [Game.MODE_TITLE] = { tick = "tickTitle", draw = "drawTitle" },
    [Game.MODE_OPTIONS] = { tick = "tickOptions", draw = "drawOptions" },
    ...
}
```

Where Hello SpiffBoy chooses its screen with an `if`, Spiff-Pong uses a table: each mode names the method that advances it and the method that draws it, and `tick` and `draw` shrink to one line each:

```lua
function Game:tick(inputs, tick)
    self.clock = self.clock + 1
    self:pollLink()
    self[SCREENS[self.mode].tick](self, inputs[1])
end

function Game:draw(screen)
    self[SCREENS[self.mode].draw](self, screen)
end
```

Each screen also has an open method (`openTitle`, `openOptions`, `openPlay`...) that sets the mode and prepares what the screen needs. A screen moves to the next one only through its open method, so every way into a screen goes through the same preparation, and no screen opens with a field left over from its last visit.

`init` loads the art, reads the save, wraps the port of the cable, applies the music option and opens the title:

```lua
function Game:init()
    local art = self.context.art
    self.logo = art("logo")
    self.digits = art("digits")
    self.records = Records.read(self.save)
    self.options = Options.read(self.save)
    self.port = Link.new(self.link)
    self.clock = 0
    self.twoPlayer = false
    self:applyMix()
    self:openTitle()
end
```

At its end, `Game.lua` requires `Menus`, `Play` and `Results`. Those files add methods to the class (`function Game:tickTitle(input)`...), so they must load after the class exists: a simple way to split one class over several files.

## Match.lua: the rules and nothing else

`Match` is a pure simulation: it takes what the two paddles hold this tick and moves the world one step.

```lua
function Match:tick(left, right)
    if self.phase == Match.PHASE_OVER then
        return
    end
    self.ticks = self.ticks + 1
    self:movePaddle(1, left)
    self:movePaddle(2, right)
    if self.phase == Match.PHASE_SERVE then
        self.timer = self.timer - 1
        if self.timer <= 0 then
            self:serve()
        end
        return
    end
    self:moveBall()
end
```

It never reads a button, draws a pixel or plays a note, which is what lets both consoles of a two player game run the same code with the same inputs. What it does:

- Positions and speeds are whole numbers of sub pixels, 16 per pixel (`Match.SUB`), as the [rules of determinism](10-kahlua-and-pitfalls.md#determinism) ask.
- Its own generator, `SpiffBoyRandom.new(seed)`, draws the height and angle of each serve.
- The collision is swept. A fast ball moves several pixels a tick and could jump over a 3 pixel paddle, so `moveBall` checks whether the ball crossed the face of the paddle between its old and new position, not whether it overlaps it now.
- The angle depends on where the ball hits the paddle, and the ball gets a little faster at each hit.
- When something happens, the match records an event (`serve`, `paddle`, `wall`, `point`, `over`). The game reads them with `takeEvents()` and plays the matching sound.
- `checksum()` sums up the whole state in one number for the two consoles to compare.

## Brain.lua: the console player

The console player does not move its paddle. It presses buttons, returning `{ up = ..., down = ... }` like a human, and the match moves the paddle with the same rules for both sides. A brain that only presses buttons cannot cheat, and the match code is the same for one or two players.

```lua
self.match:tick(heldOf(input), self.brain:think(self.match, 2))
```

To be beatable, it aims a little off the ball (a new error after each hit and each serve, drawn from its own seeded generator) and rests one tick in four, which makes its paddle slower than yours. `AIM_ERROR` and `REST_EVERY` set its strength.

## Play.lua: running a match

Alone:

```lua
function Game:startSoloMatch()
    local seed = self.random:int(1, SEED_MAX)
    self.twoPlayer = false
    self.mySide = 1
    self.match = Match.new(seed, self.options.speed, self.options.points)
    self.brain = Brain.new(seed + 1)
    self:openPlay()
end
```

The seed of the match comes from `self.random`. Each tick, `tickPlay` handles the pause (Start pauses, Start resumes, B quits), advances the match with your input and the brain's, turns the events into sounds, and opens the result when the match is over:

```lua
function Game:hearMatch()
    for _, event in ipairs(self.match:takeEvents()) do
        if event.kind == "paddle" then
            self:effect(Music.PADDLE)
        elseif event.kind == "wall" then
            self:effect(Music.WALL)
        elseif event.kind == "point" then
            self:effect(Music.POINT)
        end
    end
end
```

On the cable, `tickLinked` runs the lockstep of [The link cable](07-link-cable.md#each-frame-of-the-match). `drawPlay` draws the field through `View.field`, writes `YOU` and `CPU` above the paddles before the first serve, `WAITING` when the cable stalls, and the pause box.

## Link.lua: the protocol

`Link.lua` wraps `self.link` with the messages of the game: hello, bye, ping and pong, start, input and checksum. Every message starts with one letter for its kind; `poll` checks the kind and the length of each message before reading it, and ignores what it does not understand. Ticks travel as two bytes and wrap at 65536. [The link cable](07-link-cable.md#how-spiff-pong-does-it) describes the exchange.

`Game:pollLink`, called at the start of every tick, reads the port on every screen, so pings are always answered and nothing old waits in the queue when a two player screen opens. It also sends the console back to the title when the cable is lost or the other player leaves during a two player screen.

## Menus.lua: title, options, best scores, waiting

The title draws the logo as a layered sheet in the two shades it uses, a small endless rally (three calls), and the menu with a small ball as cursor:

```lua
local LOGO_W = 119
local LOGO_H = 15
local LOGO_SHADES = { View.INK, View.SOFT }

screen:layers(self.logo, 0, LOGO_W, LOGO_H, math.floor((View.WIDTH - LOGO_W) / 2), LOGO_Y, LOGO_SHADES)
```

The size of the logo is written as constants, because the texture can still be loading during the first frames.

The menu cursors wrap with the [`wrap` function](10-kahlua-and-pitfalls.md#modulo-keeps-the-sign-of-the-left-side). The menus call [`keepMusic`](04-sound-and-music.md#music-after-a-jingle), so the jingle of a won or lost match ends before the title music returns.

The options screen turns an entry with left and right, applies the music option at once with `setMix`, and writes the save once when the player leaves, only if something changed.

The waiting screen sends a hello every half second. Once both consoles are there, the leader measures the cable with four pings, picks the delay, draws the seed and sends the start.

## Results.lua: results and initials

When the match is over, `openResult` plays the win or lose jingle and, against the console, counts the match and writes the save at once. The result screen ignores the buttons for one second (`RESULT_LOCK`), so a button still held from the match does not skip it.

If the longest rally of the match enters the table, the initials screen opens, following the pattern of [Saving](05-saving.md#pattern-best-scores-with-initials).

## View.lua: drawing helpers

`View` names the four shades by role, so drawing code reads as intent:

```lua
View.INK = 1
View.DIM = 2
View.SOFT = 3
View.PAPER = 4
```

It wraps the drawing methods to take a shade number: `View.rect(screen, x, y, w, h, shade)`, `View.text`, `View.centre`, `View.right`, `View.box` (two calls) and `View.cursor`. `View.field` draws a whole match in about 25 calls: background, walls, a dashed middle line of fourteen dashes, both scores with `screen:number`, both paddles and the ball. The comment of each helper counts its calls, which keeps the budget easy to follow; the robot reports 50 calls for the busiest frame it sees.

## Records.lua and Options.lua: the save

Each kind of saved data has its module with `read(save)` and `write(save, ...)`, as described in [Saving](05-saving.md#never-trust-a-save). The best scores are stored as short texts, `"ABC:12"`.

## Music.lua: the sound

Twelve tunes: a looping title music in G major with sparse drums, a start jingle, a win jingle, a lose jingle, and short effects for the paddle, the wall, the point, the cursor, confirm, back, refuse and pause.

```lua
[Music.PADDLE] = { pulse2 = "t240 @2 v12 y2 l32 o5 b" },
[Music.WALL] = { pulse2 = "t240 @2 v9 y2 l32 o4 b" },
[Music.POINT] = { pulse1 = "t150 @2 v12 y3 s2,-3 l8 o4 d", noise = "t150 l16 v6 y2 n{56 104}" },
```

The match itself has no music, only the blips of the ball. The point effect uses the falling sweep of pulse 1 and a burst of noise. The music option silences the music through the mix and keeps the effects.

## Testing it

The robot plays Spiff-Pong alone; `tests/spiff_pong/run_link_test.py` plays it on two consoles with simulated cables of different delays and checks that both matches stay identical tick after tick ([Testing](09-testing.md#testing-the-link-cable-offline)).

## From here

The [Spiff-Pong challenges](exercises/README.md#spiff-pong-challenges) suggest five changes to it. For your own game, its structure carries over: a pure simulation, a brain that presses buttons, a table of screens with open, tick and draw methods, a module per kind of saved data, and a view module with named shades.

Next: [Tools reference](13-tools-reference.md).

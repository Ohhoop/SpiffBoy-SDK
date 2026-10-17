# 2. How a cartridge works

The SpiffBoy mod runs the console: it reads the buttons, keeps the clock, plays the sound chip and stores the save. It knows nothing about any game. Once your game starts, the screen belongs to it entirely: the console draws no title, no score and no pause menu. If your game needs one, your game draws it.

A cartridge is a few files, each in the folder the engine reads it from:

| File, under `media/` | Side | Role |
|---|---|---|
| `lua/shared/<Ns>/Games/<Id>/Definition.lua` | shared | Registers the cartridge with the console. |
| `lua/shared/<Ns>/Games/<Id>/Translate/<LANG>.json` | shared | The texts of the game, one file per language. |
| `lua/client/<Ns>/Games/<Id>/Game.lua`, and more files if you split the game | client | The game class: rules and drawing. |
| `ui/<Ns>/Games/<Id>/*.png` | | The art: white masks, and the colour `label.png`. |
| `scripts/<Ns>/<Id>.txt` | | The cartridge item. |

`<Ns>` is the namespace of your mod, `<Id>` the id of the game. Shared files run on the clients and on the server: the server needs every definition to put cartridges in the loot. Client files run only where a player draws the game. Shared files load before client files.

## The definition

`Definition.lua` registers the cartridge with `SpiffBoy.Cartridges.register`. The one of Hello SpiffBoy:

```lua
require "SpiffBoySDK/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "HelloSpiffBoy",
    item = "SpiffBoySDK.Cartridge_HelloSpiffBoy",
    title = "Hello SpiffBoy",
    mod = SpiffBoySDK.MOD_ID,
    game = "SpiffBoySDKHelloGame",
    art = "media/ui/SpiffBoySDK/Games/HelloSpiffBoy/",
    texts = "media/lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/",
    loot = { weight = 0 },
})
```

| Field | Required | Meaning |
|---|---|---|
| `api` | yes | The version of the SpiffBoy framework the game is written for, a whole number from 1. Write `api = 1`. See [Versions of the framework](#versions-of-the-framework). |
| `id` | yes | The name of the game: its folders, its texts and its tunes are found by it. Use letters and digits. |
| `item` | yes | The full type of the cartridge item, `Module.ItemName`, as your item script defines it, 64 characters at most. |
| `title` | yes | The title printed on a paper label when the art folder holds no `label.png`. |
| `mod` | yes | The id of the mod that holds the art and the texts, as in its `mod.info`. Hello SpiffBoy gives `SpiffBoySDK.MOD_ID`, defined in `Core.lua`. |
| `game` | yes | The global name of the game class, as a string: the class only exists on the client, the definition also runs on the server. |
| `art` | yes | The art folder, from the version folder (`42/`) of the mod, ending with `/`. |
| `texts` | yes | The folder of the text files, from the version folder of the mod, ending with `/`. |
| `loot` | no | `{ weight = n }`, optionally with `lists = { ... }`. Without it the weight is 2. See [The cartridge item](08-the-cartridge-item.md#loot). |

A missing or malformed required field stops the file with an error that names the cartridge, such as `SpiffBoy: cartridge MyGame needs a title`.

Each cartridge of every loaded mod must be unique. The registration stops with an error naming the cartridges and the mods involved when:

- a cartridge of another mod already registered the same `id`;
- another cartridge already uses the same `item`;
- another cartridge already uses the same `game` class.

Prefixing the item module and the class name with your namespace, and choosing an id that names your game well, keeps you clear of other mods. Your own mod may register the same id again, as happens when its files reload: the new definition replaces the old one.

### Versions of the framework

`SpiffBoy.API_VERSION` is the version of the framework the installed SpiffBoy provides; it is 1 today. A definition whose `api` is above it is refused with `SpiffBoy: cartridge MyGame needs a newer SpiffBoy`, followed by both numbers, so a player with an old SpiffBoy reads why your cartridge does not load.

A new version of the framework never removes or reduces what an older version offers. A change that would break existing games creates a new version, and SpiffBoy keeps accepting every older one: a cartridge written for `api = 1` keeps working.

## The game class

`Game.lua` defines a class derived from `SpiffBoyGameBase`:

```lua
require "SpiffBoySDK/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "SpiffBoySDK/Games/HelloSpiffBoy/Music"

SpiffBoySDKHelloGame = SpiffBoyGameBase:derive("SpiffBoySDKHelloGame")
```

`require` paths start under `lua/shared`, `lua/client` or `lua/server`, without the `.lua`. The global name, the name given to `derive` and the `game` field of the definition must be the same. Other mods define globals too: prefix the name with your namespace.

The class overrides three methods. The base class gives empty ones, so a game writes only what it needs.

| Method | When the console calls it |
|---|---|
| `init()` | Once, when the game starts, after the boot logo of the console. Load the art, read the save, open the first screen. |
| `tick(inputs, tick)` | 60 times per second, at a fixed rate, until the console is switched off. All the rules live here. |
| `draw(screen)` | Each time the window paints a frame. It only draws; it never changes the state of the game. |

Do not override `new`: the base `new` sets the fields below, then calls your `init`.

### Why tick and draw are separate

The window paints frames as fast as the computer allows: 30 times a second on a slow machine, 144 on a fast one. The console counts the time that passed and calls `tick` as many times as needed for 60 ticks per second: a slow frame gets two or three ticks, a fast frame sometimes none. So:

- Movement and timers count in ticks. `SPEED = 1` in Hello SpiffBoy means one pixel per tick, 60 pixels per second, on every computer.
- `draw` reads the state and draws it. It can run twice without a tick in between. If it changed the state, the game would run differently from one computer to the next.

The clock has three more rules. It catches up at most 100 ms per frame, so a long freeze of the game does not run hundreds of ticks at once. No tick runs while Project Zomboid is paused. When the game speed is raised to 5x, 20x or 40x, the console runs 2, 4 or 6 times faster.

The second argument of `tick` counts the ticks since the game started. Hello SpiffBoy keeps its own counter, `self.ticks`, instead.

## The fields of a game

The base class sets these fields before it calls `init`:

| Field | Content |
|---|---|
| `self.screen` | The screen, the same object `draw` receives, so `tick` can read `self.screen.width` (180) and `self.screen.height` (120). See [Screen and art](03-screen-and-art.md). |
| `self.context` | What the console created the game with (below). |
| `self.random` | A random generator seeded by the console. |
| `self.save` | The save of the cartridge, a table. See [Saving](05-saving.md). |
| `self.chip` | The sound chip. See [Sound and music](04-sound-and-music.md). |
| `self.sequencer` | The music player of the chip. |
| `self.link` | The link cable port. See [The link cable](07-link-cable.md). |

`self:persist()` writes `self.save` on the cartridge, or raises an error when the save breaks one of its limits ([Saving](05-saving.md#what-a-save-can-hold)).

`self.context` holds `seed` (the number `self.random` was seeded with), `definition` (your definition table), `chip`, `sequencer` and `link` (the same objects as above), and `art(name)`, which loads `name.png` from the `art` folder of the definition and returns the texture, or nil when the file does not exist.

## The inputs

`tick` receives `inputs`, a list. `inputs[1]` is the input state of the player holding the console; a second player plays on another console, through the link cable.

`inputs[1]` has two tables of booleans with the keys `up`, `down`, `left`, `right`, `a`, `b` and `start`:

- `held` is true as long as the button is down. It suits movement: walking, steering, a paddle.
- `pressed` is true only on the tick the button went down. It suits actions and menus: one press, one effect. A press that starts and ends between two ticks still counts once.

`inputs[1]:axes()` returns the horizontal and the vertical direction held, each -1, 0 or 1. Left and right held together give 0.

From Hello SpiffBoy:

```lua
function SpiffBoySDKHelloGame:tickPlay(input)
    local pressed = input.pressed
    if pressed.start then
        self:leavePlay()
        return
    end
    local dx, dy = input:axes()
    self:moveSpiffo(dx * SPEED, dy * SPEED)
    if pressed.a then
        self:sayHello()
    end
    ...
```

Spiffo moves while a direction is held; the hello happens once per press of A.

## The random generator

`self.random` is deterministic: from the same seed it gives the same numbers in the same order.

| Call | Returns |
|---|---|
| `self.random:int(low, high)` | A whole number from `low` to `high`, both included. |
| `self.random:float()` | A number from 0 (included) to 1 (excluded). |
| `self.random:range(low, high)` | A number between `low` and `high`. |
| `self.random:chance(p)` | True with the probability `p`, from 0 to 1. |
| `self.random:reseed(n)` | Starts the sequence again from the number `n`. |

Use only this generator in a game, never `math.random`, `ZombRand` or the clock. The [robot](09-testing.md#the-robot) gives your game a fixed seed, so two runs of the same code play the same game and a change of code can be compared with the run before it. Two consoles on a link cable rely on the same property to compute the same match. For a second independent sequence, create one with `SpiffBoyRandom.new(seed)` (require `SpiffBoy/Core/Random`), as Spiff-Pong does for each match.

## Crashes

Every call the console makes to your game is protected. When your code raises an error in `init`, `tick` or `draw`:

1. The game stops for good: it is not called again.
2. The console freezes: the screen goes blank under interference and the chip holds its last note.
3. The error is written once in the log, `console.txt`, with the class name, the stage and the message:

   ```
   SpiffBoy: the game SpiffBoySDKHelloGame crashed in tick: <message>
   ```

The rest of Project Zomboid keeps running. Switching the console off and on starts your game from nothing; the save keeps its last written state.

When the console cannot find the class (a misspelled `game` field, or a client file that failed to load), it shows that the game is missing and the log says `SpiffBoy: no game class named <name>`. [Testing](09-testing.md#the-log-consoletxt) lists every message of the console.

## Hello SpiffBoy, step by step

Open `lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua` next to this page.

### The top of the file

After the requires and the class shown [above](#the-game-class), the file takes three locals: `Music`, the names of its tunes; `gameText`, which gives the texts of the game in the language of the player ([Texts and translations](06-texts-and-translations.md)); and `SHADES`, the four colours of the screen.

### The constants

```lua
local CELL = 16
local SPEED = 1
local PLAY_TOP = 18
local PLAY_BOTTOM = 101
local HELLO_TICKS = 40
local MODE_TITLE = "title"
local MODE_PLAY = "play"
```

Sizes in pixels, durations in ticks (60 ticks make a second), and the names of the two screens, so each number is tuned in one place.

### init

```lua
function SpiffBoySDKHelloGame:init()
    self.spiffo = self.context.art("spiffo")
    self.best = readBest(self.save)
    self.musicOn = readMusic(self.save)
    self.ticks = 0
    self.blinkTicks = 0
    self.nextBlink = self.random:int(BLINK_GAP_MIN, BLINK_GAP_MAX)
    self:enterTitle()
    self:applyMusic()
end
```

The art is loaded once, here, never in `draw`. The save is read through small functions that check every value. The first blink is drawn from `self.random`. Then the title opens and the music starts.

### Screens as modes

`self.mode` names the active screen, and each screen has an `enter` method that prepares it:

```lua
function SpiffBoySDKHelloGame:enterTitle()
    self.mode = MODE_TITLE
    self.selection = MENU_PLAY
end
```

`tick` and `draw` look at the mode and call the method of that screen:

```lua
function SpiffBoySDKHelloGame:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    self:tickBlink()
    if self.mode == MODE_TITLE then
        self:tickTitle(input)
    else
        self:tickPlay(input)
    end
end
```

Spiff-Pong organises its seven screens the same way, with a table in place of the `if` ([walkthrough](12-spiff-pong-walkthrough.md#gamelua-the-class-and-its-screens)).

### The title menu

```lua
function SpiffBoySDKHelloGame:tickTitle(input)
    local pressed = input.pressed
    if pressed.up then
        self.selection = (self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    elseif pressed.down then
        self.selection = self.selection % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    end
    if pressed.a or pressed.start then
        ...
```

The cursor reads `pressed`, so one press moves it once. Up from the first entry wraps to the last; the size is added before `%` because `%` of a negative number stays negative in the game ([Kahlua and pitfalls](10-kahlua-and-pitfalls.md#modulo-keeps-the-sign-of-the-left-side)). Each move plays a short sound effect.

### The play screen

`tickPlay`, shown in [The inputs](#the-inputs), moves Spiffo with `axes()`, says hello on A, switches the music on B and leaves on Start. `moveSpiffo` keeps him inside the playfield with `clamp`. `sayHello` counts, opens the mouth for `HELLO_TICKS`, plays the effect and raises the best count.

### Saving

The best count shows on screen at once but reaches the save only in `leavePlay`, when the player leaves the play screen, and only when it changed. [Saving](05-saving.md#when-to-persist) shows the code and explains why.

### Drawing

```lua
function SpiffBoySDKHelloGame:draw(screen)
    screen:clear(ink(4))
    if self.mode == MODE_TITLE then
        self:drawTitle(screen)
    else
        self:drawPlay(screen)
    end
end
```

Every frame starts by filling the screen with the lightest shade, then draws the current screen on top. `ink(index)` turns a shade number into the three colour values the drawing methods take. [Screen and art](03-screen-and-art.md) explains every call of `drawTitle` and `drawPlay`.

### The music file

`Music.lua` names the tunes and registers them under the id of the cartridge; [Sound and music](04-sound-and-music.md) goes through it.

The [Hello SpiffBoy exercises](exercises/hello-spiffboy.md) change this file one step at a time.

Next: [Screen and art](03-screen-and-art.md).

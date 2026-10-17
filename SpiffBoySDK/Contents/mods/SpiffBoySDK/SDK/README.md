# SpiffBoy SDK

The SpiffBoy SDK teaches you to make games for the SpiffBoy, the handheld console of the SpiffBoy mod for Project Zomboid build 42. A game for the console is a **cartridge**: an item of your own mod, holding Lua code, pictures, texts and music written as notes.

The SpiffBoy mod provides the console: the screen, the buttons, the sound chip, the save and the link cable. Your mod provides the game and everything it shows on the screen.

## Where the kit is

The whole kit comes with the SpiffBoy SDK mod. Once you subscribe to it on the Steam Workshop, Steam puts the mod folder in:

```
<Steam>/steamapps/workshop/content/108600/<SDK id>/mods/SpiffBoySDK/
    mod.info
    42/                 the files of the mod, which the game loads
        media/          the SDK media folder: the example cartridges and the developer menu
    SDK/                this kit, which the game ignores
        README.md       this page
        docs/
        tools/
        tests/
```

`<Steam>` is the folder where Steam is installed, `108600` is the number of Project Zomboid on Steam, and `<SDK id>` is the number at the end of the address of the Workshop page of the SpiffBoy SDK. The SpiffBoy mod sits beside it under its own number; the [Tools reference](docs/13-tools-reference.md#folders) gives its media folder.

Every command of these pages runs from the `SDK` folder. From there, the SDK media folder is `../42/media`.

## What the kit holds

| Part | Where, in the mod folder | Content |
|---|---|---|
| Hello SpiffBoy | the `HelloSpiffBoy` folders under `42/media` | The smallest complete cartridge: a title menu, Spiffo walking around, a sound effect, music and a saved best count, commented line by line. |
| Spiff-Pong | the `SpiffPong` folders under `42/media` | A complete game: menus, a match against the console or against a second player on the link cable, best scores with initials, options, music. |
| The developer menu | the `DevMenu` folders under `42/media` | A window that gives a console, the devices of the console and every registered cartridge of every mod. |
| The documentation | `SDK/docs/` | The pages below, and exercises with solutions. |
| The tools | `SDK/tools/` | Python scripts that create a new cartridge, turn your drawings into screen art, put your label on the cartridge model and icon, and check your texts. |
| The tests | `SDK/tests/` | The robot, which plays your cartridges offline, and a runner for every test at once. |

## Requirements

- Project Zomboid build 42.
- The SpiffBoy mod. The SDK and your own mod both depend on it.
- For the tools and the tests only: Python 3 with Pillow, numpy and lupa (`pip install pillow numpy lupa`). A cartridge can be made without them; the tests find mistakes before you start the game.

## Quick start

1. Subscribe to SpiffBoy and the SpiffBoy SDK on the Steam Workshop.
2. Enable both mods and start a solo game.
3. Right click the world and choose **SpiffBoy SDK**. Click **In a console** on the **Hello SpiffBoy** row, and play the game in that console.
4. Read [Getting started](docs/01-getting-started.md) to make your own cartridge from it.

## Learning path

| Step | Page | Topic |
|---|---|---|
| 1 | [Getting started](docs/01-getting-started.md) | Your own mod and your first cartridge, copied from Hello SpiffBoy. |
| 2 | [How a cartridge works](docs/02-how-a-cartridge-works.md) | The definition, the game class, `init`, `tick` and `draw`, the buttons, the random generator, crashes. |
| 3 | [Screen and art](docs/03-screen-and-art.md) | The 180x120 screen, the four shades, masks and layered sheets, the drawing methods, text, the draw call limit. |
| 4 | [Sound and music](docs/04-sound-and-music.md) | The sound chip, tunes and effects, the music notation. |
| 5 | [Saving](docs/05-saving.md) | The save of a cartridge, best scores and options. |
| 6 | [Texts and translations](docs/06-texts-and-translations.md) | Texts per language, arguments, item names. |
| Practice | [Exercises](docs/exercises/README.md) | Seven exercises on Hello SpiffBoy, then challenges on Spiff-Pong. |
| 7 | [The link cable](docs/07-link-cable.md) | Two consoles, two players, lockstep on top of the port. |
| 8 | [The cartridge item](docs/08-the-cartridge-item.md) | The item script, the icon, the 3D model, the label and the loot. |
| 9 | [Testing](docs/09-testing.md) | The robot, the developer menu, the log. |
| 10 | [Kahlua and pitfalls](docs/10-kahlua-and-pitfalls.md) | Where the Lua of the game differs from standard Lua, determinism, common mistakes. |
| 11 | [Publishing](docs/11-publishing.md) | `mod.info`, the folder layout, the Workshop, the versions of your mod and of the framework. |
| 12 | [Spiff-Pong walkthrough](docs/12-spiff-pong-walkthrough.md) | A tour of a complete cartridge. |
| Reference | [Tools reference](docs/13-tools-reference.md) | Every tool and test with its options. |
| Reference | [Sound chip reference](docs/14-sound-chip-reference.md) | The voices, registers, wave tables and noise settings of the chip, the limits of the notation, example scores. |

## License

License: to be decided by the author.

# 1. Getting started

This page takes you from the two mods to your own cartridge, copied from Hello SpiffBoy and renamed.

## Install SpiffBoy and the SDK

You need two mods: **SpiffBoy**, which provides the console, and **SpiffBoy SDK**, this kit. Subscribe to both on the Steam Workshop. The kit, these pages included, comes inside the SpiffBoy SDK mod, in its `SDK` folder; the [README](../README.md#where-the-kit-is) shows where Steam puts it.

The tools and the tests need Python 3 and three packages:

```
pip install pillow numpy lupa
```

Enable **SpiffBoy** and **SpiffBoy SDK** in the **Mods** menu of the game, then start a solo game.

## The developer menu

The SDK adds an entry to the right click menu of the world: **SpiffBoy SDK**. It opens a window with two sections:

- **Devices**: a console, a battery, headphones, earbuds and a link cable. Each click puts one in your main inventory, when it has room.
- **Cartridges**: one row per cartridge registered by any loaded mod, its title followed by the id of its mod in brackets. The left button gives the loose cartridge, **In a console** gives a console with that cartridge already inside, and **All cartridges** gives one of each.

In solo the entry is always there. In multiplayer it shows only for players whose role may add items.

Take Hello SpiffBoy **In a console** and play it once, so you know what you are about to copy.

## Create your own mod

A cartridge lives in your own mod, never inside SpiffBoy or the SDK. Create the folders of a build 42 mod in `C:\Users\<you>\Zomboid\Workshop\`. This guide calls the mod `MyMod`; use your own name everywhere `MyMod` appears.

```
Zomboid/Workshop/MyMod/
    preview.png                      the picture of the Workshop page, 256x256
    Contents/mods/MyMod/
        mod.info
        poster.png
        42/
            mod.info
            media/
```

Write the same `mod.info` in `Contents/mods/MyMod/` and in `Contents/mods/MyMod/42/`:

```
id=MyMod
name=My Mod
description=My first SpiffBoy cartridge.
modversion=0.1.0
require=\SpiffBoy
poster=poster.png
icon=poster.png
versionMin=42.0
```

`require=\SpiffBoy` makes the game load SpiffBoy before your mod, so the registry of cartridges exists when your cartridge registers. [Publishing](11-publishing.md#modinfo) explains every line.

Keep the real files in `Zomboid/Workshop/MyMod`. A mod folder reached through a junction or a symbolic link loads in solo, but a multiplayer server refuses the connection.

## Copy the example with new_cartridge.py

`tools/new_cartridge.py` copies Hello SpiffBoy into your mod and renames everything: the folders, the game class, the item, the title and the id. From the `SDK` folder of the SpiffBoy SDK mod, where `../42/media` is the media folder of the SDK, on one line:

```
python tools/new_cartridge.py --sdk "../42/media" --mod "C:/Users/<you>/Zomboid/Workshop/MyMod/Contents/mods/MyMod/42/media" --namespace MyMod --module MyMod --id SpaceRace --title "Space Race" --mod-id MyMod
```

- `--namespace` is the folder name of your mod under `lua`, `ui`, `scripts` and `textures`, and the name of its global Lua table.
- `--module` is the script module of the cartridge item. Giving it the namespace is the simplest choice.
- `--id` is the id of the game. It names its folders and its texts, and the console finds its tunes by it. Choose it different from the namespace: the tool joins the two in the names it writes, and `--namespace SpaceRace --id SpaceRace` would give the class `SpaceRaceSpaceRaceGame` and the table `SpaceRace.SpaceRace`.
- `--title` is the title of the game.
- `--mod-id` is the `id=` of your `mod.info`.

The tool prints every file it writes:

```
written lua/shared/MyMod/Games/SpaceRace/Definition.lua
written lua/shared/MyMod/Games/SpaceRace/Translate/EN.json
written lua/client/MyMod/Games/SpaceRace/Game.lua
written lua/client/MyMod/Games/SpaceRace/Music.lua
written ui/MyMod/Games/SpaceRace/label.png
written ui/MyMod/Games/SpaceRace/spiffo.png
written scripts/MyMod/SpaceRace.txt
written textures/MyMod/MyModCartridge_SpaceRace.png
written textures/Item_MyMod_Cartridge_SpaceRace.png
written lua/shared/MyMod/Core.lua
written lua/shared/Translate/EN/ItemName.json
cartridge SpaceRace created: item MyMod.Cartridge_SpaceRace, game class MyModSpaceRaceGame
```

`Core.lua` defines the global table of your mod and `MyMod.MOD_ID`, the id the definition gives the console so it finds your art and texts in your mod.

The comments of Hello SpiffBoy that point to its exercises are left out of the copy. Of the texts of Hello SpiffBoy, the tool copies `EN.json` only. The console shows the English texts in every language your game has no file for; add the other languages once your texts are final ([Texts and translations](06-texts-and-translations.md)).

The tool writes nothing at all when a file it would create already exists, or when a name of the example is left over after renaming; it prints the problems instead. [Tools reference](13-tools-reference.md#new_cartridgepy) lists every rule.

## Or copy the example by hand

Copy these files from the SDK media folder to yours:

| From the SDK | To your mod |
|---|---|
| `lua/shared/SpiffBoySDK/Core.lua` | `lua/shared/MyMod/Core.lua` |
| `lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Definition.lua` and `Translate/EN.json` | `lua/shared/MyMod/Games/SpaceRace/`, keeping `Translate/` |
| `lua/client/SpiffBoySDK/Games/HelloSpiffBoy/` | `lua/client/MyMod/Games/SpaceRace/` |
| `ui/SpiffBoySDK/Games/HelloSpiffBoy/` | `ui/MyMod/Games/SpaceRace/` |
| `scripts/SpiffBoySDK/HelloSpiffBoy.txt` | `scripts/MyMod/SpaceRace.txt` |
| `textures/SpiffBoySDK/SpiffBoySDKCartridge_HelloSpiffBoy.png` | `textures/MyMod/MyModCartridge_SpaceRace.png` |
| `textures/Item_SpiffBoySDK_Cartridge_HelloSpiffBoy.png` | `textures/Item_MyMod_Cartridge_SpaceRace.png` |

Then rename inside the files:

1. In `Core.lua`, the table `SpiffBoySDK` becomes `MyMod`, and `MOD_ID` becomes the id of your `mod.info`.
2. In `Definition.lua`, the fields `id`, `item`, `title`, `mod`, `game`, `art` and `texts`; `api` stays 1.
3. In `Game.lua` and `Music.lua`, every `require` path, the class name `SpiffBoySDKHelloGame`, the table `SpiffBoySDK.HelloSpiffBoy`, and the id given to `SpiffBoy.GameTexts.of` and `SpiffBoy.Tunes.register`.
4. In the item script, `module SpiffBoySDK`, the item name `Cartridge_HelloSpiffBoy`, its `Icon`, its `WorldStaticModel` and the `model` block with its `texture`. Keep its `Tags` line as it is ([The cartridge item](08-the-cartridge-item.md#the-item-script) explains it).
5. In `Translate/EN.json`, the `"Title"` text.

A forgotten name can make your cartridge run the class, the texts or the tunes of the example instead of yours. The tool checks for leftovers; by hand, search your files for `HelloSpiffBoy` and `SpiffBoySDK` when you are done.

## Replace the pictures of the example

Your cartridge still shows the pictures of Hello SpiffBoy. Replace them with your own as you build your game:

- `ui/MyMod/Games/SpaceRace/label.png`, the label of the cartridge, 388x212 in colour, shown on the cartridge in the slot of the console.
- `ui/MyMod/Games/SpaceRace/spiffo.png`, the sprite of Spiffo, and every other picture your game draws ([Screen and art](03-screen-and-art.md)).
- The texture of the 3D model and the inventory icon, which `tools/cartridge_label.py` writes from your label. Given a fourth path, it also writes the picture of your mod, to copy as `poster.png` next to each `mod.info` and as `preview.png`:

```
python tools/cartridge_label.py ".../ui/MyMod/Games/SpaceRace/label.png" ".../textures/MyMod/MyModCartridge_SpaceRace.png" ".../textures/Item_MyMod_Cartridge_SpaceRace.png" ".../poster.png"
```

## Give the item a name

The inventory name of an item comes from `media/lua/shared/Translate/<LANG>/ItemName.json` of your mod. When your mod has no `lua/shared/Translate/EN/ItemName.json` yet, the tool writes it with the English name; when it has one, the tool leaves it alone and prints the line to add. The file reads:

```json
{
    "MyMod.Cartridge_SpaceRace": "Space Race Cartridge"
}
```

The key is the full type of the item: the module, a dot, the item name. [Texts and translations](06-texts-and-translations.md#item-names) covers the other languages.

## Run it

Enable your mod next to SpiffBoy (and the SDK, for the developer menu), start a solo game and open the **SpiffBoy SDK** window. Your cartridge has its own row, with your mod id in brackets. Take it **In a console** and play it: it is Hello SpiffBoy under your own name.

On the keyboard, the buttons your game reads are, by default: the directions on the movement keys of the character (W, A, S and D), A on L, B on P and Start on Space. Escape puts the console away, and Caps Lock takes it back while it is still switched on. The key bindings of the game options change them.

When the game hits an error, the console freezes and the reason is written in `C:\Users\<you>\Zomboid\console.txt`. [Testing](09-testing.md) shows how to read it, and how the robot finds most mistakes before you start the game.

Next: [How a cartridge works](02-how-a-cartridge-works.md).

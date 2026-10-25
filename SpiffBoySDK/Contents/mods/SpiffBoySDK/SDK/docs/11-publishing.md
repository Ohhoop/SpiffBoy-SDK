# 11. Publishing

## Before you publish

- [ ] The robot says `ok` for every game on several seeds and in every language, with `most calls` well under 300 (`run_all.py` runs three seeds, then each language of your games).
- [ ] `check_texts.py` reports no problem.
- [ ] Every text the player reads comes from `Translate/<LANG>.json`, and `EN.json` is complete.
- [ ] The item has a name in `Translate/EN/ItemName.json`, an icon and a 3D model wearing your label (`cartridge_label.py`).
- [ ] The `loot` weight is the one you want: 0 keeps the cartridge out of the world.
- [ ] You played it in the game from start to end, including on a new cartridge with an empty save.
- [ ] If it plays on the cable, you played a two player game with a second player.
- [ ] `mod.info` requires SpiffBoy, and every id of the definition points at your mod, not at the SDK.
- [ ] The definition gives `api = 1`, its own `art` and `texts` folders, and an `id`, an `item` and a `game` class no other mod uses ([The definition](02-how-a-cartridge-works.md#the-definition)).
- [ ] The item script gives `Tags = base:hasmetal;spiffboy:cartridge`, and `console.txt` holds no line about your cartridge after a game starts ([Dismantling](08-the-cartridge-item.md#dismantling)).
- [ ] Your mod does not depend on the SDK: the SDK is a tool for you, not for your players.

## mod.info

The `mod.info` of [Getting started](01-getting-started.md#create-your-own-mod), line by line:

| Line | Meaning |
|---|---|
| `id` | The id of your mod. It must be unique on the Workshop and must never change after the first release: servers, saves and other mods know your mod by it. It is also the value of `MyMod.MOD_ID` in your `Core.lua`. |
| `name` | The name shown in the mod list. |
| `description` | One or two sentences for the mod list. |
| `modversion` | Your version number ([Versions](#versions)). |
| `require` | The mods loaded before yours, each prefixed with a backslash and separated by commas (`require=\SpiffBoy,\OtherMod`). `\SpiffBoy` makes the registry of cartridges exist before your cartridge registers. If a required mod is missing, the game does not load yours. |
| `poster`, `icon` | Pictures in the same folder as `mod.info`, shown in the mod list. |
| `versionMin` | The oldest build of the game your mod runs on. |

The same file goes in `Contents/mods/MyMod/` and in `Contents/mods/MyMod/42/`.

## Folder layout

A complete mod with one cartridge, `SpaceRace`:

```
Zomboid/Workshop/MyMod/
    preview.png                                  Workshop picture, 256x256
    Contents/mods/MyMod/
        mod.info
        poster.png
        42/
            mod.info
            poster.png
            media/
                lua/
                    shared/
                        MyMod/
                            Core.lua                             MyMod.MOD_ID
                            Games/SpaceRace/
                                Definition.lua                   registers the cartridge
                                Translate/EN.json                texts of the game
                                Translate/FR.json
                        Translate/
                            EN/ItemName.json                     item names of the mod
                            FR/ItemName.json
                    client/
                        MyMod/Games/SpaceRace/
                            Game.lua                             the game class
                            Music.lua                            the tunes
                ui/
                    MyMod/Games/SpaceRace/
                        label.png                                colour label, 388x212
                        hero.png                                 masks and layered sheets
                textures/
                    Item_MyMod_Cartridge_SpaceRace.png           inventory icon, 64x64
                    MyMod/MyModCartridge_SpaceRace.png           texture of the 3D model
                scripts/
                    MyMod/
                        SpaceRace.txt                            the cartridge item and its 3D model
```

One mod can hold several cartridges: a folder per game under `Games/`, a script per item, and all their names in the same `ItemName.json`.

The tools, the tests and your art sources stay out of the mod folder: only `Contents` reaches the players.

## Uploading to the Workshop

Upload the folder `Zomboid/Workshop/MyMod`, with `preview.png` and `Contents` as above, as real files rather than a junction or a link. The game uploads it itself:

1. In the main menu, click **WORKSHOP**, then **Create and update items**.
2. Choose the folder of your mod among the folders of `Zomboid/Workshop`.
3. Fill in the title, the description, the tags and the visibility. **Unlisted** or **Hidden** lets you check the page before everyone sees it.
4. For the first upload, choose **This is a new workshop item**: Steam gives the item its Workshop ID. For every later upload, choose **This is an existing workshop item I want to update** and enter that ID.
5. Write the change notes, then click **Upload to Steam Workshop now!**.

The uploader checks the folder first: everything must sit inside `Contents`, each mod needs a valid `mod.info`, and some file types, such as `.exe`, `.bat` or `.zip`, are refused.

On the Steam page of your item, add SpiffBoy as a required item, and say in the description that the mod needs SpiffBoy, where the cartridge can be found, and whether it plays on the link cable.

## Versions

Write your version in `modversion` and in the change notes of each upload. A simple scheme: `1.0.0` for the first release, the last number for fixes, the middle one for new features, the first one for changes that break something.

Once players have your cartridge, some things must never change:

| Never change | Why |
|---|---|
| The `id` of `mod.info` | Saves and servers know your mod by it. |
| The full type of the item, `MyMod.Cartridge_SpaceRace` | Cartridges and consoles in the world store it; under a new type the console no longer finds their game. |
| The `id` of the cartridge | The tunes and the texts are found by it. |
| The meaning of a field of the save | Old cartridges keep their old save ([Saving](05-saving.md#changing-the-save-between-versions)). |
| A text key | Renaming it loses every translation of it. |

The code, the art and the music can change freely, and new tunes, texts and save fields can be added.

## Versions of the framework

The `api` field of your definition is the version of the SpiffBoy framework your game is written for, not the version of your mod: leave it at 1 when your mod changes. SpiffBoy follows two rules ([Versions of the framework](02-how-a-cartridge-works.md#versions-of-the-framework)):

- A new version of the framework never removes or reduces anything an older version offers. A change that would break existing games creates a new version, and SpiffBoy keeps accepting every older one, so a cartridge published with `api = 1` keeps working with every later SpiffBoy.
- A player whose SpiffBoy is older than the `api` of your cartridge gets an error naming your cartridge and both versions, instead of a game that breaks halfway.

## A development copy and a public copy

Keep two copies of your mod to test changes without touching the version players use: a `MyMod-DEV` folder with `id=MyMod-DEV` and `MyMod.MOD_ID = "MyMod-DEV"`, never published, and the public `MyMod`. Only `mod.info` and `MOD_ID` differ; everything else uses the namespace, which stays the same. Never enable both copies at once: SpiffBoy refuses a cartridge whose id another mod already registered, so the second copy stops with an error at registration.

Next: [Spiff-Pong walkthrough](12-spiff-pong-walkthrough.md).

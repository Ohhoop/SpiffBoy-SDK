# 6. Texts and translations

Every text the player reads goes through a translation file, never through a string written in the code. A game written this way can be translated into the 29 languages of Project Zomboid without touching its Lua.

## One file per language

The texts of a game live in the `texts` folder of its definition, one JSON file per language, named after the language code:

```
media/lua/shared/MyMod/Games/SpaceRace/Translate/
    EN.json
    FR.json
    DE.json
    ...
```

The English file of Hello SpiffBoy:

```json
{
    "UI": {
        "Title": "HELLO SPIFFBOY",
        "Play": "PLAY",
        "MusicOn": "MUSIC: ON",
        "MusicOff": "MUSIC: OFF",
        "Best": "BEST %1",
        "Count": "HELLOS %1",
        "Hello": "HELLO!",
        "HintButtons": "A HELLO  B MUSIC",
        "HintStart": "START MENU"
    }
}
```

- The texts sit in a section named `"UI"`, the only one the console reads. A language file without it, or a file that is not valid JSON, stops the game with an error the first time a text is asked in that language; the error names the game, the language, the file and the mod.
- A key is a short name of letters, digits and underscores, starting with a letter: `Play`, `MusicOn`, `Best`. Once the game is translated, a key never changes.
- Save the files in UTF-8 and write accented letters as they are: `"Jouer"`, `"Spielen"`, `"Играть"`.
- `EN.json` is the reference: every key exists there.

## Reading a text

At the top of your game file, ask for the text function of your game by its id:

```lua
require "SpiffBoy/Framework/GameTexts"

local gameText = SpiffBoy.GameTexts.of("HelloSpiffBoy")
```

Then every text is a call:

```lua
screen:textCentre(gameText("Title"), centre, 6, ink(1))
```

`gameText(key)` returns the text of the key in the language of the player. Each language file is read the first time a text is asked in that language, then kept.

## Arguments

A text can hold places for values, `%1` to `%9`, filled by the values given after the key:

```json
"Best": "BEST %1",
"WonLost": "WON %1  LOST %2"
```

```lua
gameText("Best", self.best)
text("WonLost", self.records.wins, self.records.losses)
```

- A whole number is written without decimals: `3`, never `3.0`. Other values are written with `tostring`.
- A missing value leaves the place empty.
- `%%` writes a percent sign: `"SOUND %1%%"` gives `SOUND 80%`.

Each language can put the value where its grammar wants it. Give the translator the whole sentence with its places; never build a sentence from pieces in the code.

## English as the fallback

When the language of the player has no file for your game, or its file lacks a key, the English text is used. When `EN.json` lacks the key too, the key itself is drawn and the log says once:

```
SpiffBoy: the game HelloSpiffBoy has no text Hi
```

A game with only `EN.json` therefore runs in every language, in English.

## The language codes

The file name is the language code: `EN`, `AR`, `CA`, `CH`, `CN`, `CS`, `DA`, `DE`, `ES`, `ES_CL`, `ES_MX`, `FI`, `FR`, `HU`, `ID`, `IT`, `JP`, `KO`, `NL`, `NO`, `PL`, `PT`, `PTBR`, `RO`, `RU`, `STREW`, `TH`, `TR`, `UA`. The text files of Hello SpiffBoy hold all 29 and show which language each code is; note that `AR` holds Spanish of Argentina, not Arabic.

## Fitting the screen

A translation is often longer than the English text, and the screen is 180 pixels wide. Measure texts with `screen:textWidth`, cut long ones with `screen:wrapText` ([Screen and art](03-screen-and-art.md#textwidth-lineheight-and-wraptext)), and tell your translators the room they have, such as "12 letters at most" for a menu entry. A longer text also costs more draw calls.

## Item names

The name of the cartridge item in the inventory is not a text of the game. It comes from `media/lua/shared/Translate/<LANG>/ItemName.json` of your mod, one file per language, which maps the full type of each item to its name:

```
media/lua/shared/Translate/EN/ItemName.json
media/lua/shared/Translate/FR/ItemName.json
```

```json
{
    "MyMod.Cartridge_SpaceRace": "Space Race Cartridge"
}
```

These files belong to the whole mod: when it holds several cartridges, all their names go in the same file.

## Checking your texts

`tools/check_texts.py` reads the text files and the Lua files of every game of your mod, without running them:

```
python tools/check_texts.py "C:/Users/<you>/Zomboid/Workshop/MyMod/Contents/mods/MyMod/42/media"
```

```
MyMod/SpaceRace: ok  3 Lua files, 8 literal keys, 0 prefixes, 2 computed keys not checked
1 games checked, 0 with problems
```

It reports a file that is not valid JSON in UTF-8, a key written twice, an `EN.json` without its `"UI"` section, the keys each language lacks or has in excess compared with `EN.json`, and every `gameText("Key")` of your code whose key is absent from `EN.json`. A key computed at run time, such as `gameText(hint)`, cannot be checked and is counted as computed: make sure every value it can take exists in `EN.json`.

The tool is stricter than the console on purpose: the console falls back to English for a missing key, the tool lists it, so you see what each language still lacks. [Tools reference](13-tools-reference.md#check_textspy) has the details.

Next: [The link cable](07-link-cable.md).

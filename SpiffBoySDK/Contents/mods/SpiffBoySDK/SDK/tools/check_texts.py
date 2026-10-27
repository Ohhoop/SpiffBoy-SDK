"""Checks the texts of every cartridge of a mod: the language files of each game and the keys its Lua code asks for.

For every game folder lua/shared/<Namespace>/Games/<Id>/ holding a Definition.lua, it reads Translate/<LANG>.json and checks that:
    every file is valid JSON named after a language (EN, FR, PTBR, ES_MX...), an object of sections holding only texts,
    with no key repeated, EN.json holds an "UI" section, the section SpiffBoy.GameTexts reads,
    every other language holds exactly the sections and keys of EN.json, and reports the missing and the extra ones,
    every key the Lua files of the game ask for in a literal, gameText("Key"), exists in the "UI" section of EN.json,
    and every literal prefix, gameText("Item_" .. id), starts at least one key of it,
    the files call SpiffBoy.GameTexts.of with the id of the game and no other id,
    no text with letters is drawn straight from a literal, screen:text("GAME OVER"), or from a constant holding one,
    local OVER = "GAME OVER" then screen:text(OVER), or local LABELS = { over = "GAME OVER" } then screen:text(LABELS.over),
    instead of a language file,
    and lua/shared/Translate/EN/ItemName.json gives a name to the item of the definition.
The Lua scan is static and best effort: it follows the names given to SpiffBoy.GameTexts.of("<Id>") in the files under
lua/client, lua/shared and lua/server <Namespace>/Games/<Id>/, and the locals copied from them, and counts the calls whose
key is computed, which it cannot check.

The line printed for each game counts its Lua files, the different literal keys its code asks for and the calls asking for
them (a key asked in three places is one key and three calls), the calls with a literal prefix, the calls with a computed
key, and the keys of the "UI" section of EN.json, which may hold more keys than the code asks for literally.

Usage:
    python check_texts.py <mod media folder> [--games A,B]

Examples:
    python check_texts.py "C:/Users/me/Zomboid/Workshop/MyMod/Contents/mods/MyMod/42/media"
    python check_texts.py .../MyMod/42/media --games MyGame
"""

import argparse
import json
import re
import sys
from pathlib import Path

REFERENCE = "EN"
SECTION = "UI"
LANGUAGE = re.compile(r"^[A-Z]+(_[A-Z]+)?$")
KEY = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
TEXTS_OF = re.compile(r"""^[ \t]*(local[ \t]+)?([A-Za-z_][\w.]*)[ \t]*=[ \t]*(?:SpiffBoy\.)?GameTexts\.of\([ \t]*(?:"([^"]*)"|'([^']*)'|([A-Za-z_]\w*))[ \t]*\)""", re.M)
CONSTANT = re.compile(r"""^[ \t]*(?:local[ \t]+)?([A-Za-z_]\w*)[ \t]*=[ \t]*(?:"([^"]*)"|'([^']*)')[ \t]*$""", re.M)
COPY = re.compile(r"^[ \t]*(local[ \t]+)?([A-Za-z_][\w.]*)[ \t]*=[ \t]*([A-Za-z_][\w.]*)[ \t]*$", re.M)
WRITTEN_TEXT = re.compile(r""":(?:text|textCentre|textRight|wrapText)[ \t]*\([ \t]*(?:"([^"\\\n]*)"|'([^'\\\n]*)')""")
WRITTEN_NAME = re.compile(r""":(?:text|textCentre|textRight|wrapText)[ \t]*\([ \t]*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)[ \t]*[,)]""")
TABLE_CONSTANT = re.compile(r"""^[ \t]*(?:local[ \t]+)?([A-Za-z_]\w*)[ \t]*=[ \t]*\{([^{}]*)\}""", re.M)
TABLE_FIELD = re.compile(r"""([A-Za-z_]\w*)[ \t]*=[ \t]*(?:"([^"\\\n]*)"|'([^'\\\n]*)')""")
LETTER = re.compile(r"[^\W\d_]")
ITEM_FIELD = re.compile(r"""^[ \t]*item[ \t]*=[ \t]*["']([^"']+)["']""", re.M)
ITEM_NAMES = Path("lua") / "shared" / "Translate" / "EN" / "ItemName.json"
SIDES = ("client", "shared", "server")


class TextError(Exception):
    """Reports a language file that cannot be read."""


def reject_duplicates(pairs):
    """Builds a JSON object and raises when a key appears twice."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise TextError(f"key {key} repeated")
        result[key] = value
    return result


def read_language(path):
    """Reads one language file and returns its sections, or raises with the first problem found."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicates)
    except UnicodeDecodeError as error:
        raise TextError(f"not UTF-8, {error}") from error
    except json.JSONDecodeError as error:
        raise TextError(f"invalid JSON, {error}") from error
    if not isinstance(data, dict):
        raise TextError("the file must hold an object of sections")
    for section, entries in data.items():
        if not isinstance(entries, dict):
            raise TextError(f"section {section} must be an object")
        for key, text in entries.items():
            if not KEY.match(key):
                raise TextError(f"invalid key {section}.{key}")
            if not isinstance(text, str):
                raise TextError(f"{section}.{key} must be a text")
    return data


def check_languages(folder):
    """Returns the problems of the language files of a game and the UI keys of its EN.json."""
    if not folder.is_dir():
        return [f"no folder {folder}"], None
    problems, languages = [], {}
    for path in sorted(folder.iterdir()):
        if path.suffix != ".json" or not path.is_file() or not LANGUAGE.match(path.stem):
            problems.append(f"{path.name}: not a language file <LANG>.json")
            continue
        try:
            languages[path.stem] = read_language(path)
        except TextError as error:
            problems.append(f"{path.name}: {error}")
    if REFERENCE not in languages:
        problems.append(f"no valid {REFERENCE}.json")
        return problems, None
    reference = languages[REFERENCE]
    if SECTION not in reference:
        problems.append(f"{REFERENCE}.json has no \"{SECTION}\" section")
    for language, data in sorted(languages.items()):
        for section in sorted(set(reference) | set(data)):
            expected, found = set(reference.get(section, {})), set(data.get(section, {}))
            if section not in data:
                problems.append(f"{language}.json: missing section {section}")
            elif section not in reference:
                problems.append(f"{language}.json: section {section} absent from {REFERENCE}.json")
            else:
                if expected - found:
                    problems.append(f"{language}.json: missing {section} keys {', '.join(sorted(expected - found))}")
                if found - expected:
                    problems.append(f"{language}.json: extra {section} keys {', '.join(sorted(found - expected))}")
    return problems, set(reference.get(SECTION, {}))


def lua_files(media, namespace, game):
    """Returns the Lua files of a game under the client, shared and server folders of its namespace."""
    files = []
    for side in SIDES:
        files += sorted((media / "lua" / side / namespace / "Games" / game).rglob("*.lua"))
    return files


def text_names(files, game):
    """Returns the names given to the text function of the game, shared by every file of the game and local to each file, and the calls of SpiffBoy.GameTexts.of that name another id, with their place."""
    shared, local, others = set(), {}, []
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        constants = {m.group(1): m.group(2) if m.group(2) is not None else m.group(3) for m in CONSTANT.finditer(text)}
        names = set()
        for match in TEXTS_OF.finditer(text):
            target = match.group(3) if match.group(3) is not None else match.group(4)
            if target is None:
                target = constants.get(match.group(5))
            if target != game:
                others.append((target, f"{path.name}:{text.count(chr(10), 0, match.start()) + 1}"))
                continue
            if match.group(1) and "." not in match.group(2):
                names.add(match.group(2))
            else:
                shared.add(match.group(2))
        local[path] = names
    texts = {path: path.read_text(encoding="utf-8", errors="replace") for path in files}
    grown = True
    while grown:
        grown = False
        for path in files:
            for match in COPY.finditer(texts[path]):
                if match.group(3) not in shared | local[path]:
                    continue
                into = local[path] if match.group(1) and "." not in match.group(2) else shared
                if match.group(2) not in into:
                    into.add(match.group(2))
                    grown = True
    return shared, local, others


def written_texts(files):
    """Returns the texts with letters that the files draw straight from a literal, or from a constant of the same file holding one, a plain one or a field of a table of constants, without a language file, with the place of each."""
    found = []
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        constants = {m.group(1): m.group(2) if m.group(2) is not None else m.group(3) for m in CONSTANT.finditer(text)}
        for table in TABLE_CONSTANT.finditer(text):
            for field in TABLE_FIELD.finditer(table.group(2)):
                constants[f"{table.group(1)}.{field.group(1)}"] = field.group(2) if field.group(2) is not None else field.group(3)
        for match in WRITTEN_TEXT.finditer(text):
            literal = match.group(1) if match.group(1) is not None else match.group(2)
            if LETTER.search(literal):
                found.append((literal, f"{path.name}:{text.count(chr(10), 0, match.start()) + 1}"))
        for match in WRITTEN_NAME.finditer(text):
            literal = constants.get(match.group(1))
            if literal is not None and LETTER.search(literal):
                found.append((literal, f"{path.name}:{text.count(chr(10), 0, match.start()) + 1}"))
    return found


def item_name_problems(media, namespace, game):
    """Returns the problems of the inventory name of the item of a game: no English item names file, or no name in it for the item of its definition."""
    definition = media / "lua" / "shared" / namespace / "Games" / game / "Definition.lua"
    item = ITEM_FIELD.search(definition.read_text(encoding="utf-8", errors="replace"))
    if not item:
        return ["Definition.lua: no item = \"Module.Name\" field to check the inventory name of"]
    names = media / ITEM_NAMES
    if not names.is_file():
        return [f"no {ITEM_NAMES.as_posix()}: the item {item.group(1)} has no name in the inventory"]
    try:
        entries = json.loads(names.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        return [f"{ITEM_NAMES.as_posix()}: cannot be read, {error}"]
    if not isinstance(entries, dict) or item.group(1) not in entries:
        return [f"{ITEM_NAMES.as_posix()}: no name for the item {item.group(1)}"]
    return []


def asked_keys(files, shared, local):
    """Returns the literal keys, the literal prefixes and the number of computed keys the files ask the text function for, with the place of each."""
    keys, prefixes, computed = [], [], 0
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        for name in sorted(shared | local[path]):
            call = re.compile(r"(?<![\w.:])" + re.escape(name) + r"""[ \t]*\([ \t]*(?:"([^"\\\n]*)"|'([^'\\\n]*)')?([ \t]*\.\.)?""")
            for match in call.finditer(text):
                literal = match.group(1) if match.group(1) is not None else match.group(2)
                line = text.count("\n", 0, match.start()) + 1
                place = f"{path.name}:{line}"
                if literal is None:
                    computed += 1
                elif match.group(3):
                    prefixes.append((literal, place))
                else:
                    keys.append((literal, place))
    return keys, prefixes, computed


def check_game(media, namespace, game):
    """Returns the problems of the texts of one game and a line summing up what was checked."""
    problems, english = check_languages(media / "lua" / "shared" / namespace / "Games" / game / "Translate")
    problems += item_name_problems(media, namespace, game)
    files = lua_files(media, namespace, game)
    shared, local, others = text_names(files, game)
    for target, place in others:
        problems.append(f"{place}: SpiffBoy.GameTexts.of(\"{target}\") reads the texts of {target}, not of this game, {game}")
    for literal, place in written_texts(files):
        problems.append(f"{place}: the text \"{literal}\" is written in the code: put it in {REFERENCE}.json and draw gameText(\"<Key>\")")
    if not shared and not any(local.values()):
        if english:
            problems.append(f"{REFERENCE}.json holds {len(english)} keys, but no Lua file of the game calls SpiffBoy.GameTexts.of(\"{game}\"), so none is drawn")
        return problems, f"{len(files)} Lua files, none calls SpiffBoy.GameTexts.of(\"{game}\")"
    keys, prefixes, computed = asked_keys(files, shared, local)
    if english is not None:
        for key, place in keys:
            if key not in english:
                problems.append(f"{place}: key {key} absent from {REFERENCE}.json")
        for prefix, place in prefixes:
            if not any(key.startswith(prefix) for key in english):
                problems.append(f"{place}: no key of {REFERENCE}.json starts with {prefix}")
    held = "no" if english is None else len(english)
    asked = len({key for key, _ in keys})
    return problems, (f"{len(files)} Lua files, {asked} literal keys asked in {len(keys)} calls, {len(prefixes)} prefix calls,"
                      f" {computed} computed calls not checked, {held} keys in {REFERENCE}.json")


def main():
    """Checks the texts of every game of the mod, prints one line per game and its problems, and exits with an error when any is found."""
    parser = argparse.ArgumentParser(description="Checks the per game texts of a SpiffBoy cartridge mod.")
    parser.add_argument("mod", type=Path, help="media folder of the mod")
    parser.add_argument("--games", default="", help="comma separated ids of the games to check")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    shared = args.mod / "lua" / "shared"
    games = sorted((p.parent.parent.parent.name, p.parent.name) for p in shared.glob("*/Games/*/Definition.lua"))
    if args.games:
        wanted = set(args.games.split(","))
        unknown = wanted - {game for _, game in games}
        if unknown:
            print(f"check_texts: no game {', '.join(sorted(unknown))} in {shared}", file=sys.stderr)
            return 1
        games = [(namespace, game) for namespace, game in games if game in wanted]
    if not games:
        print(f"check_texts: no lua/shared/<Namespace>/Games/<Id>/Definition.lua under {args.mod}", file=sys.stderr)
        return 1
    failed = 0
    for namespace, game in games:
        problems, summary = check_game(args.mod, namespace, game)
        print(f"{namespace}/{game}: {'ok' if not problems else 'FAIL'}  {summary}")
        for problem in problems:
            print(f"    {problem}")
        failed += bool(problems)
    print(f"{len(games)} games checked, {failed} with problems")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

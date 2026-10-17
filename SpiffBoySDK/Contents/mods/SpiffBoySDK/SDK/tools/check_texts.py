"""Checks the texts of every cartridge of a mod: the language files of each game and the keys its Lua code asks for.

For every game folder lua/shared/<Namespace>/Games/<Id>/ holding a Definition.lua, it reads Translate/<LANG>.json and checks that:
    every file is valid JSON named after a language (EN, FR, PTBR, ES_MX...), an object of sections holding only texts,
    with no key repeated, EN.json holds an "UI" section, the section SpiffBoy.GameTexts reads,
    every other language holds exactly the sections and keys of EN.json, and reports the missing and the extra ones,
    every key the Lua files of the game ask for in a literal, gameText("Key"), exists in the "UI" section of EN.json,
    and every literal prefix, gameText("Item_" .. id), starts at least one key of it.
The Lua scan is static and best effort: it follows the names given to SpiffBoy.GameTexts.of("<Id>") in the files under
lua/client, lua/shared and lua/server <Namespace>/Games/<Id>/, and the locals copied from them, and counts the calls whose
key is computed, which it cannot check.

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
    """Returns the names given to the text function of the game: shared by every file of the game, and local to each file."""
    shared, local = set(), {}
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        constants = {m.group(1): m.group(2) if m.group(2) is not None else m.group(3) for m in CONSTANT.finditer(text)}
        names = set()
        for match in TEXTS_OF.finditer(text):
            target = match.group(3) if match.group(3) is not None else match.group(4)
            if target is None:
                target = constants.get(match.group(5))
            if target != game:
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
    return shared, local


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
    files = lua_files(media, namespace, game)
    shared, local = text_names(files, game)
    if not shared and not any(local.values()):
        return problems, f"{len(files)} Lua files, none calls SpiffBoy.GameTexts.of(\"{game}\")"
    keys, prefixes, computed = asked_keys(files, shared, local)
    if english is not None:
        for key, place in keys:
            if key not in english:
                problems.append(f"{place}: key {key} absent from {REFERENCE}.json")
        for prefix, place in prefixes:
            if not any(key.startswith(prefix) for key in english):
                problems.append(f"{place}: no key of {REFERENCE}.json starts with {prefix}")
    return problems, f"{len(files)} Lua files, {len(keys)} literal keys, {len(prefixes)} prefixes, {computed} computed keys not checked"


def main():
    """Checks the texts of every game of the mod, prints one line per game and its problems, and exits with an error when any is found."""
    parser = argparse.ArgumentParser(description="Checks the per game texts of a SpiffBoy cartridge mod.")
    parser.add_argument("mod", type=Path, help="media folder of the mod")
    parser.add_argument("--games", default="", help="comma separated ids of the games to check")
    args = parser.parse_args()
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

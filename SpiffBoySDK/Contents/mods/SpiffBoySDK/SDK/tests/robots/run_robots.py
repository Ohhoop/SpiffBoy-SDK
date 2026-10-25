"""Plays every cartridge of a mod offline on top of SpiffBoy with a robot pressing seeded random buttons, and reports for each game its crash, its busiest frame in draw calls and a digest of everything it drew and played.

Usage:
    python run_robots.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--seed N] [--games A,B] [--lang LANG] [--json out.json] [--compare reference.json]

A media folder is the media folder of a mod, such as .../mods/SpiffBoy/42/media. Every game folder of the mod holding a
Definition.lua (lua/shared/<Namespace>/Games/<Id>/Definition.lua) is played. The robot holds or taps a seeded random button on
each tick, and now and then pauses one to five seconds without any button. Two runs with the same ticks and seed give the same
digests when the games behave the same; --compare fails on any digest that differs from the reference. --lang plays in another
language of the game, such as FR or JP (EN unless given), with the texts of that language, so the draw calls count them.

A game fails with CRASH when a file of it fails to load, when its game class is missing, or when it raises an error; it fails
with WARN when it asks for a picture no file has with exactly that name, letter case included, asks for a text missing in
English, or draws a text past an edge of the screen. math.random stops the game: only self.random repeats a game.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
COMMENT = re.compile(r"/\*.*?\*/", re.S)
BLOCK = re.compile(r"\b(module|item)\s+(\w+)\s*\{")
TAGS = re.compile(r"\bTags\s*=\s*([^,\n]+)")
FRAMEWORK = Path("lua") / "shared" / "SpiffBoy" / "Framework" / "Cartridges.lua"


def require_spiffboy(media):
    """Stops the test with a message naming the folder when it is not the media folder of the SpiffBoy mod, which every test loads."""
    if not (media / FRAMEWORK).is_file():
        sys.exit(f"{media} is not the media folder of the SpiffBoy mod: it has no {FRAMEWORK.as_posix()}. "
                 "Give the 42/media folder of SpiffBoy, the mod the SDK requires.")


def require_mod(media):
    """Stops the test with a message naming the folder when it is not the media folder of a mod, with a mod.info next to it."""
    if not (media.parent / "mod.info").is_file():
        sys.exit(f"{media} is not the media folder of a mod: there is no mod.info in {media.parent}. "
                 "Give the 42/media folder of your mod, next to its mod.info.")


def mod_id(media):
    """Returns the id of the mod a media folder belongs to, read from the mod.info next to it."""
    text = (media.parent / "mod.info").read_text(encoding="utf-8")
    return re.search(r"^id=(.+)$", text, re.M).group(1).strip()


def games_of(media):
    """Returns the folders of the games of a mod, as the paths its files require them by, such as SpiffBoySDK/Games/HelloSpiffBoy."""
    shared = media / "lua" / "shared"
    return sorted(p.parent.relative_to(shared).as_posix() for p in shared.glob("*/Games/*/Definition.lua"))


def english_texts(*medias):
    """Returns the English UI texts of the given mods by key."""
    texts = {}
    for media in medias:
        path = media / "lua" / "shared" / "Translate" / "EN" / "UI.json"
        if path.exists():
            texts.update(json.loads(path.read_text(encoding="utf-8")))
    return texts


def mod_files(*medias):
    """Returns the path of every file of the given mods, as the game names them: the folder of the mod, a slash, then the path from it, letter case kept."""
    files = {}
    for media in medias:
        folder = media.parent
        prefix = str(folder).replace("\\", "/") + "/"
        for path in folder.rglob("*"):
            if path.is_file():
                files[prefix + path.relative_to(folder).as_posix()] = True
    return files


def block_end(text, start):
    """Returns the index just past the brace that closes the block whose opening brace ends right before the given index."""
    depth = 1
    index = start
    while depth and index < len(text):
        depth += {"{": 1, "}": -1}.get(text[index], 0)
        index += 1
    return index


def item_scripts(media):
    """Returns the tags of every item the scripts of a mod define, by full type such as MyMod.Cartridge_SpaceRace."""
    items = {}
    for path in (media / "scripts").rglob("*.txt"):
        text = COMMENT.sub("", path.read_text(encoding="utf-8", errors="replace"))
        module = None
        module_end = 0
        index = 0
        while (found := BLOCK.search(text, index)):
            if found.start() >= module_end:
                module = None
            end = block_end(text, found.end())
            if found.group(1) == "module":
                module, module_end = found.group(2), end
                index = found.end()
                continue
            if module:
                body = text[found.end():end - 1]
                tags = TAGS.search(body)
                items[f"{module}.{found.group(2)}"] = [tag.strip() for tag in tags.group(1).split(";")] if tags else []
            index = end
    return items


def namespaces(media):
    """Returns the names of the folders of a mod under lua/shared, lua/client and lua/server, the first part of the paths its files require."""
    lua = media / "lua"
    return sorted({p.name for side in ("shared", "client", "server") if (lua / side).is_dir() for p in (lua / side).iterdir() if p.is_dir()})


def load_preamble(lua, spiffboy, mod, language):
    """Loads the preamble of the robots in the given Lua runtime, the given mod and SpiffBoy giving its code, its files, its item scripts and the English texts of the console, and returns the loader of further Lua files."""
    roots = lua.table_from([str(mod / "lua").replace("\\", "/"), str(spiffboy / "lua").replace("\\", "/")])
    folders = lua.table_from({mod_id(media): str(media.parent).replace("\\", "/") for media in (spiffboy, mod)})
    load = lua.eval("function(path, ...) local f = assert(loadfile(path)); return f(...) end")
    load(str(HERE / "preamble.lua"), roots, folders, language, lua.table_from(mod_files(spiffboy, mod)))
    robot = lua.globals().ROBOT
    robot.texts = lua.table_from(english_texts(spiffboy, mod))
    robot.itemScripts = lua.table_from({name: lua.table_from(tags) for name, tags in item_scripts(mod).items()})
    robot.namespaces = lua.table_from({name: True for name in namespaces(mod)})
    return load


def play(spiffboy, mod, games, ticks, seed, language):
    """Plays the given games of the mod on top of SpiffBoy and returns one result per game, with the number of texts the console asked for and did not find."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    state = {"hash": None}

    def begin_game(game_id):
        state["hash"] = hashlib.sha1()

    def digest(chunk):
        state["hash"].update(chunk.encode("utf-8"))
        state["hash"].update(b"|")

    def end_game():
        return state["hash"].hexdigest()

    load = load_preamble(lua, spiffboy, mod, language)
    robot = lua.globals().ROBOT
    robot.beginGame = begin_game
    robot.digest = digest
    robot.endGame = end_game
    results = load(str(HERE / "cartridges.lua"), lua.table_from(games), ticks, seed)
    out = []
    for i in range(1, len(results) + 1):
        row = results[i]
        out.append({key: row[key] for key in ("id", "most", "frames", "saves", "crash", "offScreen", "warnings", "expected", "digest")})
    return out, robot.missingTexts


def main():
    """Runs the robots, prints one line per game and exits with an error when a game crashed, warned or, with --compare, behaved differently from the reference."""
    parser = argparse.ArgumentParser()
    parser.add_argument("spiffboy")
    parser.add_argument("mod")
    parser.add_argument("--ticks", type=int, default=20000)
    parser.add_argument("--seed", type=int, default=12345)
    parser.add_argument("--games", default="")
    parser.add_argument("--lang", default="EN")
    parser.add_argument("--json", default="")
    parser.add_argument("--compare", default="")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    spiffboy, mod = Path(args.spiffboy), Path(args.mod)
    require_spiffboy(spiffboy)
    require_mod(mod)
    games = games_of(mod)
    if args.games:
        wanted = set(args.games.split(","))
        games = [g for g in games if g.rsplit("/", 1)[1] in wanted]
    results, missing = play(spiffboy, mod, games, args.ticks, args.seed, args.lang)
    reference = {}
    if args.compare:
        reference = {row["id"]: row for row in json.loads(Path(args.compare).read_text(encoding="utf-8"))["games"]}
    failed = False
    for row in results:
        verdict = "ok"
        if row["crash"] and not row["expected"]:
            verdict, failed = "CRASH", True
        elif row["warnings"] or row["offScreen"]:
            verdict, failed = "WARN", True
        same = ""
        if reference:
            ref = reference.get(row["id"])
            if ref is None:
                same = "  (not in reference)"
            elif ref["digest"] == row["digest"] and ref["frames"] == row["frames"]:
                same = "  same as reference"
            else:
                same = "  DIFFERS FROM REFERENCE"
                failed = True
        print(f"{row['id']:<14} {verdict:<6} frames {row['frames']:>6}  most calls {row['most']:>3}  saves {row['saves']:>4}  {row['digest'][:12]}{same}  {row['crash']}")
        if row["offScreen"]:
            print(f"    text off screen: {row['offScreen']}")
        if row["warnings"]:
            for warning in row["warnings"].split(" | "):
                print(f"    {warning}")
    print(f"console texts missing: {missing}")
    if args.json:
        Path(args.json).write_text(json.dumps({"ticks": args.ticks, "seed": args.seed, "games": results}, indent=1), encoding="utf-8")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

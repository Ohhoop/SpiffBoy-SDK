"""Plays every cartridge of a mod offline on top of SpiffBoy with a robot pressing seeded random buttons, and reports for each game its crash, its busiest frame in draw calls and a digest of everything it drew and played.

Usage:
    python run_robots.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--seed N] [--games A,B] [--lang LANG] [--json out.json] [--compare reference.json] [--state]

A media folder is the media folder of a mod, such as .../mods/SpiffBoy/42/media. Every game folder of the mod holding a
Definition.lua (lua/shared/<Namespace>/Games/<Id>/Definition.lua) is played. The robot holds or taps a seeded random button on
each tick, START only about once a minute, and now and then pauses one to five seconds without any button. Two runs with the same ticks and seed give the same
digests when the games behave the same; --compare fails on any digest that differs from the reference. --lang plays in another
language of the game, such as FR or JP (EN unless given), with the texts of that language, so the draw calls count them.

A game fails with CRASH when a file of it fails to load, when its game class is missing, or when it raises an error; it fails
with WARN when it asks for a picture no file has with exactly that name, letter case included, asks for a text missing in
English, draws a text past an edge of the screen or over another text, or has a text in the language played holding a character
the pixel font lacks. math.random stops the game: only self.random repeats a game.

--state then freezes each game that did not crash at ticks 600, 2400 and 6000 of a run of its own, as the console does when
another player takes it, restores it in a second Lua, and fails when the restored game does not play on exactly as the first
one (DIFF) or when the console cannot freeze it (FREEZE).
"""

import argparse
import hashlib
import json
import re
import sys
import time
from pathlib import Path

import lupa.lua51 as lupa
from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
STATE_TICKS = (600, 2400, 6000)
VERIFY_TICKS = 60
CONTINUE_TICKS = 1200
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
import screen_image  # noqa: E402
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


def lua_calls(calls):
    """Returns the draw calls of a frame recorded in Lua as Python lists, in order."""
    return [[call[j] for j in range(1, len(call) + 1)] for call in (calls[i] for i in range(1, len(calls) + 1))]


def load_preamble(lua, spiffboy, mod, language):
    """Loads the preamble of the robots in the given Lua runtime, the given mod and SpiffBoy giving its code, its files, its item scripts and the English texts of the console, and returns the loader of further Lua files."""
    roots = lua.table_from([str(mod / "lua").replace("\\", "/"), str(spiffboy / "lua").replace("\\", "/")])
    folders = lua.table_from({mod_id(media): str(media.parent).replace("\\", "/") for media in (spiffboy, mod)})
    load = lua.eval("function(path, ...) local f = assert(loadfile(path)); return f(...) end")
    load(str(HERE / "preamble.lua"), roots, folders, language, lua.table_from(mod_files(spiffboy, mod)))
    robot = lua.globals().ROBOT
    robot.imageSize = screen_image.image_size
    robot.cellInk = screen_image.cell_ink
    robot.renderFrame = lambda calls, out: screen_image.render(lua_calls(calls), out)
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
        out.append({key: row[key] for key in ("id", "most", "frames", "saves", "crash", "offScreen", "warnings", "expected", "digest", "unplayed", "unasked", "noted")})
    return out, robot.missingTexts


def state_lua(spiffboy, mod, language):
    """Returns a fresh Lua with the robot preamble, the given mod and SpiffBoy loaded, and the save state driver: the driver, the digest it feeds and the Lua itself."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    holder = {"hash": hashlib.sha1()}

    def digest(chunk):
        holder["hash"].update(chunk.encode("utf-8"))
        holder["hash"].update(b"|")

    load = load_preamble(lua, spiffboy, mod, language)
    lua.globals().ROBOT.digest = digest
    return load(str(HERE / "state.lua")), holder, lua


def from_lua(value):
    """Returns a Lua value as Python data: tables as dicts keyed by their Lua keys."""
    if lupa.lua_type(value) == "table":
        return {from_lua(key): from_lua(item) for key, item in value.items()}
    return value


def to_lua(lua, value):
    """Returns Python data made by from_lua as Lua values of the given Lua."""
    if isinstance(value, dict):
        table = lua.table()
        for key, item in value.items():
            table[to_lua(lua, key)] = to_lua(lua, item)
        return table
    return value


def check_states(spiffboy, mod, games, ticks, seed, language):
    """Freezes every given game at each tick of STATE_TICKS the run reaches, restores it in a second Lua, compares the fingerprints after VERIFY_TICKS ticks without buttons and the digests of the next CONTINUE_TICKS ticks, prints one line per check and returns true when every check holds; a game that crashes before a check fails it."""
    passed = True
    for folder in games:
        game_id = folder.rsplit("/", 1)[1]
        for at in STATE_TICKS:
            if at > ticks:
                continue
            first, first_digest, _ = state_lua(spiffboy, mod, language)
            console = first.start(folder, seed)
            crash = "init" if console is None else None
            if console is not None:
                rng, crash = first.play(console, at, seed)
            if crash:
                print(f"{game_id:<14} CRASH  state at tick {at:>5}  {crash}")
                passed = False
                break
            try:
                started = time.perf_counter()
                data = first.capture(console)
                spent = (time.perf_counter() - started) * 1000
                size = first.size(data)
                first_print = first.fingerprintAhead(console, VERIFY_TICKS)
                second, second_digest, second_lua = state_lua(spiffboy, mod, language)
                restored = second.restore(folder, seed, to_lua(second_lua, from_lua(data)))
                second_print = second.fingerprintAhead(restored, VERIFY_TICKS)
            except Exception as error:
                print(f"{game_id:<14} FREEZE state at tick {at:>5}")
                print(f"    {str(error).splitlines()[0]}")
                passed = False
                continue
            first_digest["hash"] = hashlib.sha1()
            second_digest["hash"] = hashlib.sha1()
            first.play(console, CONTINUE_TICKS, rng)
            second.play(restored, CONTINUE_TICKS, rng)
            problem = None
            if first_print != second_print:
                problem = f"the restored game reached another state after {VERIFY_TICKS} ticks without buttons"
            elif first_digest["hash"].hexdigest() != second_digest["hash"].hexdigest():
                problem = f"the restored game drew or played differently in the {CONTINUE_TICKS} ticks after"
            verdict = "DIFF" if problem else "ok"
            print(f"{game_id:<14} {verdict:<6} state at tick {at:>5}  tables {size:>6}  capture {spent:>6.1f} ms")
            if problem:
                print(f"    [SB-STATE-DIFF] {problem} (docs/09-testing.md, The save state check)")
                passed = False
    return passed


def main():
    """Runs the robots, prints one line per game and exits with an error when a game crashed, warned, with --compare behaved differently from the reference, or with --state did not play on the same from its save state."""
    parser = argparse.ArgumentParser()
    parser.add_argument("spiffboy")
    parser.add_argument("mod")
    parser.add_argument("--ticks", type=int, default=20000)
    parser.add_argument("--seed", type=int, default=12345)
    parser.add_argument("--games", default="")
    parser.add_argument("--lang", default="EN")
    parser.add_argument("--json", default="")
    parser.add_argument("--compare", default="")
    parser.add_argument("--state", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    spiffboy, mod = Path(args.spiffboy), Path(args.mod)
    require_spiffboy(spiffboy)
    require_mod(mod)
    games = games_of(mod)
    if not games:
        sys.exit(f"{mod} holds no cartridge: no lua/shared/<Namespace>/Games/<Id>/Definition.lua under it. "
                 "Give the 42/media folder of your mod, the one that holds lua, ui and scripts.")
    if args.games:
        wanted = set(args.games.split(","))
        games = [g for g in games if g.rsplit("/", 1)[1] in wanted]
        if not games:
            sys.exit(f"no game {args.games} among the cartridges of {mod}")
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
        if not row["crash"]:
            if row["saves"] == 0:
                print("    note: the robot never reached a save of this game; check the saves with a test of your own (docs/09-testing.md, Writing a test of your own)")
            if row["unplayed"]:
                print(f"    note: the robot never played the tunes {row['unplayed']}; check them in a test of your own (docs/09-testing.md, Writing a test of your own)")
            if row["noted"]:
                print(f"    note: the console warned {row['noted']}; the robot plays faster than a player, so check that the game saves only at the moments the player sees (docs/05-saving.md, When to save)")
            if row["unasked"]:
                print(f"    note: the robot never asked for the texts {row['unasked']}; check them in a test of your own (docs/09-testing.md, Writing a test of your own)")
    print(f"console texts missing: {missing}")
    if args.state:
        played = [folder for folder, row in zip(games, results) if not row["crash"]]
        if not check_states(spiffboy, mod, played, args.ticks, args.seed, args.lang):
            failed = True
    if args.json:
        Path(args.json).write_text(json.dumps({"ticks": args.ticks, "seed": args.seed, "games": results}, indent=1), encoding="utf-8")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

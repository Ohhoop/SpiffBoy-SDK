"""Plays every cartridge of a mod offline on top of SpiffBoy with a robot pressing seeded random buttons, and reports for each game its crash, its busiest frame in draw calls and a digest of everything it drew and played.

Usage:
    python run_robots.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--seed N] [--games A,B] [--json out.json] [--compare reference.json]

A media folder is the media folder of a mod, such as .../mods/SpiffBoy/42/media. Every game folder of the mod holding a
Definition.lua (lua/shared/<Namespace>/Games/<Id>/Definition.lua) is played. Two runs with the same ticks and seed give the same
digests when the games behave the same; --compare fails on any digest that differs from the reference.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
MAX_CALLS = 300


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


def play(spiffboy, mod, games, ticks, seed):
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

    roots = lua.table_from([str(mod / "lua").replace("\\", "/"), str(spiffboy / "lua").replace("\\", "/")])
    folders = lua.table_from({mod_id(media): str(media.parent).replace("\\", "/") for media in (spiffboy, mod)})
    load = lua.eval("function(path, ...) local f = assert(loadfile(path)); return f(...) end")
    load(str(HERE / "preamble.lua"), roots, folders)
    robot = lua.globals().ROBOT
    robot.texts = lua.table_from(english_texts(spiffboy, mod))
    robot.beginGame = begin_game
    robot.digest = digest
    robot.endGame = end_game
    results = load(str(HERE / "cartridges.lua"), lua.table_from(games), ticks, seed)
    out = []
    for i in range(1, len(results) + 1):
        row = results[i]
        out.append({key: row[key] for key in ("id", "most", "frames", "saves", "crash", "expected", "digest")})
    return out, robot.missingTexts


def main():
    """Runs the robots, prints one line per game and exits with an error when a game crashed, went past the draw call limit or, with --compare, behaved differently from the reference."""
    parser = argparse.ArgumentParser()
    parser.add_argument("spiffboy")
    parser.add_argument("mod")
    parser.add_argument("--ticks", type=int, default=20000)
    parser.add_argument("--seed", type=int, default=12345)
    parser.add_argument("--games", default="")
    parser.add_argument("--json", default="")
    parser.add_argument("--compare", default="")
    args = parser.parse_args()
    spiffboy, mod = Path(args.spiffboy), Path(args.mod)
    games = games_of(mod)
    if args.games:
        wanted = set(args.games.split(","))
        games = [g for g in games if g.rsplit("/", 1)[1] in wanted]
    results, missing = play(spiffboy, mod, games, args.ticks, args.seed)
    reference = {}
    if args.compare:
        reference = {row["id"]: row for row in json.loads(Path(args.compare).read_text(encoding="utf-8"))["games"]}
    failed = False
    for row in results:
        verdict = "ok"
        if row["crash"] and not row["expected"]:
            verdict, failed = "CRASH", True
        if row["most"] > MAX_CALLS:
            verdict, failed = "OVER CALLS", True
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
    print(f"console texts missing: {missing}")
    if args.json:
        Path(args.json).write_text(json.dumps({"ticks": args.ticks, "seed": args.seed, "games": results}, indent=1), encoding="utf-8")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

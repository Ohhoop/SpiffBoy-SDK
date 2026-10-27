"""Runs a test of your own, written in Lua with tests/lib/test_console.lua, on a cartridge of a mod, offline on top of SpiffBoy.

Usage:
    python run_test.py <SpiffBoy media folder> <mod media folder> <test.lua> [--lang LANG]

The test file starts its cartridge with TestConsole.start, plays it with press, hold and wait, and checks what it expects with
TestConsole.check. --lang plays it in another language of the game, such as FR (EN unless given). The warnings of the console
count as failures, as in the robot: a text drawn off screen, missing art, a text missing in English, a letter the font lacks.
A screenshot path given relative is taken from the folder of the test file.
The runner prints every failed check and warning, then one line with the number of checks and failures, and exits with 1 when
a check failed, a warning came up or the test itself stopped on an error.

Example:
    python run_test.py ".../mods/SpiffBoy/42/media" ".../mods/MyMod/42/media" ".../MyMod/tests/race_test.lua" --lang FR
"""

import argparse
import sys
from pathlib import Path

from lupa.lua51 import LuaError, LuaRuntime

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE / "robots"))
import run_robots  # noqa: E402
import screen_image  # noqa: E402

LIBRARY = HERE / "lib" / "test_console.lua"


def run(spiffboy, mod, test, language):
    """Loads the preamble of the robots in the given language, the test console and the test, runs the test and returns its number of checks and failures, a warning of the console counting as a failure; stops with the error that interrupted the test."""
    run_robots.require_spiffboy(spiffboy)
    run_robots.require_mod(mod)
    lua = LuaRuntime(unpack_returned_tuples=True)
    load = run_robots.load_preamble(lua, spiffboy, mod, language)
    folder = test.resolve().parent
    lua.globals().ROBOT.renderFrame = lambda calls, out: screen_image.render(run_robots.lua_calls(calls), folder / out)
    load(str(LIBRARY))
    try:
        load(str(test))
    except LuaError as error:
        sys.exit(f"{test.name}: the test stopped: {error}")
    console = lua.globals().TestConsole
    warnings = lua.globals().ROBOT.warnings
    for i in range(1, len(warnings) + 1):
        print(f"WARN {warnings[i]}")
    return console.checks, console.failures + len(warnings)


def main():
    """Runs the test given on the command line and exits with 1 when a check failed or a warning came up."""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Runs a test of your own on a cartridge of a mod.")
    parser.add_argument("spiffboy", type=Path, help="media folder of the SpiffBoy mod")
    parser.add_argument("mod", type=Path, help="media folder of the mod under test")
    parser.add_argument("test", type=Path, help="the test, a Lua file written with tests/lib/test_console.lua")
    parser.add_argument("--lang", default="EN", help="language the game reads its texts in, such as FR")
    args = parser.parse_args()
    checks, failures = run(args.spiffboy, args.mod, args.test, args.lang)
    print(f"{args.test.name} ({args.lang}): {checks} checks, {failures} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

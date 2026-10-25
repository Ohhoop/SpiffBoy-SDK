"""Runs a test of your own, written in Lua with tests/lib/test_console.lua, on a cartridge of a mod, offline on top of SpiffBoy.

Usage:
    python run_test.py <SpiffBoy media folder> <mod media folder> <test.lua>

The test file starts its cartridge with TestConsole.start, plays it with press, hold and wait, and checks what it expects with
TestConsole.check. The runner prints every failed check, then one line with the number of checks and failures, and exits with 1
when a check failed or the test itself stopped on an error.

Example:
    python run_test.py ".../mods/SpiffBoy/42/media" ".../mods/MyMod/42/media" ".../MyMod/tests/race_test.lua"
"""

import sys
from pathlib import Path

from lupa.lua51 import LuaError, LuaRuntime

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "robots"))
import run_robots  # noqa: E402

LIBRARY = HERE / "lib" / "test_console.lua"


def run(spiffboy, mod, test):
    """Loads the preamble of the robots, the test console and the test, runs the test and returns its number of checks and failures, or stops with the error that interrupted it."""
    run_robots.require_spiffboy(spiffboy)
    run_robots.require_mod(mod)
    lua = LuaRuntime(unpack_returned_tuples=True)
    load = run_robots.load_preamble(lua, spiffboy, mod, "EN")
    load(str(LIBRARY))
    try:
        load(str(test))
    except LuaError as error:
        sys.exit(f"{test.name}: the test stopped: {error}")
    console = lua.globals().TestConsole
    return console.checks, console.failures


def main():
    """Runs the test given on the command line and exits with 1 when a check failed."""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    checks, failures = run(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
    print(f"{Path(sys.argv[3]).name}: {checks} checks, {failures} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

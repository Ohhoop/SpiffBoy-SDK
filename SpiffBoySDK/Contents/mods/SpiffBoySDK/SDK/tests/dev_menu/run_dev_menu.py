"""Runs the offline checks of the SpiffBoy SDK developer menu with lupa.

Usage:
    python run_dev_menu.py <SpiffBoy media folder> <SDK media folder>

Exits with an error when any check fails.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "robots"))
import run_robots  # noqa: E402

from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
SIDES = ("shared", "client", "server")


def main():
    """Loads the harness with the module reader of both mods, runs it and exits with its failure count."""
    spiffboy, sdk = Path(sys.argv[1]), Path(sys.argv[2])
    run_robots.require_spiffboy(spiffboy)
    roots = [media / "lua" / side for media in (sdk, spiffboy) for side in SIDES]

    def read_module(name):
        """Returns the source of the Lua module at the given require path, or None."""
        for root in roots:
            path = root / (name + ".lua")
            if path.is_file():
                return path.read_text(encoding="utf-8")
        return None

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().read_module = read_module
    failures = lua.execute((HERE / "dev_menu.lua").read_text(encoding="utf-8"))
    sys.exit(1 if failures != 0 else 0)


if __name__ == "__main__":
    main()

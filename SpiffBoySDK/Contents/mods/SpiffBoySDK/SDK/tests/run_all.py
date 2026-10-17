"""Runs every offline test suite of the SpiffBoy SDK on a mod and prints one ok, FAIL or skip line per suite.

The suites are the robots of tests/robots/run_robots.py, played once per seed of SEEDS, the text checker tools/check_texts.py,
and the runners of SDK_SUITES, which take <SpiffBoy media folder> <mod media folder> and test a part of the SDK itself: each one
runs only on a mod holding the folder it tests, and is skipped on any other mod. Each suite runs in its own process; a suite fails
when it exits with an error.

Usage:
    python run_all.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--verbose]

--ticks sets the ticks each robot plays per game (20000 unless given); --verbose prints the output of every suite,
otherwise only the output of the suites that fail is printed, after the summary.

Examples:
    python run_all.py ".../mods/SpiffBoy/42/media" ".../mods/SpiffBoySDK/42/media"
    python run_all.py ".../mods/SpiffBoy/42/media" ".../mods/MyMod/42/media" --ticks 5000 --verbose
"""

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROBOTS = HERE / "robots" / "run_robots.py"
CHECK_TEXTS = HERE.parent / "tools" / "check_texts.py"
SEEDS = (12345, 2718, 31337)
SDK_SUITES = {
    "dev_menu/run_dev_menu": "lua/client/SpiffBoySDK/DevMenu",
    "spiff_pong/run_link_test": "lua/client/SpiffBoySDK/Games/SpiffPong",
}


def suites(spiffboy, mod, ticks):
    """Returns the name and command line of every suite, with None as the command line of a suite the mod does not hold: the robots once per seed, the text checker, then the SDK suites."""
    found = [(f"robots seed {seed}", [sys.executable, str(ROBOTS), str(spiffboy), str(mod), "--ticks", str(ticks), "--seed", str(seed)]) for seed in SEEDS]
    found.append(("check_texts", [sys.executable, str(CHECK_TEXTS), str(mod)]))
    for name, tested in SDK_SUITES.items():
        command = None
        if (mod / tested).is_dir():
            command = [sys.executable, str(HERE / (name + ".py")), str(spiffboy), str(mod)]
        found.append((name, command))
    return found


def main():
    """Runs every suite, prints one line per suite and the output of the failed ones, and exits with an error when any failed."""
    parser = argparse.ArgumentParser(description="Runs every offline test suite of the SpiffBoy SDK.")
    parser.add_argument("spiffboy", type=Path, help="media folder of the SpiffBoy mod")
    parser.add_argument("mod", type=Path, help="media folder of the mod under test")
    parser.add_argument("--ticks", type=int, default=20000, help="ticks each robot plays per game")
    parser.add_argument("--verbose", action="store_true", help="print the output of every suite")
    args = parser.parse_args()
    for folder in (args.spiffboy, args.mod):
        if not (folder.parent / "mod.info").is_file():
            print(f"run_all: {folder} is not the media folder of a mod, no mod.info next to it", file=sys.stderr)
            return 1
    failed = []
    for name, command in suites(args.spiffboy, args.mod, args.ticks):
        if command is None:
            print(f"skip  {name}", flush=True)
            continue
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
        verdict = "ok  " if result.returncode == 0 else "FAIL"
        print(f"{verdict}  {name}", flush=True)
        output = (result.stdout + result.stderr).rstrip()
        if args.verbose and output:
            print("    " + output.replace("\n", "\n    "))
        if result.returncode != 0:
            failed.append((name, output))
    if not args.verbose:
        for name, output in failed:
            print(f"\n--- {name} ---\n{output}")
    print(f"\n{len(failed)} suites failed" if failed else "\nall suites passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

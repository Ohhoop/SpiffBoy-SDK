"""Runs every offline test suite of the SpiffBoy SDK on a mod and prints one ok, FAIL or skip line per suite.

The suites are the robots of tests/robots/run_robots.py, played once per seed of SEEDS in English, then once more with the first
seed in each other language a game of the mod has a text file for, the text checker tools/check_texts.py, every test of the mod
itself (<Workshop folder of the mod>/tests/*_test.lua, next to Contents, run with tests/run_test.py), and the runners of SDK_SUITES, which take <SpiffBoy media folder> <mod media folder> and test a part of the SDK itself: each one
runs only on a mod holding the folder it tests, and is skipped on any other mod. Each suite runs in its own process; a suite fails
when it exits with an error.

Usage:
    python run_all.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--timeout S] [--verbose]

--ticks sets the ticks each robot plays per game (20000 unless given); --timeout the seconds a suite may run before it is
stopped and fails (900 unless given); --verbose prints the output of every suite, otherwise only the output of the suites that
fail is printed, after the summary; the notes of a suite that passed, such as a game the robot never saw save, are printed
under its line in any case, each note once. Every test of the mod itself runs in English, then once in each other language.

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
RUN_TEST = HERE / "run_test.py"
OWN_TESTS = "tests"
SEEDS = (12345, 2718, 31337)
ENGLISH = "EN"
NOTE = "    note:"
FRAMEWORK = Path("lua") / "shared" / "SpiffBoy" / "Framework" / "Cartridges.lua"
SDK_SUITES = {
    "docs/run_error_codes": "../../SDK/docs",
    "dev_menu/run_dev_menu": "lua/client/SpiffBoySDK/DevMenu",
    "hello/run_round_test": "lua/client/SpiffBoySDK/Games/HelloSpiffBoy",
    "spiff_pong/run_link_test": "lua/client/SpiffBoySDK/Games/SpiffPong",
}


def languages(mod):
    """Returns the languages other than English that a game of the mod has a text file for, sorted."""
    files = (mod / "lua" / "shared").glob("*/Games/*/Translate/*.json")
    return sorted({path.stem for path in files} - {ENGLISH})


def own_tests(mod):
    """Returns the tests of the mod itself: every file ending in _test.lua in the tests folder of its Workshop folder, next to Contents, sorted; none for a mod outside a Contents/mods folder."""
    contents = mod.parents[3]
    if contents.name != "Contents":
        return []
    return sorted((contents.parent / OWN_TESTS).glob("*_test.lua"))


def suites(spiffboy, mod, ticks):
    """Returns the name and command line of every suite, with None as the command line of a suite the mod does not hold: the robots once per seed, then once per other language, the text checker, the tests of the mod itself, then the SDK suites."""
    robot = [sys.executable, str(ROBOTS), str(spiffboy), str(mod), "--ticks", str(ticks)]
    found = [(f"robots seed {seed}", robot + ["--seed", str(seed)]) for seed in SEEDS]
    found += [(f"robots {language}", robot + ["--seed", str(SEEDS[0]), "--lang", language]) for language in languages(mod)]
    found.append(("check_texts", [sys.executable, str(CHECK_TEXTS), str(mod)]))
    for test in own_tests(mod):
        command = [sys.executable, str(RUN_TEST), str(spiffboy), str(mod), str(test)]
        found.append((f"test {test.stem}", command))
        found += [(f"test {test.stem} {language}", command + ["--lang", language]) for language in languages(mod)]
    for name, tested in SDK_SUITES.items():
        command = None
        if (mod / tested).is_dir():
            command = [sys.executable, str(HERE / (name + ".py")), str(spiffboy), str(mod)]
        found.append((name, command))
    return found


def run(command, timeout):
    """Runs one suite in its own process and returns its exit code and output; a suite still running after the given seconds is stopped and fails with a line saying so."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as expired:
        partial = expired.stdout
        if isinstance(partial, bytes):
            partial = partial.decode("utf-8", "replace")
        notice = f"stopped after {timeout} seconds without finishing: a loop that never ends, such as a test waiting for a screen its game never opens"
        return 1, ((partial or "").rstrip() + "\n" + notice).strip()
    return result.returncode, (result.stdout + result.stderr).rstrip()


def main():
    """Runs every suite, prints one line per suite and the output of the failed ones, and exits with an error when any failed."""
    parser = argparse.ArgumentParser(description="Runs every offline test suite of the SpiffBoy SDK.")
    parser.add_argument("spiffboy", type=Path, help="media folder of the SpiffBoy mod")
    parser.add_argument("mod", type=Path, help="media folder of the mod under test")
    parser.add_argument("--ticks", type=int, default=20000, help="ticks each robot plays per game")
    parser.add_argument("--verbose", action="store_true", help="print the output of every suite")
    parser.add_argument("--timeout", type=int, default=900, help="seconds a suite may run before it is stopped and fails")
    args = parser.parse_args()
    for folder in (args.spiffboy, args.mod):
        if not (folder.parent / "mod.info").is_file() or not (folder / "lua").is_dir():
            print(f"run_all: {folder} is not the media folder of a mod: give the 42/media folder, which holds lua and has a mod.info next to it", file=sys.stderr)
            return 1
    if not (args.spiffboy / FRAMEWORK).is_file():
        print(f"run_all: {args.spiffboy} is not the media folder of the SpiffBoy mod: it has no {FRAMEWORK.as_posix()}. "
              "Give the 42/media folder of SpiffBoy, the mod the SDK requires.", file=sys.stderr)
        return 1
    failed = []
    shown = set()
    for name, command in suites(args.spiffboy, args.mod, args.ticks):
        if command is None:
            print(f"skip  {name}", flush=True)
            continue
        returncode, output = run(command, args.timeout)
        verdict = "ok  " if returncode == 0 else "FAIL"
        print(f"{verdict}  {name}", flush=True)
        if args.verbose and output:
            print("    " + output.replace("\n", "\n    "))
        elif returncode == 0:
            for line in output.splitlines():
                if line.startswith(NOTE) and line not in shown:
                    shown.add(line)
                    print(line, flush=True)
        if returncode != 0:
            failed.append((name, output))
    if not args.verbose:
        for name, output in failed:
            print(f"\n--- {name} ---\n{output}")
    print(f"\n{len(failed)} suites failed" if failed else "\nall suites passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

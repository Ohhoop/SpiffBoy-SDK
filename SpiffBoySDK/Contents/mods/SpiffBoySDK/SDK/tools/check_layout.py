"""Checks that the folders of a mod are laid out as the game loads them: everything in common, and in the version folders only the files that differ from one version of the game to another.

Usage:
    python check_layout.py <mod folder>

The mod folder is the folder holding common and the version folders, such as .../mods/MyMod. The game loads common, then one
version folder only: the highest one not above its own version. A file kept in one version folder alone is therefore missing for the
versions of the game that load another one. The check fails when:
- common holds no mod.info, or a version folder holds one;
- the version folder 42, loaded by every version of the game below the next version folder, is missing;
- a file of a version folder is missing from another version folder;
- a file of a version folder is the same in every version folder, so it belongs in common;
- a file of a version folder also exists in common, where the game never reads it;
- common or a version folder lacks one of the media folders the game looks into for every mod, AnimSets and actiongroups.
"""

import re
import sys
from pathlib import Path

COMMON = "common"
BASE_VERSION = "42"
VERSION_NAME = re.compile(r"^\d+(\.\d+)?$")
MOD_INFO = "mod.info"
SEARCHED_FOLDERS = ("media/AnimSets", "media/actiongroups")
PLACEHOLDER = "keep.txt"


def files_of(folder):
    """Returns the files of a folder by their path relative to it."""
    return {path.relative_to(folder).as_posix(): path for path in folder.rglob("*") if path.is_file()}


def is_placeholder(relative):
    """Returns true when the file only keeps a folder the game looks into from being empty."""
    return relative.rsplit("/", 1)[-1] == PLACEHOLDER


def problems_of(mod):
    """Returns the faults of the layout of a mod folder, one line each."""
    problems = []
    common = mod / COMMON
    versions = sorted(path for path in mod.iterdir() if path.is_dir() and VERSION_NAME.match(path.name))
    if not (common / MOD_INFO).is_file():
        problems.append(f"{COMMON}/{MOD_INFO} is missing")
    if not (mod / BASE_VERSION).is_dir():
        problems.append(f"the version folder {BASE_VERSION} is missing")
    common_files = files_of(common) if common.is_dir() else {}
    by_version = {version.name: files_of(version) for version in versions}
    for folder in [common] + versions:
        for searched in SEARCHED_FOLDERS:
            if not (folder / searched).is_dir() or not any((folder / searched).iterdir()):
                problems.append(f"{folder.name}/{searched} is missing or empty")
    every = sorted(set().union(*by_version.values())) if by_version else []
    for relative in every:
        holders = [name for name, files in by_version.items() if relative in files]
        if relative == MOD_INFO:
            problems.append(f"{', '.join(holders)} hold a {MOD_INFO}; it belongs in {COMMON} alone")
            continue
        absent = [name for name in by_version if name not in holders]
        if absent:
            problems.append(f"{relative} is in {', '.join(holders)} but missing from {', '.join(absent)}")
        if is_placeholder(relative):
            continue
        if relative in common_files:
            problems.append(f"{relative} is in {COMMON} and in {', '.join(holders)}; the game never reads the one of {COMMON}")
        contents = {by_version[name][relative].read_bytes() for name in holders}
        if not absent and len(contents) == 1:
            problems.append(f"{relative} is the same in every version folder; it belongs in {COMMON}")
    return problems


def main():
    """Checks the mod folder given on the command line, prints each fault and one verdict line, and exits with an error when a fault was found."""
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    mod = Path(sys.argv[1])
    if not mod.is_dir():
        sys.exit(f"{mod} is not a folder")
    problems = problems_of(mod)
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"layout: {len(problems)} failures")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()

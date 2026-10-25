"""Checks the error codes of SpiffBoy against the documentation of the SDK: every code of the catalog points to a page and a
section that exist, and the table of the error codes lists every code of the catalog and no other.

Usage:
    python run_error_codes.py <SpiffBoy media folder> <SDK media folder>

Prints each problem and a summary line; exits with 1 on any problem.
"""

import re
import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

CATALOG = Path("lua") / "shared" / "SpiffBoy" / "Core" / "GameErrors.lua"
CODES_PAGE = "10-kahlua-and-pitfalls.md"
CODE_ROW = re.compile(r"^\| `(SB-[A-Z-]+)` \|", re.M)
HEADING = re.compile(r"^#+ (.+?)\s*$", re.M)


def catalog(spiffboy):
    """Returns the catalog of the error codes of SpiffBoy as a dictionary of code to the page and the section it points to."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((spiffboy / CATALOG).read_text(encoding="utf-8"))
    entries = {}
    for code, entry in lua.globals().SpiffBoy.GameErrors.CATALOG.items():
        page, _, section = entry.see.partition(", ")
        entries[code] = (page, section)
    return entries


def main():
    """Compares the catalog with the pages of the documentation and prints every difference."""
    spiffboy, sdk = Path(sys.argv[1]), Path(sys.argv[2])
    docs = sdk.parent.parent / "SDK" / "docs"
    entries = catalog(spiffboy)
    problems = []
    for code, (page, section) in sorted(entries.items()):
        path = docs / page
        if not path.exists():
            problems.append(f"{code} points to {page}, which does not exist")
            continue
        if section and section not in HEADING.findall(path.read_text(encoding="utf-8")):
            problems.append(f"{code} points to the section {section} of {page}, which does not exist")
    listed = CODE_ROW.findall((docs / CODES_PAGE).read_text(encoding="utf-8"))
    for code in sorted(set(entries) - set(listed)):
        problems.append(f"{code} is missing from the table of {CODES_PAGE}")
    for code in sorted(set(listed) - set(entries)):
        problems.append(f"{code} is listed in {CODES_PAGE} but not in the catalog")
    for code in sorted({code for code in listed if listed.count(code) > 1}):
        problems.append(f"{code} is listed more than once in {CODES_PAGE}")
    for problem in problems:
        print(problem)
    print(f"error codes: {len(entries)} in the catalog, {len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()

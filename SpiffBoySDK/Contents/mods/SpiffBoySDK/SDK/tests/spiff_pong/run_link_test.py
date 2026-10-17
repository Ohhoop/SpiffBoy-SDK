"""Plays Spiff-Pong on two consoles joined by a simulated link cable, offline on top of SpiffBoy, and checks that both consoles stay in step.

Usage:
    python run_link_test.py <SpiffBoy media folder> <SDK media folder>

Scenarios: cables of 1, 6 and 12 ticks of delay through a whole match, a second player who joins late, a cable pulled in the
middle of a match, and one console alone through a match, its initials and its best scores. A linked match passes when both
consoles computed the same ball, paddles and score after every tick, their checksums agreed, no match waited more than half a
second for the cable, the port never refused a message, and every frame stayed under 300 draw calls. Prints one line per
scenario and a summary line; exits with 1 on any failure.
"""

import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
ROBOTS = HERE.parent / "robots"
sys.path.insert(0, str(ROBOTS))
import run_robots  # noqa: E402

MAX_CALLS = 300

SCENARIOS = [
    {"name": "cable 1 tick", "delay": 1, "frames": 60000},
    {"name": "cable 6 ticks", "delay": 6, "frames": 60000},
    {"name": "cable 12 ticks", "delay": 12, "frames": 60000},
    {"name": "late second player", "delay": 6, "frames": 60000, "lateB": 400},
    {"name": "cable pulled", "delay": 6, "frames": 3000, "cutAt": 600},
    {"name": "alone", "solo": True, "frames": 60000},
]


def run(spiffboy, sdk):
    """Loads the preamble of the robots and the test, plays every scenario and returns the results with the number of missing texts."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    roots = lua.table_from([str(sdk / "lua").replace("\\", "/"), str(spiffboy / "lua").replace("\\", "/")])
    folders = lua.table_from({run_robots.mod_id(media): str(media.parent).replace("\\", "/") for media in (spiffboy, sdk)})
    load = lua.eval("function(path, ...) local f = assert(loadfile(path)); return f(...) end")
    load(str(ROBOTS / "preamble.lua"), roots, folders)
    lua.globals().ROBOT.texts = lua.table_from(run_robots.english_texts(spiffboy, sdk))
    scenarios = lua.table_from([lua.table_from(s) for s in SCENARIOS])
    results = load(str(HERE / "link_test.lua"), scenarios)
    rows = [dict(results[i].items()) for i in range(1, len(SCENARIOS) + 1)]
    return rows, results["missingTexts"]


def verdict(scenario, row):
    """Returns the list of the failures of one scenario."""
    failures = []
    if row["crash"]:
        failures.append("crash " + row["crash"])
    if row["most"] >= MAX_CALLS:
        failures.append(f"{row['most']} draw calls")
    if scenario.get("solo"):
        if not row["sawRecords"] or row["saves"] < 2 or row["records"] < 1 or row["wins"] + row["losses"] != 1:
            failures.append("the match alone did not end on saved best scores")
        return failures
    if row["mismatches"] or row["checksums"]:
        failures.append(f"{row['mismatches']} ticks differ, {row['checksums']} checksum mismatches")
    if row["stalls"]:
        failures.append(f"{row['stalls']} stalled frames")
    if row["refused"]:
        failures.append(f"{row['refused']} messages refused")
    if scenario.get("cutAt"):
        if row["modeA"] != "title" or row["modeB"] != "title" or row["noticeA"] != "CableLost":
            failures.append(f"pulled cable left {row['modeA']}/{row['modeB']}")
        if row["compared"] < 100:
            failures.append("the match did not start before the cable was pulled")
        return failures
    if row["modeA"] != "result" or row["modeB"] != "result":
        failures.append(f"match not finished: {row['modeA']}/{row['modeB']}")
    if row.get("scoreA") != row.get("scoreB") or row["wonA"] == row["wonB"]:
        failures.append("the consoles disagree on the result")
    return failures


def main():
    """Runs the scenarios, prints a line for each and a summary, and exits with 1 on any failure."""
    spiffboy, sdk = Path(sys.argv[1]), Path(sys.argv[2])
    rows, missing = run(spiffboy, sdk)
    failed = 0
    for scenario, row in zip(SCENARIOS, rows):
        failures = verdict(scenario, row)
        failed += bool(failures)
        if scenario.get("solo"):
            detail = f"saves {row['saves']}, wins {row['wins']}, losses {row['losses']}, best scores {row['records']}"
        else:
            detail = (f"delay {row['delay']}, score {row.get('scoreA')}/{row.get('scoreB')}, longest rally {row.get('rally')}, "
                      f"{row['compared']} ticks compared, stalls {row['stalls']}")
        status = "ok" if not failures else "FAIL " + "; ".join(failures)
        print(f"{scenario['name']:<20} {status:<6} frames {row['frames']:>6}  most calls {row['most']:>3}  {detail}")
    print(f"Spiff-Pong link test: {len(SCENARIOS) - failed}/{len(SCENARIOS)} scenarios passed, {missing} missing texts")
    sys.exit(1 if failed or missing else 0)


if __name__ == "__main__":
    main()

"""Plays rounds of Hello SpiffBoy offline on top of SpiffBoy and checks when the game writes its save: never during a round nor when a round is given up, once when the end of a round is confirmed with a button, and only what changed.

Usage:
    python run_round_test.py <SpiffBoy media folder> <SDK media folder>

It runs round_test.lua through tests/run_test.py. Prints the failed checks and a summary line; exits with 1 on any failure.
"""

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE.parent))
import run_test  # noqa: E402


def main():
    """Runs round_test.lua on the SDK and exits with 1 when a check failed."""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    checks, failures = run_test.run(Path(sys.argv[1]), Path(sys.argv[2]), HERE / "round_test.lua", "EN")
    print(f"hello round: {checks} checks, {failures} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

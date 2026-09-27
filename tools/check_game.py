#!/usr/bin/env python3
"""
Check that the game actually runs, and optionally see what it looks like.

Godot exits with code 0 even when scripts crash every frame, so this script runs the
game for a few seconds of game time, reads Godot's log, and gives a short verdict.

Usage:
    python3 tools/check_game.py                               # run main scene 3s headless
    python3 tools/check_game.py --screenshot                  # ...and save .previews/game.png
    python3 tools/check_game.py --hold move_right --hold jump@1-1.2 --seconds 4 --screenshot
    python3 tools/check_game.py --scene res://scenes/level_2.tscn

--hold ACTION[@START[-END]] presses an input action (from project.godot) during the run,
e.g. "jump@0.5-0.6" taps jump at half a second. Without times it's held the whole run.
--screenshot opens a real game window for a moment (a display is required).

Exit code 0 = no errors, 1 = errors found, 2 = could not run Godot at all.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = ROOT / "game"
RUNNER = Path(__file__).resolve().parent / "check_game_runner.gd"
PREVIEW_DIR = ROOT / ".previews"

ERROR_RE = re.compile(r"(SCRIPT ERROR|USER SCRIPT ERROR|^ERROR|Parse Error|CHECK ERROR)")
WARNING_RE = re.compile(r"^(WARNING|USER WARNING)")
# Noise Godot prints in headless/movie runs that says nothing about the game
IGNORE_RE = re.compile(r"(ObjectDB instances leaked|resources still in use at exit|Pages in use exist at exit)")


def find_godot():
    candidates = [os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(Path.home() / "Applications/Godot.app/Contents/MacOS/Godot")]
    for c in candidates:
        if c and Path(c).exists():
            return c
    return None


def parse_hold(spec, seconds):
    action, _, times = spec.partition("@")
    start, end = 0.0, seconds + 1
    if times:
        start_s, _, end_s = times.partition("-")
        start = float(start_s)
        end = float(end_s) if end_s else start + 0.1
    return f"{action}:{start}:{end}"


def summarize(output):
    """Group Godot's log into distinct problems (errors repeat every frame)."""
    errors, warnings = Counter(), Counter()
    lines = output.splitlines()
    for i, line in enumerate(lines):
        if IGNORE_RE.search(line):
            continue
        bucket = errors if ERROR_RE.search(line) else warnings if WARNING_RE.search(line) else None
        if bucket is None:
            continue
        # Keep the "at: file:line" context that follows, it's the useful part
        block = [line.strip()]
        for extra in lines[i + 1:i + 4]:
            if not extra.startswith(" "):
                break
            if "at:" in extra or "res://" in extra:
                block.append(extra.strip())
        bucket["\n    ".join(block)] += 1
    return errors, warnings


def run(cmd, timeout):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=ROOT)
        return result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""  # can be bytes even with text=True
        return None, out.decode(errors="replace") if isinstance(out, bytes) else str(out)


def main():
    parser = argparse.ArgumentParser(description="Check that the Godot game runs without errors")
    parser.add_argument("--scene", help="Scene to run (default: the project's main scene)")
    parser.add_argument("--seconds", type=float, default=3.0, help="Game time to run for (default: 3)")
    parser.add_argument("--hold", action="append", default=[], metavar="ACTION[@START[-END]]",
                        help="Press an input action during the run (repeatable)")
    parser.add_argument("--screenshot", nargs="?", const=str(PREVIEW_DIR / "game.png"), metavar="PATH",
                        help="Save what the screen looks like at the end (default: .previews/game.png)")
    parser.add_argument("--verbose", action="store_true", help="Print Godot's full output")
    args = parser.parse_args()

    godot = find_godot()
    if not godot:
        print("Could not find Godot. Install it, or set the GODOT environment variable to its path.")
        return 2
    if not (GAME_DIR / "project.godot").exists():
        print(f"No Godot project found at {GAME_DIR}")
        return 2

    # Import new/changed assets (sprites, sounds) so the game can load them
    code, output = run([godot, "--headless", "--path", str(GAME_DIR), "--import"], timeout=300)
    import_errors, _ = summarize(output)
    if code is None:
        print("Godot timed out while importing assets.")
        return 2

    user_args = ["--seconds", str(args.seconds)]
    if args.scene:
        user_args += ["--scene", args.scene]
    for spec in args.hold:
        user_args += ["--hold", parse_hold(spec, args.seconds)]
    cmd = [godot, "--path", str(GAME_DIR), "--fixed-fps", "60", "--script", str(RUNNER)]
    if args.screenshot:
        shot = Path(args.screenshot).resolve()
        shot.parent.mkdir(parents=True, exist_ok=True)
        shot.unlink(missing_ok=True)
        user_args += ["--screenshot", str(shot)]
    else:
        cmd.insert(1, "--headless")

    code, output = run(cmd + ["--"] + user_args, timeout=args.seconds * 4 + 30)
    if args.verbose:
        print(output)
    errors, warnings = summarize(output)
    errors = import_errors | errors  # the import pass reports some of the same problems

    if code is None:
        print(f"The game froze: it did not finish {args.seconds}s of game time (infinite loop?).")
        return 1
    if "CHECK: finished" not in output and not errors:
        errors["Godot stopped before the check finished (crash?). Re-run with --verbose."] += 1

    for text, n in warnings.most_common(5):
        print(f"{f'[x{n}] ' if n > 1 else ''}{text}")
    for text, n in errors.most_common(10):
        print(f"{f'[x{n}] ' if n > 1 else ''}{text}")
    if args.screenshot and Path(args.screenshot).exists():
        shot = Path(args.screenshot).resolve()
        print(f"Screenshot: {shot.relative_to(ROOT) if shot.is_relative_to(ROOT) else shot}")

    if errors:
        print(f"FAILED: {sum(errors.values())} error(s) in {len(errors)} place(s).")
        return 1
    print(f"OK: game ran {args.seconds}s with no errors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

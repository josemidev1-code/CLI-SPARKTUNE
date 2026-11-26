"""Verify the startup intro in a Windows pseudo-terminal and export its frames."""
import json
import sys
import time
from pathlib import Path

import pyte
from winpty import PtyProcess


def capture(width, *flags):
    screen = pyte.Screen(width, 20)
    stream = pyte.Stream(screen)
    process = PtyProcess.spawn(
        ["powershell.exe", "-NoProfile", "-File", "sparktune.ps1", "banner", *flags],
        dimensions=(20, width),
    )
    frames = []
    start = time.monotonic()
    while True:
        try:
            output = process.read(4096)
        except EOFError:
            break
        if not output:
            break
        stream.feed(output)
        rows = [row.rstrip() for row in screen.display[:9]]
        colors = [[screen.buffer[y][x].fg for x in range(len(row))] for y, row in enumerate(rows)]
        if not frames or (rows, colors) != (frames[-1]["rows"], frames[-1]["colors"]):
            frames.append({"time": round((time.monotonic() - start) * 1000), "rows": rows, "colors": colors})
    return frames, screen.cursor.hidden


frames, hidden = capture(90)
if len(frames) < 8 or not any("." in row for frame in frames for row in frame["rows"]):
    raise SystemExit(f"The Windows console did not animate. Captured frames: {frames!r}")
if not any("_" in row for frame in frames for row in frame["rows"]):
    raise SystemExit("The credit did not display its typing cursor.")
if not any("brightwhite" in row or "white" in row for frame in frames for row in frame["colors"]):
    raise SystemExit("The reveal did not display its bright edge.")
if hidden or "made by josemidev1" not in " ".join(frames[-1]["rows"]):
    raise SystemExit("The final credit or visible cursor is missing.")
if sum("#" in row for row in frames[-1]["rows"]) != 5:
    raise SystemExit("The logo left extra lines or failed to draw.")
narrow, _ = capture(30)
if "SparkTune" not in " ".join(narrow[-1]["rows"]) or "made by josemidev1" not in " ".join(narrow[-1]["rows"]):
    raise SystemExit("The narrow console did not show the compact logo.")
skipped, _ = capture(90, "--no-banner")
if any(row.strip() for frame in skipped for row in frame["rows"]):
    raise SystemExit("--no-banner emitted banner output.")
Path(sys.argv[1]).write_text(json.dumps(frames), encoding="utf-8")
print(f"ASCII intro verified in a Windows pseudo-terminal: {len(frames)} distinct frames.")

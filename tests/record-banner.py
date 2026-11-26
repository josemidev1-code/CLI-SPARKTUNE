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
        rows = [row.rstrip() for row in screen.display[:12]]
        colors = [[screen.buffer[y][x].fg for x in range(len(row))] for y, row in enumerate(rows)]
        if not frames or (rows, colors) != (frames[-1]["rows"], frames[-1]["colors"]):
            frames.append({"time": round((time.monotonic() - start) * 1000), "rows": rows, "colors": colors})
    return frames, screen.cursor.hidden


frames, hidden = capture(90)
def has(frame, char):
    return any(char in row for row in frame["rows"])


binary = next((i for i, frame in enumerate(frames) if has(frame, "0") and has(frame, "1")), -1)
spark = next((i for i, frame in enumerate(frames) if has(frame, "*")), -1)
if not 0 <= binary < spark:
    raise SystemExit("The binary assembly must precede the spark.")
spark_row = next((row for row in frames[spark]["rows"] if "*" in row), "")
if not 12 <= spark_row.index("*") <= 28:
    raise SystemExit("The spark must appear above the SPARK part of the logo.")
if hidden or "made by josemidev1" not in " ".join(frames[-1]["rows"]):
    raise SystemExit("The final credit or visible cursor is missing.")
final = frames[-1]
if sum("█" in row for row in final["rows"]) != 5 or has(final, "*"):
    raise SystemExit("The final logo must have five block rows and no spark residue.")
colors = {color for row, shades in zip(final["rows"], final["colors"]) for char, color in zip(row, shades) if char == "█"}
if len(colors) < 6:
    raise SystemExit(f"The final logo should carry an RGB gradient. Colors: {colors}")
narrow, _ = capture(30)
if "SparkTune" not in " ".join(narrow[-1]["rows"]) or "made by josemidev1" not in " ".join(narrow[-1]["rows"]):
    raise SystemExit("The narrow console did not show the compact logo.")
skipped, _ = capture(90, "--no-banner")
if any(row.strip() for frame in skipped for row in frame["rows"]):
    raise SystemExit("--no-banner emitted banner output.")
Path(sys.argv[1]).write_text(json.dumps(frames), encoding="utf-8")
print(f"ASCII intro verified in a Windows pseudo-terminal: {len(frames)} distinct frames.")

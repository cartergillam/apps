#!/usr/bin/env python3
"""Inspect decoded pixels, duration and every wraparound step. No networking."""
from pathlib import Path
import sys
from PIL import Image, ImageChops

root = Path(sys.argv[1])
counts = {"layout_nasdaq": 1, "layout_nyse": 1, "layout_tsx": 1, "layout_cad": 1, "layout_long": 1, "layout_missing": 1, "layout_plan": 1, "layout_mixed": 3, "ten": 10, "dotted": 1, "canadian_plan": 1, "aapl": 1, "two": 2, "five": 5, "same_company": 2, "long": 1, "mixed_plan": 2, "aapl_closed": 1, "aapl_stale": 1, "msft": 1, "five_open": 5, "five_closed": 5}
for scenario, count in counts.items():
    path = root / f"ticker-{scenario}.webp"
    with Image.open(path) as image:
        assert image.size == (64, 32), path
        assert image.n_frames == 96 * count, (path, image.n_frames)
        frames, duration = [], 0
        for i in range(image.n_frames):
            image.seek(i)
            frame = image.convert("RGB")
            frames.append(frame)
            assert image.info["duration"] == 55, (path, i, image.info)
            duration += image.info["duration"]
        for i, frame in enumerate(frames):
            following = frames[(i + 1) % len(frames)]
            # Includes last -> first. A full pixel column is the only new data.
            assert ImageChops.difference(frame.crop((1, 0, 64, 32)), following.crop((0, 0, 63, 32))).getbbox() is None, (path, "non-continuous step", i)
        assert duration == 5280 * count
        assert len({frame.tobytes() for frame in frames}) > 90
        if scenario == "five":
            # Each distinct configured listing actually appears in the loop.
            assert len({frames[i * 96].tobytes() for i in range(5)}) == 5
    print(f"{path.name}: {96 * count} frames, {duration} ms, seamless 1px steps")

# Only the fixed right-hand bottom status region may differ between states.
for baseline, variant in [("aapl", "aapl_closed"), ("aapl", "aapl_stale"), ("five_open", "five_closed")]:
    with Image.open(root / f"ticker-{baseline}.webp") as a, Image.open(root / f"ticker-{variant}.webp") as b:
        assert a.n_frames == b.n_frames
        for i in range(a.n_frames):
            a.seek(i); b.seek(i)
            assert ImageChops.difference(a.convert("RGB").crop((0, 0, 64, 25)), b.convert("RGB").crop((0, 0, 64, 25))).getbbox() is None, (variant, "geometry changed", i)
            # Currency stays fixed too, when the logo column is visible.
            if i % 96 == 0:
                assert ImageChops.difference(a.convert("RGB").crop((0, 25, 20, 32)), b.convert("RGB").crop((0, 25, 20, 32))).getbbox() is None
print("OPEN/CLOSED/STALE ticker quote geometry is identical")

# CLOSED is absent from all normal display paths, while STALE is retained.
source = Path("apps/marketwatch/market_watch.star").read_text()
assert '"closed": ""' in source
assert '"closed": "CLOSED"' not in source

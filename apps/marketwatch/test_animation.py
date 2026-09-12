#!/usr/bin/env python3
"""Inspect decoded pixels, duration and every wraparound step. No networking."""
from pathlib import Path
import sys
from PIL import Image, ImageChops

root = Path(sys.argv[1])
counts = {"aapl": 1, "two": 2, "five": 5, "same_company": 2, "long": 1, "mixed_plan": 2}
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
            assert image.info["duration"] == 40, (path, i, image.info)
            duration += image.info["duration"]
        for i, frame in enumerate(frames):
            following = frames[(i + 1) % len(frames)]
            # Includes last -> first. A full pixel column is the only new data.
            assert ImageChops.difference(frame.crop((1, 0, 64, 32)), following.crop((0, 0, 63, 32))).getbbox() is None, (path, "non-continuous step", i)
        assert duration == 3840 * count
        assert len({frame.tobytes() for frame in frames}) > 90
        if scenario == "five":
            # Each distinct configured listing actually appears in the loop.
            assert len({frames[i * 96].tobytes() for i in range(5)}) == 5
    print(f"{path.name}: {96 * count} frames, {duration} ms, seamless 1px steps")

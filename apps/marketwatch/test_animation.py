#!/usr/bin/env python3
"""Inspect decoded pixels, duration and every wraparound step. No networking."""
from pathlib import Path
import sys
import json
from PIL import Image, ImageChops

root = Path(sys.argv[1])
counts = {"density_short": 1, "density_two": 2, "density_five": 5, "density_ten": 10, "layout_nasdaq": 1, "layout_nyse": 1, "layout_tsx": 1, "layout_cad": 1, "layout_long": 1, "layout_missing": 1, "layout_plan": 1, "layout_mixed": 3, "ten": 10, "dotted": 1, "canadian_plan": 1, "aapl": 1, "two": 2, "five": 5, "same_company": 2, "long": 1, "mixed_plan": 2, "aapl_closed": 1, "aapl_stale": 1, "msft": 1, "five_open": 5, "five_closed": 5}
for scenario, count in counts.items():
    path = root / f"ticker-{scenario}.webp"
    with Image.open(path) as image:
        assert image.size == (64, 32), path
        widths = json.loads((root / f"ticker-{scenario}.widths.json").read_text().split("] ", 1)[1])
        assert len(widths) == count
        assert all(36 <= width <= 68 for width in widths), widths
        assert image.n_frames == sum(widths), (path, image.n_frames, widths)
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
        assert duration == 55 * sum(widths)
        assert len({frame.tobytes() for frame in frames}) > 35
        if scenario == "five":
            # Each distinct configured listing actually appears in the loop.
            assert len({frames[sum(widths[:i])].tobytes() for i in range(5)}) == 5
    # Every measured item ends in exactly five deliberate blank columns.
        strip = Image.new("RGB", (len(frames), 32))
        for i, item_frame in enumerate(frames):
            strip.paste(item_frame.crop((0,0,1,32)), (i,0))
        offset = 0
        for width in widths:
            assert strip.crop((offset+width-5,0,offset+width,32)).getbbox() is None
            offset += width
        blank = [strip.crop((i,0,i+1,32)).getbbox() is None for i in range(len(frames))]
        run = longest = 0
        for empty in blank + blank:
            run = run+1 if empty else 0
            longest = max(longest,run)
        assert longest <= 10, (scenario,"oversized visual gap",longest)
    print(f"{path.name}: widths={widths}, {sum(widths)} frames, {duration} ms, seamless 1px steps; gaps <=10px")

assert json.loads((root / "ticker-density_short.widths.json").read_text().split("] ",1)[1])[0] < json.loads((root / "ticker-aapl.widths.json").read_text().split("] ",1)[1])[0]

# Only the fixed bottom logo status region may differ between states.
for baseline, variant in [("aapl", "aapl_closed"), ("aapl", "aapl_stale"), ("five_open", "five_closed")]:
    with Image.open(root / f"ticker-{baseline}.webp") as a, Image.open(root / f"ticker-{variant}.webp") as b:
        assert a.n_frames == b.n_frames
        for i in range(a.n_frames):
            a.seek(i); b.seek(i)
            assert ImageChops.difference(a.convert("RGB").crop((0, 0, 64, 25)), b.convert("RGB").crop((0, 0, 64, 25))).getbbox() is None, (variant, "geometry changed", i)
            # Currency stays fixed too, when the logo column is visible.
            if i == 0:
                assert ImageChops.difference(a.convert("RGB").crop((22, 25, 49, 32)), b.convert("RGB").crop((22, 25, 49, 32))).getbbox() is None
print("OPEN/CLOSED/STALE ticker quote geometry is identical")

# CLOSED is absent from all normal display paths, while STALE is retained.
source = Path("apps/marketwatch/market_watch.star").read_text()
assert '"closed": ""' in source
assert '"closed": "CLOSED"' not in source

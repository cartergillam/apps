#!/usr/bin/env python3
"""Offline pixel regressions for the shared rigid 64x32 quote composition."""
import base64
import io
import json
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageChops

root = Path(sys.argv[1])

def frame(name):
    with Image.open(root / f"{name}.webp") as image:
        assert image.size == (64, 32)
        return image.convert("RGB")

def same(a, b, region=(0, 0, 64, 32)):
    assert ImageChops.difference(a.crop(region), b.crop(region)).getbbox() is None, region

base = frame("layout_nasdaq")
# Exchange metadata must have zero pixel influence in either mode, every frame.
for prefix in ("", "ticker-"):
    for variant in ("layout_nyse", "layout_tsx"):
        with Image.open(root / f"{prefix}layout_nasdaq.webp") as a, Image.open(root / f"{prefix}{variant}.webp") as b:
            assert a.n_frames == b.n_frames
            for index in range(a.n_frames):
                a.seek(index); b.seek(index)
                same(a.convert("RGB"), b.convert("RGB"))
# Focus and ticker start from the identical 64px card, including error cards.
for scenario in ("layout_nasdaq", "layout_nyse", "layout_tsx", "layout_cad", "layout_long", "layout_missing", "layout_plan", "aapl", "msft", "dotted", "canadian_plan"):
    same(frame(scenario), frame("ticker-" + scenario))
# Only the intended fixed slot can change; other content must remain pixel-exact.
same(base, frame("layout_cad"), (0, 0, 64, 25))
same(base, frame("layout_cad"), (36, 25, 64, 32))
same(base, frame("layout_long"), (0, 0, 20, 32))
same(base, frame("layout_long"), (20, 8, 64, 32))
same(base, frame("layout_missing"), (20, 0, 64, 32))
same(base, frame("layout_plan"), (0, 0, 20, 32))
for scenario in ("layout_missing", "canadian_plan"):
    assert frame(scenario).crop((0, 0, 20, 32)).getbbox() == (1, 3, 19, 21), scenario
for scenario in ("layout_nasdaq", "layout_cad", "canadian_plan"):
    assert frame(scenario).crop((20, 25, 36, 32)).getbbox()[0] == 0, scenario
# Fixed symbol anchor (white glyphs start at X20); no clipping at the right edge.
for scenario in ("layout_nasdaq", "layout_long", "layout_plan", "msft", "dotted"):
    image = frame(scenario)
    assert image.crop((20, 0, 64, 8)).getbbox()[0] == 0, scenario
    assert image.crop((63, 0, 64, 32)).getbbox() is None, scenario
# Mixed strip is composed of the same cards at exactly 96-frame boundaries.
with Image.open(root / "ticker-layout_mixed.webp") as mixed:
    for index, scenario in enumerate(("layout_nasdaq", "msft", "canadian_plan")):
        mixed.seek(index * 96)
        same(mixed.convert("RGB"), frame(scenario))
# Synthetic normalized remote logos exercise wide/tall artwork and missing logos
# without acquiring anything over the network. Text coordinates remain unchanged.
quote = {"symbol": "AAPL", "price": 212.48, "absoluteChange": 2.15,
         "percentageChange": 1.02, "currency": "USD", "marketStatus": "open"}
for name, rect in (("remote_wide", (0, 6, 18, 12)), ("remote_tall", (6, 0, 12, 18)), ("remote_box", (0, 0, 18, 18))):
    logo = Image.new("RGBA", (18, 18))
    logo.paste((34, 119, 238, 255), rect)
    data = io.BytesIO(); logo.save(data, format="PNG")
    quote["logoData"] = base64.b64encode(data.getvalue()).decode()
    subprocess.run(["pixlet", "render", "apps/marketwatch/market_watch.star",
                    "$provider_data=" + json.dumps([quote]), "--output", str(root / f"{name}.webp")], check=True)
    same(base, frame(name), (20, 0, 64, 32))
assert frame("remote_box").crop((0, 0, 20, 32)).getbbox() == (1, 3, 19, 21)
# Large numeric values use compact price text, never overflow or resize the card.
quote["price"] = 1234567.89
subprocess.run(["pixlet", "render", "apps/marketwatch/market_watch.star",
                "$provider_data=" + json.dumps([quote]), "--output", str(root / "large_price.webp")], check=True)
image = frame("large_price")
same(base, image, (20, 0, 64, 8))
same(base, image, (20, 18, 64, 32))
assert image.crop((63, 0, 64, 32)).getbbox() is None
print("Rigid logo/text anchors, exchange independence, currency/error slots, aspect ratios and clipping checks passed")

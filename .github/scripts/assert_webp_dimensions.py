#!/usr/bin/env python3
"""Fail when a rendered WebP canvas is not the physical 64x32 target."""

import pathlib
import sys


def dimensions(path: pathlib.Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError("not a WebP file")
    kind = data[12:16]
    if kind == b"VP8X":
        return 1 + int.from_bytes(data[24:27], "little"), 1 + int.from_bytes(data[27:30], "little")
    if kind == b"VP8 " and data[23:26] == b"\x9d\x01\x2a":
        return int.from_bytes(data[26:28], "little") & 0x3FFF, int.from_bytes(data[28:30], "little") & 0x3FFF
    if kind == b"VP8L" and data[20] == 0x2F:
        b1, b2, b3, b4 = data[21:25]
        return 1 + b1 + ((b2 & 0x3F) << 8), 1 + (b2 >> 6) + (b3 << 2) + ((b4 & 0x0F) << 10)
    raise ValueError(f"unsupported WebP chunk {kind!r}")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: assert_webp_dimensions.py FILE...", file=sys.stderr)
        return 2
    failed = False
    for raw in sys.argv[1:]:
        path = pathlib.Path(raw)
        try:
            actual = dimensions(path)
        except (OSError, ValueError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed = True
            continue
        if actual != (64, 32):
            print(f"{path}: expected 64x32, got {actual[0]}x{actual[1]}", file=sys.stderr)
            failed = True
    if failed:
        return 1
    print(f"Verified {len(sys.argv) - 1} render(s) at exactly 64x32")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify a QEMU capture is the centered DINX Plymouth splash, not GRUB."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

BACKGROUND = (11, 13, 18)
GRUB_MENU = re.compile(r"\bstart\s+dinx(?:\s+live|\s*\()|\badvanced\s+options\b", re.IGNORECASE)


def has_grub_menu(text: str) -> bool:
    return GRUB_MENU.search(text) is not None


def has_centered_dinx_logo(width: int, height: int, pixels: bytes) -> tuple[bool, str]:
    if width < 1 or height < 1 or len(pixels) != width * height * 3:
        return False, "invalid PPM dimensions or pixel data"

    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        offset = (y * width + x) * 3
        if any(abs(pixels[offset + channel] - BACKGROUND[channel]) > 8 for channel in range(3)):
            return False, "DINX Plymouth background is absent"

    min_x, min_y = width, height
    max_x = max_y = -1
    red_count = 0
    for y in range(0, height, 2):
        row = y * width * 3
        for x in range(0, width, 2):
            offset = row + x * 3
            red, green, blue = pixels[offset : offset + 3]
            if red >= 150 and green <= 110 and blue <= 180 and red >= green * 1.5:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                red_count += 1

    if red_count < 500:
        return False, "DINX logo pixels are missing"

    logo_width = max_x - min_x + 1
    logo_height = max_y - min_y + 1
    center_x = (min_x + max_x + 1) / (2 * width)
    center_y = (min_y + max_y + 1) / (2 * height)
    width_ratio = logo_width / width
    height_ratio = logo_height / height
    if abs(center_x - 0.5) > 0.09 or abs(center_y - 0.5) > 0.09:
        return False, "DINX logo is not centered like the Plymouth splash"
    if not 0.23 <= width_ratio <= 0.46 or not 0.32 <= height_ratio <= 0.58:
        return False, "DINX logo is not rendered at the Plymouth splash scale"
    return True, "centered DINX logo detected"


def read_ppm(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    header = data.split(b"\n", 3)
    if len(header) != 4 or header[0].strip() != b"P6" or header[2].strip() != b"255":
        raise ValueError("screendump is not a binary PPM with 8-bit RGB pixels")
    dimensions = header[1].split()
    if len(dimensions) != 2:
        raise ValueError("invalid PPM dimensions")
    width, height = (int(value) for value in dimensions)
    pixels = header[3]
    if len(pixels) != width * height * 3:
        raise ValueError("PPM pixel data length does not match its dimensions")
    return width, height, pixels


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print("usage: check_dinx_plymouth_screen.py SCREEN.ppm [TESSERACT_LANG]", file=sys.stderr)
        return 2

    path = Path(argv[1])
    language = argv[2] if len(argv) == 3 else "eng"
    try:
        width, height, pixels = read_ppm(path)
    except (OSError, ValueError) as error:
        print(f"check_dinx_plymouth_screen: {error}", file=sys.stderr)
        return 1

    valid, reason = has_centered_dinx_logo(width, height, pixels)
    if not valid:
        print(f"check_dinx_plymouth_screen: {reason}", file=sys.stderr)
        return 1

    try:
        result = subprocess.run(
            ["tesseract", str(path), "stdout", "-l", language, "--psm", "11"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"check_dinx_plymouth_screen: Tesseract could not inspect {path}: {error}", file=sys.stderr)
        return 1

    if has_grub_menu(result.stdout):
        print("check_dinx_plymouth_screen: capture still shows the GRUB menu", file=sys.stderr)
        return 1
    print(f"check_dinx_plymouth_screen: {reason} without GRUB menu: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

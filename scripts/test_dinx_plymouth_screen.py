# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_dinx_plymouth_screen import (  # noqa: E402
    BACKGROUND,
    has_centered_dinx_logo,
    has_grub_menu,
    read_ppm,
)


def _frame(
    width: int = 800,
    height: int = 600,
    *,
    offset_x: int = 0,
    offset_y: int = 0,
    mark_size: int = 230,
) -> bytes:
    pixels = bytearray(BACKGROUND * (width * height))
    mark_height = 270
    left = (width - mark_size) // 2 + offset_x
    top = (height - mark_height) // 2 + offset_y
    for y in range(top, top + mark_height):
        for x in range(left, left + mark_size):
            dx = (x - left - (mark_size - 1) / 2) / (mark_size / 2)
            dy = (y - top - (mark_height - 1) / 2) / (mark_height / 2)
            outer = dx * dx + dy * dy <= 1
            inner = (dx / 0.55) ** 2 + (dy / 0.62) ** 2 < 1
            if outer and not inner:
                offset = (y * width + x) * 3
                pixels[offset : offset + 3] = b"\xf4\x31\x55"
    return bytes(pixels)


class PlymouthScreenTests(unittest.TestCase):
    def test_accepts_centered_splash_at_theme_scale(self) -> None:
        valid, reason = has_centered_dinx_logo(800, 600, _frame())
        self.assertTrue(valid, reason)
        self.assertEqual(reason, "centered DINX logo detected")

    def test_rejects_logo_in_grub_corner(self) -> None:
        valid, reason = has_centered_dinx_logo(800, 600, _frame(offset_x=110, offset_y=-130))
        self.assertFalse(valid)
        self.assertEqual(reason, "DINX logo is not centered like the Plymouth splash")

    def test_rejects_logo_smaller_than_theme_scale(self) -> None:
        valid, reason = has_centered_dinx_logo(800, 600, _frame(mark_size=120))
        self.assertFalse(valid)
        self.assertEqual(reason, "DINX logo is not rendered at the Plymouth splash scale")

    def test_rejects_missing_theme_background(self) -> None:
        pixels = bytearray(_frame())
        pixels[:3] = b"\x00\x00\x00"
        valid, reason = has_centered_dinx_logo(800, 600, bytes(pixels))
        self.assertFalse(valid)
        self.assertEqual(reason, "DINX Plymouth background is absent")

    def test_rejects_mismatched_pixel_data_length(self) -> None:
        valid, reason = has_centered_dinx_logo(800, 600, b"\x00")
        self.assertFalse(valid)
        self.assertEqual(reason, "invalid PPM dimensions or pixel data")

    def test_ppm_reader_preserves_binary_pixels(self) -> None:
        pixels = _frame()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "splash.ppm"
            path.write_bytes(b"P6\n800 600\n255\n" + pixels)
            self.assertEqual(read_ppm(path), (800, 600, pixels))

    def test_grub_menu_ocr_is_identified(self) -> None:
        self.assertTrue(has_grub_menu("Start DINX Linux"))
        self.assertTrue(has_grub_menu("Boot to the Firmware/BIOS"))
        self.assertTrue(has_grub_menu("Advanced options"))
        self.assertFalse(has_grub_menu("Pearl Greeter"))

    def test_cli_reports_invalid_ppm_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.ppm"
            path.write_bytes(b"not a PPM")
            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("check_dinx_plymouth_screen.py")), str(path)],
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn("screendump is not a binary PPM", result.stderr)


if __name__ == "__main__":
    unittest.main()

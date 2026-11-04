# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(__file__))
from initramfs_manifest import read_initramfs  # noqa: E402


def _cpio(entries: list[tuple[str, bytes]]) -> bytes:
    output = bytearray()
    for inode, (name, payload) in enumerate(entries, start=1):
        encoded_name = name.encode() + b"\0"
        fields = (
            inode,
            0o100644,
            0,
            0,
            1,
            0,
            len(payload),
            0,
            0,
            0,
            0,
            len(encoded_name),
            0,
        )
        output.extend(b"070701")
        output.extend(b"".join(f"{field:08x}".encode() for field in fields))
        output.extend(encoded_name)
        output.extend(b"\0" * (-len(output) % 4))
        output.extend(payload)
        output.extend(b"\0" * (-len(payload) % 4))

    encoded_name = b"TRAILER!!!\0"
    fields = (0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, len(encoded_name), 0)
    output.extend(b"070701")
    output.extend(b"".join(f"{field:08x}".encode() for field in fields))
    output.extend(encoded_name)
    output.extend(b"\0" * (-len(output) % 4))
    return bytes(output)


class InitramfsManifestTests(unittest.TestCase):
    def test_reads_entries_from_both_early_and_compressed_archives(self) -> None:
        early = _cpio([("usr/lib/modules/vboxvideo.ko.zst", b"module")])
        main_archive = _cpio(
            [
                ("init", b"#!/bin/sh"),
                ("usr/bin/plymouthd", b"daemon"),
                ("usr/share/plymouth/themes/dinx/logo.png", b"logo"),
            ]
        ) + b"\0" * 512
        compressed = subprocess.run(
            ["zstd", "--quiet", "--compress", "--stdout"],
            input=main_archive,
            stdout=subprocess.PIPE,
            check=True,
        ).stdout

        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "initramfs.img"
            image.write_bytes(early + b"\0" * 512 + compressed)
            entries = read_initramfs(image)

        self.assertIn("usr/lib/modules/vboxvideo.ko.zst", entries)
        self.assertIn("init", entries)
        self.assertIn("usr/bin/plymouthd", entries)
        self.assertIn("usr/share/plymouth/themes/dinx/logo.png", entries)

    def test_rejects_early_archive_without_main_payload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "initramfs.img"
            image.write_bytes(_cpio([("early_cpio", b"")]))
            with self.assertRaisesRegex(ValueError, "main compressed CPIO is missing"):
                read_initramfs(image)


if __name__ == "__main__":
    unittest.main()

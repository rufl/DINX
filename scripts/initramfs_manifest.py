# SPDX-License-Identifier: Apache-2.0
"""List entries from Artix mkinitcpio's early and compressed CPIO archives."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import BinaryIO

_CPIO_HEADER_SIZE = 110
_CPIO_MAGICS = (b"070701", b"070702")
_ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"


def _read_exact(stream: BinaryIO, size: int, description: str) -> bytes:
    value = stream.read(size)
    if len(value) != size:
        raise ValueError(f"truncated CPIO {description}")
    return value


def _skip_exact(stream: BinaryIO, size: int, description: str) -> None:
    while size:
        chunk = stream.read(min(size, 1024 * 1024))
        if not chunk:
            raise ValueError(f"truncated CPIO {description}")
        size -= len(chunk)


def _require_zero_padding(stream: BinaryIO) -> None:
    while chunk := stream.read(1024 * 1024):
        if any(chunk):
            raise ValueError("unexpected data after the main CPIO trailer")


def _read_cpio(stream: BinaryIO) -> set[str]:
    entries: set[str] = set()
    while True:
        header = _read_exact(stream, _CPIO_HEADER_SIZE, "header")
        if header[:6] not in _CPIO_MAGICS:
            raise ValueError(f"unsupported CPIO magic {header[:6]!r}")
        try:
            file_size = int(header[54:62], 16)
            name_size = int(header[94:102], 16)
        except ValueError as error:
            raise ValueError("invalid CPIO header fields") from error
        if name_size < 1:
            raise ValueError("empty CPIO member name")

        raw_name = _read_exact(stream, name_size, "member name")
        if raw_name[-1:] != b"\0":
            raise ValueError("unterminated CPIO member name")
        _skip_exact(stream, (-(_CPIO_HEADER_SIZE + name_size)) % 4, "name padding")

        name = os.fsdecode(raw_name[:-1]).removeprefix("./")
        _skip_exact(stream, file_size, f"member {name!r}")
        _skip_exact(stream, -file_size % 4, "member padding")
        if name == "TRAILER!!!":
            return entries
        entries.add(name.lstrip("/"))


def read_initramfs(path: Path) -> set[str]:
    """Read paths from the raw early CPIO and appended Zstandard main CPIO."""
    with path.open("rb") as source:
        entries = _read_cpio(source)
        next_byte = source.read(1)
        while next_byte == b"\0":
            next_byte = source.read(1)
        if not next_byte:
            raise ValueError("main compressed CPIO is missing after the early CPIO")
        source.seek(-1, os.SEEK_CUR)
        offset = source.tell()
        if source.read(len(_ZSTD_MAGIC)) != _ZSTD_MAGIC:
            raise ValueError(f"unsupported main initramfs compression at byte {offset}")

    with path.open("rb") as compressed, tempfile.TemporaryFile() as decoded:
        compressed.seek(offset)
        result = subprocess.run(
            ["zstd", "--quiet", "--decompress", "--stdout"],
            stdin=compressed,
            stdout=decoded,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode:
            diagnostic = result.stderr.decode("utf-8", "replace").strip()
            raise ValueError(f"zstd could not decode the main CPIO: {diagnostic}")
        decoded.seek(0)
        entries.update(_read_cpio(decoded))
        _require_zero_padding(decoded)
    return entries


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} INITRAMFS", file=sys.stderr)
        return 2
    try:
        entries = read_initramfs(Path(argv[1]))
    except (OSError, ValueError) as error:
        print(f"initramfs-manifest: {error}", file=sys.stderr)
        return 1
    for entry in sorted(entries):
        print(entry)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

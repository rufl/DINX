#!/usr/bin/env python3
"""Reject runner-dependent installed boot configurations without building an ISO."""
import pathlib
import subprocess
import tempfile
import unittest

CHECK = pathlib.Path(__file__).with_name("check-installed-grub.sh")
UUID = "c06f96cd-f002-4cab-8260-5833da314b0d"
ENTRY = f"\tlinux\t/boot/vmlinuz-linux root=UUID={UUID} rw console=tty0\n"


class InstalledGrub(unittest.TestCase):
    def check_config(self, config):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "grub.cfg"
            path.write_text(config)
            return subprocess.run(["bash", str(CHECK), str(path), UUID],
                                  capture_output=True, text=True).returncode

    def test_target_and_recovery_entries(self):
        self.assertEqual(self.check_config(ENTRY + ENTRY.replace(" rw ", " ro single ")), 0)

    def test_no_kernel(self):
        self.assertNotEqual(self.check_config("set timeout=1\n"), 0)

    def test_host_entry_after_valid_target(self):
        self.assertNotEqual(self.check_config(ENTRY + "linux /vmlinuz-7.0-aws root=UUID=other ro\n"), 0)

    def test_wrong_or_missing_root(self):
        for root in ("root=/dev/nvme0n1p1", "", f"root=UUID={UUID}extra"):
            with self.subTest(root=root):
                self.assertNotEqual(self.check_config(ENTRY.replace(f"root=UUID={UUID}", root)), 0)

    def test_duplicate_root(self):
        self.assertNotEqual(self.check_config(ENTRY.rstrip() + " root=/dev/sda1\n"), 0)

    def test_efi_foreign_entry(self):
        self.assertNotEqual(self.check_config(ENTRY + "linuxefi /vmlinuz-host root=/dev/sda1\n"), 0)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Exercise qualification prerequisite elevation without devices, QEMU or an ISO."""
import os
import pathlib
import subprocess
import tempfile
import unittest

CHECK = pathlib.Path(__file__).with_name("check-iso-qualification-host.sh")


class QualificationHost(unittest.TestCase):
    def probe(self, sudo_status=0, device_present=True):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            root.chmod(0o755)
            bindir = root / "bin"
            bindir.mkdir()
            log = root / "commands.log"
            log.touch(mode=0o666)
            log.chmod(0o666)
            device = root / "loop-control"
            if device_present:
                device.touch()
            firmware = root / "firmware.fd"
            firmware.touch()
            script = root / "check-host.sh"
            # Substitute only the device-node fixture; execute the complete gate.
            script.write_text(CHECK.read_text().replace("/dev/loop-control", str(device)))
            script.chmod(0o755)

            def command(name, body="exit 0\n"):
                path = bindir / name
                path.write_text("#!/bin/sh\n" + body)
                path.chmod(0o755)

            for name in (
                "jq", "unsquashfs", "xorriso", "zstd", "blkid", "chroot",
                "grub-install", "grub-mkconfig", "mkfs.ext4", "mount", "mkfs.fat",
                "sfdisk", "socat", "timeout", "truncate", "umount",
            ):
                command(name)
            command("df", "printf 'Filesystem Blocks Used Available Capacity Mounted\\nfixture 999999999 0 999999999 0%% /\\n'\n")
            command("tesseract", "printf 'eng\\n'\n")
            command("qemu-system-x86_64", "printf 'virtio-vga\\n'\n")
            command("sudo", '''printf 'sudo %s\\n' "$*" >> "$DINX_HOST_FIXTURE_LOG"
[ "$*" = 'losetup --find' ] || exit 91
[ "$DINX_HOST_FIXTURE_SUDO_STATUS" = 0 ] || exit "$DINX_HOST_FIXTURE_SUDO_STATUS"
export DINX_HOST_FIXTURE_ELEVATED=1
exec "$@"
''')
            command("losetup", '''printf 'losetup %s\\n' "$*" >> "$DINX_HOST_FIXTURE_LOG"
[ "${DINX_HOST_FIXTURE_ELEVATED:-}" = 1 ] || exit 92
printf '/dev/loop-fixture\\n'
''')
            environment = os.environ.copy()
            environment.update({
                "PATH": f"{bindir}:{os.defpath}",
                "DINX_HOST_FIXTURE_LOG": str(log),
                "DINX_HOST_FIXTURE_SUDO_STATUS": str(sudo_status),
                "DINX_INSTALL_OVMF_CODE": str(firmware),
                "DINX_INSTALL_OVMF_VARS": str(firmware),
                "DINX_QEMU_OCR_LANG": "eng",
                "DINX_MIN_BUILD_KB": "1",
                "DINX_MIN_BUILD_INODES": "1",
            })

            def unprivileged():
                if os.geteuid() == 0:
                    os.setgroups([])
                    os.setgid(65534)
                    os.setuid(65534)

            result = subprocess.run(
                ["/bin/bash", str(script), "full", "--build-path", str(root)],
                env=environment, capture_output=True, text=True,
                preexec_fn=unprivileged,
            )
            return result, log.read_text()

    def test_nonroot_probe_uses_installer_elevation(self):
        result, commands = self.probe()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands, "sudo losetup --find\nlosetup --find\n")

    def test_failed_elevated_probe_is_rejected(self):
        result, commands = self.probe(sudo_status=42)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("loop-device support is unavailable", result.stderr)
        self.assertEqual(commands, "sudo losetup --find\n")

    def test_missing_device_is_rejected(self):
        result, commands = self.probe(device_present=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("loop-device support is unavailable", result.stderr)
        self.assertEqual(commands, "")


if __name__ == "__main__":
    unittest.main()

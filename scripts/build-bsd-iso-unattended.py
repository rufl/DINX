#!/usr/bin/env python3
"""Install a DINX-BSD ISO in QEMU and prove its first boot."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import selectors
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


CONSOLE_PROMPT = b"Console type [vt100]:"
SUCCESS_MARKER = b"dinx-bsd: first-boot-ready"
ERROR_MARKERS = (
    b"Installation Error",
    b"The checksum for dinx-bsd-overlay.txz does not match",
    b"panic:",
)


class ValidationError(RuntimeError):
    """A deterministic QEMU installation failure."""


def positive_int(value: str) -> int:
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Perform an unattended DINX-BSD install and verify first boot."
    )
    parser.add_argument("iso", type=Path)
    parser.add_argument("--accel", choices=("auto", "kvm", "tcg"), default="auto")
    parser.add_argument("--disk", type=Path)
    parser.add_argument("--disk-size", default="12G")
    parser.add_argument("--keep-disk", action="store_true")
    parser.add_argument("--log", type=Path)
    parser.add_argument("--memory-mib", type=positive_int, default=2048)
    parser.add_argument("--timeout", type=positive_int, default=1200)
    return parser.parse_args()


def log(message: str) -> None:
    print(f"build-bsd-iso-unattended: {message}", flush=True)


def require_command(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise ValidationError(f"required command not found: {name}")
    return path


def choose_accel(requested: str) -> str:
    if requested != "auto":
        if requested == "kvm" and not os.access("/dev/kvm", os.R_OK | os.W_OK):
            raise ValidationError("KVM requested but /dev/kvm is not accessible")
        return requested
    if os.access("/dev/kvm", os.R_OK | os.W_OK):
        return "kvm"
    return "tcg"


def stop_process(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def validate_install(args: argparse.Namespace) -> None:
    iso = args.iso.resolve()
    if not iso.is_file():
        raise ValidationError(f"ISO does not exist: {iso}")

    qemu = require_command("qemu-system-x86_64")
    qemu_img = require_command("qemu-img")
    accel = choose_accel(args.accel)
    log_path = (args.log or iso.with_suffix(".qemu.log")).resolve()
    log_path.parent.mkdir(parents=True, exist_ok=True)

    temporary_directory: tempfile.TemporaryDirectory[str] | None = None
    if args.disk is not None:
        disk = args.disk.resolve()
        disk.parent.mkdir(parents=True, exist_ok=True)
    elif args.keep_disk:
        disk = iso.with_name("dinx-bsd-validation.qcow2")
    else:
        temporary_directory = tempfile.TemporaryDirectory(
            prefix="dinx-bsd-qemu-", dir=iso.parent
        )
        disk = Path(temporary_directory.name) / "installed.qcow2"

    try:
        disk.unlink(missing_ok=True)
        subprocess.run(
            [qemu_img, "create", "-q", "-f", "qcow2", str(disk), args.disk_size],
            check=True,
        )

        command = [
            qemu,
            "-name",
            "dinx-bsd-install-validation",
            "-m",
            str(args.memory_mib),
            "-smp",
            "2",
            "-accel",
            accel,
            "-drive",
            f"file={disk},if=virtio,format=qcow2,cache=unsafe",
            "-drive",
            f"file={iso},media=cdrom,readonly=on",
            "-boot",
            "order=c,once=d,menu=off",
            "-netdev",
            "user,id=net0",
            "-device",
            "virtio-net-pci,netdev=net0",
            "-display",
            "none",
            "-serial",
            "stdio",
            "-monitor",
            "none",
        ]
        if accel == "kvm":
            command.extend(("-cpu", "host"))

        log(f"starting accel={accel} disk={disk} command={shlex.join(command)}")
        with log_path.open("wb") as qemu_log:
            process = subprocess.Popen(
                command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                bufsize=0,
            )
            assert process.stdin is not None
            assert process.stdout is not None
            selector = selectors.DefaultSelector()
            selector.register(process.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + args.timeout
            consoles_answered = 0
            install_phase = 1
            output = bytearray()
            try:
                while time.monotonic() < deadline:
                    events = selector.select(timeout=1)
                    for key, _ in events:
                        chunk = os.read(key.fd, 65536)
                        if not chunk:
                            selector.unregister(process.stdout)
                            continue
                        qemu_log.write(chunk)
                        qemu_log.flush()
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                        output.extend(chunk)

                    prompts = output.count(CONSOLE_PROMPT)
                    if prompts > consoles_answered:
                        process.stdin.write(b"\n")
                        process.stdin.flush()
                        consoles_answered = prompts
                        log("accepted the default vt100 installer console")

                    for marker in ERROR_MARKERS:
                        if marker in output:
                            raise ValidationError(
                                f"installer emitted failure marker: {marker.decode()}"
                            )

                    if (
                        SUCCESS_MARKER in output
                        and (b"FreeBSD/amd64 (dinx-bsd)" in output
                             or b"FreeBSD/amd64 (Amnesiac)" in output)
                        and b"login:" in output
                    ):
                        if install_phase == 1:
                            log("live boot observed; logging in as root")
                            process.stdin.write(b"root\n")
                            process.stdin.flush()
                            install_phase = 15
                            output.clear()
                        elif install_phase == 2:
                            log(f"first boot marker and login prompt observed; log={log_path}")
                            return

                    if install_phase == 15 and b":~ #" in output:
                        log("root shell ready; starting permanent install")
                        process.stdin.write(b"dinx-installer\n")
                        process.stdin.flush()
                        install_phase = 2
                        output.clear()

                    if len(output) > 2 * 1024 * 1024:
                        del output[: len(output) - 1024 * 1024]

                    return_code = process.poll()
                    if return_code is not None:
                        raise ValidationError(
                            f"QEMU exited with status {return_code} before first boot"
                        )

                raise ValidationError(
                    f"timed out after {args.timeout}s waiting for first boot"
                )
            finally:
                selector.close()
                stop_process(process)
    finally:
        if temporary_directory is not None:
            temporary_directory.cleanup()


def main() -> int:
    args = parse_args()
    try:
        validate_install(args)
    except ValidationError as error:
        log(f"ERROR: {error}")
        return 1
    except KeyboardInterrupt:
        log("interrupted")
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

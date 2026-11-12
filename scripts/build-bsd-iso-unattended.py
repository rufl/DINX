#!/usr/bin/env python3
import subprocess
import time
import sys
import os

def log(msg):
    print(f"[dinx-bsd-auto] {msg}")

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    bsd_iso_dir = os.path.join(root_dir, "dist", "bsd-iso")
    qcow2 = os.path.join(bsd_iso_dir, "freebsd-VM.qcow2")
    iso = os.path.join(bsd_iso_dir, "FreeBSD-14.5-RELEASE-amd64-disc1.iso")

    if not os.path.exists(iso):
        log("Error: FreeBSD installer ISO not found.")
        sys.exit(1)

    log("Starting QEMU in serial console mode for automated DINX-BSD bootstrap...")
    cmd = [
        "qemu-system-x86_64",
        "-m", "4G",
        "-smp", "4",
        "-enable-kvm",
        "-hda", qcow2,
        "-cdrom", iso,
        "-boot", "d",
        "-net", "nic,model=virtio",
        "-net", "user",
        "-nographic",
        "-serial", "mon:stdio"
    ]

    log(f"Running command: {' '.join(cmd)}")
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    try:
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            print(line, end="")
            if "Welcome to FreeBSD" in line or "Autoboot" in line:
                log("Sending serial boot command...")
                proc.stdin.write("set console=comconsole\nboot\n")
                proc.stdin.flush()
    except KeyboardInterrupt:
        log("Interrupted by user.")
        proc.terminate()

if __name__ == "__main__":
    main()

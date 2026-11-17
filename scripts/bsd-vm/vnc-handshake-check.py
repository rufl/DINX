#!/usr/bin/env python3
"""Host-side check that a live desktop is reachable over VNC.

Connects to the forwarded port (QEMU hostfwd, or a VirtualBox NAT rule) and
performs the RFB handshake through ServerInit, which yields the desktop name
and framebuffer geometry. This proves the compositor is running and serving a
screen to a remote viewer -- exactly what a user does with a VNC client on the
hypervisor host.

Protocol note: RFB 3.3 sends a 4-byte security type; RFB 3.7/3.8 send a
1-byte count of security types followed by the list.
"""
import socket
import struct
import sys


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError(f"connection closed after {len(buf)} bytes")
        buf += chunk
    return buf


def main(host: str, port: int) -> int:
    with socket.create_connection((host, port), timeout=15) as s:
        s.settimeout(15)
        version = recv_exact(s, 12)
        print("server version:", version.decode(errors="replace").strip())
        s.sendall(b"RFB 003.008\n")

        count = struct.unpack(">B", recv_exact(s, 1))[0]
        if count == 0:
            print("server rejected connection:",
                  recv_exact(s, struct.unpack(">I", recv_exact(s, 4))[0])
                  .decode(errors="replace"))
            return 1
        types = list(recv_exact(s, count))
        print("security types offered:", types)

        # Prefer None (1); fall back to VNC auth (2) with an empty password.
        chosen = 1 if 1 in types else types[0]
        s.sendall(bytes([chosen]))
        if chosen == 2:
            challenge = recv_exact(s, 16)
            s.sendall(bytes(16))  # empty password, DES response placeholder
            print("sent VNC auth response for challenge", challenge[:4].hex())

        result = struct.unpack(">I", recv_exact(s, 4))[0]
        if result != 0:
            reason = recv_exact(s, struct.unpack(">I", recv_exact(s, 4))[0])
            print("auth FAILED:", reason.decode(errors="replace"))
            return 1
        # RFB 3.8: after a successful SecurityResult the client must send
        # ClientInit (1 byte: shared flag) before the server sends ServerInit.
        s.sendall(b"\x01")
        init = recv_exact(s, 24)
        width, height = struct.unpack(">HH", init[:4])
        name_len = struct.unpack(">I", init[20:24])[0]
        name = recv_exact(s, name_len).decode(errors="replace")
        print(f"desktop name: {name!r}")
        print(f"framebuffer: {width}x{height}")
        print("VNC_HANDSHAKE_OK")
        return 0 if width > 0 and height > 0 else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1",
                  int(sys.argv[2]) if len(sys.argv) > 2 else 15900))

#!/usr/bin/env python3
"""Minimal RFB (VNC) client that grabs the live framebuffer from the host.

This is the real "can I see the desktop remotely?" test: it connects to the
forwarded VNC port, completes the RFB 3.8 handshake, negotiates a raw pixel
format, requests one full framebuffer update and decodes its rectangles into a
PPM image (convert with `pnmtopng`, or open it directly).

Usage: vnc-framebuffer-grab.py HOST PORT OUT.ppm
"""
import socket
import struct
import sys

ENCODING_RAW = 0
ENCODING_COPYRECT = 1
ENCODING_DESKTOP_NAME = -223
ENCODING_EXT_DESKTOP_SIZE = -224


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError(f"server closed after {len(buf)}/{n} bytes")
        buf += chunk
    return buf


def main(host, port, out):
    s = socket.create_connection((host, port), timeout=25)
    s.settimeout(25)
    print("server:", recv_exact(s, 12).decode(errors="replace").strip())
    s.sendall(b"RFB 003.008\n")

    count = struct.unpack(">B", recv_exact(s, 1))[0]
    if count == 0:
        reason = recv_exact(s, struct.unpack(">I", recv_exact(s, 4))[0])
        print("rejected:", reason.decode(errors="replace"))
        return 1
    types = list(recv_exact(s, count))
    print("security types:", types)
    s.sendall(bytes([1 if 1 in types else types[0]]))
    if struct.unpack(">I", recv_exact(s, 4))[0] != 0:
        reason = recv_exact(s, struct.unpack(">I", recv_exact(s, 4))[0])
        print("auth FAILED:", reason.decode(errors="replace"))
        return 1

    s.sendall(b"\x01")  # ClientInit, shared
    init = recv_exact(s, 24)
    w, h = struct.unpack(">HH", init[:4])
    name = recv_exact(s, struct.unpack(">I", init[20:24])[0]).decode(errors="replace")
    print(f"desktop name={name!r} framebuffer={w}x{h}")

    # 32bpp true-colour, big-endian flag 0, 8bpc, shifts 16/8/0 (BGRX in memory).
    fmt = struct.pack(">BBBBHHHBBBxxx", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
    s.sendall(b"\x00\x00\x00\x00" + fmt)              # SetPixelFormat
    s.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, w, h))  # FramebufferUpdateRequest

    fb = bytearray(w * h * 4)
    filled = 0

    while True:
        msg_type = struct.unpack(">B", recv_exact(s, 1))[0]
        if msg_type != 0:
            print(f"unexpected server message {msg_type}; only 0 handled")
            break
        recv_exact(s, 1)  # padding
        nrect = struct.unpack(">H", recv_exact(s, 2))[0]
        for _ in range(nrect):
            x, y, rw, rh, enc = struct.unpack(">HHHHi", recv_exact(s, 12))
            if enc == ENCODING_RAW:
                data = recv_exact(s, rw * rh * 4)
                for row in range(rh):
                    dst = ((y + row) * w + x) * 4
                    src = row * rw * 4
                    fb[dst:dst + rw * 4] = data[src:src + rw * 4]
                filled += rw * rh
            elif enc == ENCODING_COPYRECT:
                recv_exact(s, 4)
            elif enc == ENCODING_DESKTOP_NAME:
                n = struct.unpack(">I", recv_exact(s, 4))[0]
                print("desktop-name:", recv_exact(s, n).decode(errors="replace"))
            elif enc == ENCODING_EXT_DESKTOP_SIZE:
                recv_exact(s, 2)
                nw, nh, ns = struct.unpack(">HHH", recv_exact(s, 6))
                recv_exact(s, ns * 12)
                print(f"extended desktop size: {nw}x{nh}")
            else:
                print(f"unsupported encoding {enc}; stopping")
                nrect = 0
                break
        if nrect == 0 or filled >= w * h:
            break

    print(f"framebuffer pixels filled: {filled}/{w * h}")
    with open(out, "wb") as f:
        f.write(f"P6\n{w} {h}\n255\n".encode())
        for px in range(w * h):
            o = px * 4
            f.write(bytes((fb[o + 2], fb[o + 1], fb[o])))  # BGRX -> RGB
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], int(sys.argv[2]), sys.argv[3]))

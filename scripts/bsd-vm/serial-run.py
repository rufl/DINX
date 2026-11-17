import socket, sys, time

SOCK = sys.argv[1] if len(sys.argv) > 1 else "/tmp/dinx-s9.sock"
CMD = sys.argv[2] if len(sys.argv) > 2 else "echo hi"
WAIT = float(sys.argv[3]) if len(sys.argv) > 3 else 40.0

s = socket.socket(socket.AF_UNIX)
s.connect(SOCK)
s.setblocking(False)


def drain(secs):
    buf = b""
    end = time.time() + secs
    while time.time() < end:
        try:
            d = s.recv(65536)
            if d:
                buf += d
        except BlockingIOError:
            time.sleep(0.1)
    return buf.decode("utf-8", "replace")


drain(0.4)
s.sendall(b"\n")
drain(1.0)
s.sendall(CMD.encode() + b"\n")
print(drain(WAIT), end="")

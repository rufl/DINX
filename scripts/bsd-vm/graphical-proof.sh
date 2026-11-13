#!/bin/sh
# Graphical proof: boot an installed DINX-BSD disk, install the real local
# packages, enable greetd autologin, and capture the framebuffer via QMP.
# Usage: graphical-proof.sh <qcow2> <outdir> [ssh-port]
set -eu
DISK=$1
OUT=$2
PORT=${3:-2223}
QMP=/tmp/dinx-proof-qmp.sock
KEY=/tmp/dinx-vm-key
mkdir -p "$OUT"
rm -f "$QMP"

qemu-system-x86_64 -name dinx-graphical-proof -m 4096 -smp 4 -accel kvm \
  -drive "file=$DISK,if=virtio,format=qcow2,cache=unsafe" \
  -netdev "user,id=net0,hostfwd=tcp::$PORT-:22" -device virtio-net-pci,netdev=net0 \
  -display none -serial null -monitor none \
  -qmp "unix:$QMP,server=on,wait=off" &
QPID=$!
trap 'kill $QPID 2>/dev/null || true' EXIT

SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p $PORT root@127.0.0.1"
i=0
until $SSH 'echo SSH_UP' 2>/dev/null | grep -q SSH_UP; do
  i=$((i + 1))
  [ $i -gt 60 ] && { echo "ssh never came up" >&2; exit 1; }
  sleep 5
done

$SSH 'pkg add /root/build/repo/dinx-wlroots.pkg /root/build/repo/dinx-greetd.pkg /root/build/repo/dinx-aqueous.pkg /root/build/repo/dinx-pearl.pkg 2>&1 | tail -2;
printf "[initial_session]\ncommand = \"/usr/local/bin/dinx-session-select\"\nuser = \"dinx\"\n\n[default_session]\ncommand = \"agreety --cmd /usr/local/bin/dinx-session-select\"\nuser = \"greeter\"\n" > /usr/local/etc/greetd/config.toml;
service seatd start >/dev/null 2>&1; service dinx_greetd restart >/dev/null 2>&1 || service dinx_greetd start >/dev/null 2>&1; echo SESSION_STARTED'
sleep 30

python3 - "$QMP" "$OUT/frame.ppm" <<'EOF'
import json, socket, sys, time
sock = socket.socket(socket.AF_UNIX)
sock.connect(sys.argv[1])
f = sock.makefile("rw")
json.loads(f.readline())
def cmd(c, **a):
    f.write(json.dumps({"execute": c, "arguments": a}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r
cmd("qmp_capabilities")
r = cmd("screendump", filename=sys.argv[2])
print("screendump:", r)
EOF
pnmtopng "$OUT/frame.ppm" > "$OUT/graphical.png"
echo "PROOF_IMAGE=$OUT/graphical.png"

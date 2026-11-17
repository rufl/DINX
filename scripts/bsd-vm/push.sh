#!/bin/sh
# push.sh FILE [FILE...] -- send files to the host collector over the QEMU
# user-network gateway. Keeps every serial command short (<100 chars), which
# matters because the serial line discipline truncates long input lines.
for f in "$@"; do
  if [ -f "$f" ]; then
    nc -N 10.0.2.2 9000 < "$f"
    echo "pushed $f ($(wc -c < "$f") bytes)"
  else
    echo "missing $f"
  fi
  sleep 1
done

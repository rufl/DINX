#!/bin/sh
# Re-package with corrected plists, reinstall in dependency order, then run
# the headless graphical proof. Run as root inside the FreeBSD build VM.
set -u
cd /root/build || exit 1
sh build-native.sh >/dev/null 2>&1
echo BUILD7=$?
pkg delete -f -y dinx-pearl dinx-aqueous dinx-wlroots dinx-greetd dinx-compat >/dev/null 2>&1
for p in dinx-compat-1.0 dinx-wlroots-0.20.2.aqueous dinx-aqueous-1.0.5 dinx-pearl-0.3.9 dinx-greetd-0.10.3; do
  pkg add "/root/build/repo/$p.pkg" >/dev/null 2>&1
  echo "$p=$?"
done
sh headless-proof.sh

# DINX-BSD Build and Installation Guide

This guide outlines how to build and deploy DINX-BSD using FreeBSD 14.2+, dinit, seatd, wlroots, Aqueous, Pearl, and OctaPkg.

## 1. Prerequisites (FreeBSD Host)
- FreeBSD 14.2-RELEASE or newer (amd64)
- Root privileges
- Internet access for fetching ports and packages (`pkg`)

## 2. Setting up the Environment
```pkg
pkg install git zig dinit seatd pipewire wireplumber octapkg wayland wlroots
```

## 3. Building Aqueous and Pearl
```bash
cd distro/bsd/ports
make -f Makefile.aqueous install
```

## 4. Configuring Services (dinit)
Enable supervision units in `/etc/dinit.d/`:
```bash
ln -s /usr/local/etc/dinit.d/seatd /etc/dinit.d/seatd
ln -s /usr/local/etc/dinit.d/pipewire /etc/dinit.d/pipewire
ln -s /usr/local/etc/dinit.d/greetd /etc/dinit.d/greetd
```

## 5. Launching the Session
Start dinit or reboot into the graphical session where Aqueous + Pearl Greeter will automatically initialize.

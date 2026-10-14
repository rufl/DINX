#!/usr/bin/env bash
set -euo pipefail

iso_path=${1:-}
timeout_seconds=${DINX_INSTALL_TIMEOUT:-180}
memory_mb=${DINX_INSTALL_MEMORY:-2048}
disk_size=${DINX_INSTALL_DISK_SIZE:-8G}
output_dir=${DINX_INSTALL_OUTPUT_DIR:-}

fail() {
  printf 'smoke-install: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" ]] || fail "usage: $0 ISO"
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_INSTALL_TIMEOUT must be a positive integer'
[[ "$memory_mb" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_INSTALL_MEMORY must be a positive integer'
[[ "$disk_size" =~ ^[1-9][0-9]*[KMGTP]$ ]] || fail 'DINX_INSTALL_DISK_SIZE must be an integer with K, M, G, T or P suffix'

for command in xorriso unsquashfs losetup sfdisk mkfs.ext4 blkid mount umount chroot grub-install grub-mkconfig qemu-system-x86_64 socat timeout; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fail 'root or passwordless sudo is required'
  exec sudo --preserve-env=DINX_INSTALL_TIMEOUT,DINX_INSTALL_MEMORY,DINX_INSTALL_DISK_SIZE,DINX_INSTALL_OUTPUT_DIR \
    "$0" "$@"
fi

if [[ -z "$output_dir" ]]; then
  output_dir=$(dirname "$iso_path")
fi
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)

work_dir=$(mktemp -d)
rootfs_image="$work_dir/rootfs.img"
disk_image="$work_dir/dinx-installed.img"
serial_log="$output_dir/dinx-installed.qemu.log"
screen_path="$output_dir/dinx-installed-screen.ppm"
recovery_screen_path="$output_dir/dinx-recovery-screen.ppm"
loop_device=
root_device=
target_dir="$work_dir/target"
mounted_target=false
mounted_dev=false
mounted_proc=false
mounted_sys=false
mounted_run=false

cleanup() {
  set +e
  if [[ "$mounted_run" == true ]]; then umount -R "$target_dir/run" 2>/dev/null || umount "$target_dir/run" 2>/dev/null || true; fi
  if [[ "$mounted_sys" == true ]]; then umount -R "$target_dir/sys" 2>/dev/null || umount "$target_dir/sys" 2>/dev/null || true; fi
  if [[ "$mounted_proc" == true ]]; then umount -R "$target_dir/proc" 2>/dev/null || umount "$target_dir/proc" 2>/dev/null || true; fi
  if [[ "$mounted_dev" == true ]]; then umount -R "$target_dir/dev" 2>/dev/null || umount "$target_dir/dev" 2>/dev/null || true; fi
  if [[ "$mounted_target" == true ]]; then umount "$target_dir" 2>/dev/null || true; fi
  if [[ -n "$loop_device" ]]; then losetup -d "$loop_device" 2>/dev/null || true; fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

printf 'smoke-install: extracting rootfs from ISO\n'
xorriso -osirrox on -indev "$iso_path" -extract /LiveOS/rootfs.img "$rootfs_image" >/dev/null

printf 'smoke-install: creating disposable %s disk\n' "$disk_size"
truncate -s "$disk_size" "$disk_image"
printf 'label: dos\n, , 83, *\n' | sfdisk --wipe always "$disk_image" >/dev/null
loop_device=$(losetup --find --show --partscan "$disk_image")
root_device="${loop_device}p1"
for _ in {1..20}; do
  [[ -b "$root_device" ]] && break
  udevadm settle 2>/dev/null || true
  sleep 1
done
[[ -b "$root_device" ]] || fail "partition device did not appear: $root_device"
mkfs.ext4 -F -L DINX_ROOT "$root_device" >/dev/null
mkdir -p "$target_dir"
mount "$root_device" "$target_dir"
mounted_target=true

printf 'smoke-install: unpacking the same rootfs used by Calamares\n'
unsquashfs -no-xattrs -no-progress -d "$target_dir" "$rootfs_image" >/dev/null

for mount_name in dev proc sys run; do
  mkdir -p "$target_dir/$mount_name"
done
mount --rbind /dev "$target_dir/dev"
mount --make-rslave "$target_dir/dev"
mounted_dev=true
mount -t proc proc "$target_dir/proc"
mounted_proc=true
mount --rbind /sys "$target_dir/sys"
mount --make-rslave "$target_dir/sys"
mounted_sys=true
mount --rbind /run "$target_dir/run"
mount --make-rslave "$target_dir/run"
mounted_run=true

printf 'smoke-install: applying Calamares package removal contract\n'
chroot "$target_dir" /usr/bin/pacman -R --noconfirm \
  artix-live-base artix-live-dinit calamares calamares-extensions >/dev/null

printf 'smoke-install: creating the Calamares user and persistent fstab\n'
chroot "$target_dir" /usr/bin/useradd --create-home --user-group --shell /bin/bash \
  --groups users,audio,video,network,storage,wheel dinx
printf 'dinx:dinx\n' | chroot "$target_dir" /usr/bin/chpasswd
root_uuid=$(blkid -s UUID -o value "$root_device")
printf 'UUID=%s / ext4 defaults 0 1\n' "$root_uuid" > "$target_dir/etc/fstab"
printf 'dinx-install-smoke\n' > "$target_dir/etc/hostname"

printf 'smoke-install: enabling dinit services and recovery TTYs\n'
for service in NetworkManager elogind greetd getty@tty2 getty@tty3; do
  ln -sfn "../$service" "$target_dir/etc/dinit.d/boot.d/$service"
done
printf 'smoke-install: adding a first-boot marker service\n'
mkdir -p "$target_dir/usr/local/libexec" "$target_dir/var/lib/dinx"
cat > "$target_dir/usr/local/libexec/dinx-install-smoke-marker" <<'EOF'
#!/bin/sh
set -eu
install -d -m 0755 /var/lib/dinx
printf 'dinit-first-boot=%s\n' "$(date -u +%FT%TZ)" > /var/lib/dinx/install-smoke.booted
EOF
chmod 0755 "$target_dir/usr/local/libexec/dinx-install-smoke-marker"
cat > "$target_dir/etc/dinit.d/dinx-install-smoke-marker" <<'EOF'
type = scripted
command = /usr/local/libexec/dinx-install-smoke-marker
restart = false
EOF
ln -sfn ../dinx-install-smoke-marker "$target_dir/etc/dinit.d/boot.d/dinx-install-smoke-marker"

printf 'smoke-install: generating the installed initramfs\n'
chroot "$target_dir" /usr/bin/mkinitcpio -P >/dev/null

printf 'smoke-install: installing BIOS GRUB into the disposable disk\n'
grub-install --target=i386-pc --no-floppy --recheck --boot-directory="$target_dir/boot" "$loop_device" >/dev/null
chroot "$target_dir" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg >/dev/null


# The guest must start from the installed disk, not the live ISO.
umount -R "$target_dir/run"
mounted_run=false
umount -R "$target_dir/sys"
mounted_sys=false
umount -R "$target_dir/proc"
mounted_proc=false
umount -R "$target_dir/dev"
mounted_dev=false
umount "$target_dir"
mounted_target=false
losetup -d "$loop_device"
loop_device=

printf 'smoke-install: booting the installed disk\n'
if [[ -r /dev/kvm ]]; then
  accel=(-accel kvm)
else
  accel=(-accel tcg,thread=multi)
fi
monitor_dir=$(mktemp -d)
monitor_path="$monitor_dir/qemu.monitor"
set +e
timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 \
  "${accel[@]}" \
  -m "$memory_mb" \
  -drive "file=$disk_image,format=raw,if=virtio" \
  -display none \
  -monitor "unix:$monitor_path,server=on,wait=off" \
  -serial "file:$serial_log" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -no-reboot \
  -no-shutdown &
qemu_pid=$!
monitor_ready=false
for _ in {1..30}; do
  if [[ -S "$monitor_path" ]]; then
    monitor_ready=true
    break
  fi
  sleep 1
done
if [[ "$monitor_ready" == true ]]; then
  sleep 30
  printf 'screendump %s\n' "$screen_path" | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1 || true
  printf 'sendkey ctrl-alt-f2\n' | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1 || true
  sleep 3
  printf 'screendump %s\n' "$recovery_screen_path" | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1 || true
fi
wait "$qemu_pid"
qemu_status=$?
set -e
rm -rf "$monitor_dir"
[[ "$qemu_status" -eq 124 ]] || {
  [[ -s "$serial_log" ]] && cat "$serial_log" >&2 || true
  fail "installed disk QEMU exited before the ${timeout_seconds}s boot window (status $qemu_status)"
}
[[ -s "$screen_path" ]] || fail "installed disk screenshot is missing: $screen_path"
[[ -s "$recovery_screen_path" ]] || fail "recovery TTY screenshot is missing: $recovery_screen_path"
for image in "$screen_path" "$recovery_screen_path"; do
  IFS= read -r magic < "$image" || true
  [[ "$magic" == P6 ]] || fail "invalid QEMU PPM screenshot: $image"
done

loop_device=$(losetup --find --show --partscan "$disk_image")
root_device="${loop_device}p1"
for _ in {1..20}; do
  [[ -b "$root_device" ]] && break
  udevadm settle 2>/dev/null || true
  sleep 1
done
[[ -b "$root_device" ]] || fail "installed partition device did not reappear: $root_device"
mkdir -p "$target_dir"
mount "$root_device" "$target_dir"
mounted_target=true
[[ -s "$target_dir/var/lib/dinx/install-smoke.booted" ]] || {
  [[ -s "$serial_log" ]] && cat "$serial_log" >&2 || true
  fail 'dinit first-boot marker was not created'
}
[[ -L "$target_dir/etc/dinit.d/boot.d/getty@tty2" ]] || fail 'recovery TTY service is not enabled'
printf 'smoke-install: persistent install and first-boot recovery contract passed\n'

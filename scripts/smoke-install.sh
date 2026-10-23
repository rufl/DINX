#!/usr/bin/env bash
set -euo pipefail

iso_path=${1:-}
timeout_seconds=${DINX_INSTALL_TIMEOUT:-180}
memory_mb=${DINX_INSTALL_MEMORY:-2048}
disk_size=${DINX_INSTALL_DISK_SIZE:-8G}
output_dir=${DINX_INSTALL_OUTPUT_DIR:-}
firmware_mode=${DINX_INSTALL_FIRMWARE:-bios}

fail() {
  printf 'smoke-install: %s\n' "$*" >&2
  exit 1
}
case "$firmware_mode" in
  bios|uefi) ;;
  *) fail 'DINX_INSTALL_FIRMWARE must be bios or uefi' ;;
esac

[[ -n "$iso_path" ]] || fail "usage: $0 ISO"
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_INSTALL_TIMEOUT must be a positive integer'
[[ "$memory_mb" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_INSTALL_MEMORY must be a positive integer'
[[ "$disk_size" =~ ^[1-9][0-9]*[KMGTP]$ ]] || fail 'DINX_INSTALL_DISK_SIZE must be an integer with K, M, G, T or P suffix'

for command in xorriso unsquashfs losetup sfdisk mkfs.ext4 blkid mount umount chroot grub-install grub-mkconfig qemu-system-x86_64 socat timeout; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
if [[ "$firmware_mode" == uefi ]]; then
  command -v mkfs.fat >/dev/null 2>&1 || fail 'required command not found: mkfs.fat'
fi

if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fail 'root or passwordless sudo is required'
  exec sudo --preserve-env=DINX_INSTALL_FIRMWARE,DINX_INSTALL_TIMEOUT,DINX_INSTALL_MEMORY,DINX_INSTALL_DISK_SIZE,DINX_INSTALL_OUTPUT_DIR \
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
output_suffix=
if [[ "$firmware_mode" == uefi ]]; then
  output_suffix=-uefi
fi
serial_log="$output_dir/dinx-installed${output_suffix}.qemu.log"
screen_path="$output_dir/dinx-installed${output_suffix}-screen.ppm"
recovery_screen_path="$output_dir/dinx-recovery${output_suffix}-screen.ppm"
loop_device=
root_device=
efi_device=
target_dir="$work_dir/target"
mounted_target=false
mounted_efi=false
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
  if [[ "$mounted_efi" == true ]]; then umount "$target_dir/boot/efi" 2>/dev/null || true; fi
  if [[ "$mounted_target" == true ]]; then umount "$target_dir" 2>/dev/null || true; fi
  if [[ -n "$loop_device" ]]; then losetup -d "$loop_device" 2>/dev/null || true; fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

printf 'smoke-install: extracting rootfs from ISO\n'
xorriso -osirrox on -indev "$iso_path" -extract /LiveOS/rootfs.img "$rootfs_image" >/dev/null

printf 'smoke-install: creating disposable %s %s disk\n' "$disk_size" "$firmware_mode"
truncate -s "$disk_size" "$disk_image"
if [[ "$firmware_mode" == bios ]]; then
  printf 'label: dos\n, , 83, *\n' | sfdisk --wipe always "$disk_image" >/dev/null
else
  printf 'label: gpt\n, 512M, U\n, , L\n' | sfdisk --wipe always "$disk_image" >/dev/null
fi
loop_device=$(losetup --find --show --partscan "$disk_image")
if [[ "$firmware_mode" == bios ]]; then
  root_device="${loop_device}p1"
else
  efi_device="${loop_device}p1"
  root_device="${loop_device}p2"
fi
for _ in {1..20}; do
  [[ -b "$root_device" ]] && break
  udevadm settle 2>/dev/null || true
  sleep 1
done
[[ -b "$root_device" ]] || fail "partition device did not appear: $root_device"
if [[ "$firmware_mode" == uefi ]]; then
  [[ -b "$efi_device" ]] || fail "EFI partition device did not appear: $efi_device"
  mkfs.fat -F 32 -n DINX_EFI "$efi_device" >/dev/null
fi
mkfs.ext4 -F -L DINX_ROOT "$root_device" >/dev/null
mkdir -p "$target_dir"
mount "$root_device" "$target_dir"
mounted_target=true

printf 'smoke-install: unpacking the same rootfs used by Calamares\n'
unsquashfs -no-xattrs -no-progress -d "$target_dir" "$rootfs_image" >/dev/null
if [[ "$firmware_mode" == uefi ]]; then
  mkdir -p "$target_dir/boot/efi"
  mount "$efi_device" "$target_dir/boot/efi"
  mounted_efi=true
fi

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
chroot "$target_dir" /usr/bin/useradd --create-home --user-group --shell /bin/fish \
  --groups users,audio,video,network,storage,wheel dinx
printf 'dinx:dinx\n' | chroot "$target_dir" /usr/bin/chpasswd
root_uuid=$(blkid -s UUID -o value "$root_device")
printf 'UUID=%s / ext4 defaults 0 1\n' "$root_uuid" > "$target_dir/etc/fstab"
if [[ "$firmware_mode" == uefi ]]; then
  efi_uuid=$(blkid -s UUID -o value "$efi_device")
  printf 'UUID=%s /boot/efi vfat umask=0077 0 2\n' "$efi_uuid" >> "$target_dir/etc/fstab"
fi
printf 'dinx-install-smoke\n' > "$target_dir/etc/hostname"
printf 'smoke-install: root UUID=%s\n' "$root_uuid"

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
fail() {
  printf 'install_smoke_failure=%s\n' "$1" > /var/lib/dinx/install-smoke.failed
  exit 1
}
tmp=/var/lib/dinx/install-smoke.booted.tmp
{
  printf 'dinit-first-boot=%s\n' "$(date -u +%FT%TZ)"
  [ -d /var/lib/pacman/local ] || fail pacman_database_missing
  printf 'pacman_database=true\n'
  /usr/bin/pacman -Q dinit dinitui dinxpanel dome seafoam-settings zls >/dev/null 2>&1 \
    || fail core_packages_missing
  [ -f /etc/xdg/zls.json ] || fail zls_config_missing
  [ -x /usr/lib/zls/zig-env ] || fail zls_shim_missing
  [ -f /usr/lib/zls/zig/std/std.zig ] || fail zls_stdlib_missing
  [ "$(/usr/bin/zls --version)" = 0.16.0 ] || fail zls_version_mismatch
  [ "$(/usr/lib/zls/zig-env version)" = 0.16.0 ] || fail zls_shim_version_mismatch
  /usr/bin/zls env | grep -Fq '/etc/xdg/zls.json' || fail zls_config_not_selected
  printf 'zls_runtime=true\n'
  printf 'core_packages=true\n'
  for service in NetworkManager elogind; do
    ready=false
    attempt=0
    while [ "$attempt" -lt 30 ]; do
      if /usr/bin/dinitctl status "$service" >/dev/null 2>&1; then
        ready=true
        break
      fi
      attempt=$((attempt + 1))
      sleep 1
    done
    [ "$ready" = true ] || fail "service_${service}_unavailable"
  done
  printf 'dinit_services=true\n'
  [ -x /usr/bin/ldd ] || fail ldd_missing
  for binary in /usr/bin/dinitui /usr/bin/dinxpanel /usr/bin/dome /usr/bin/seafoam-settings /usr/bin/zls; do
    [ -x "$binary" ] || fail "binary_missing_${binary##*/}"
    if /usr/bin/ldd "$binary" 2>&1 | grep -Fq 'not found'; then
      fail "library_missing_${binary##*/}"
    fi
  done
  printf 'dynamic_libraries=true\n'
  if /usr/bin/pacman -Q wizp >/dev/null 2>&1 \
    || /usr/bin/pacman -Q cups-dinit >/dev/null 2>&1; then
    fail optional_packages_in_base_iso
  fi
  printf 'optional_base_absent=true\n'
  printf 'lifecycle_checks=true\n'
} > "$tmp"
mv -f "$tmp" /var/lib/dinx/install-smoke.booted
EOF
chmod 0755 "$target_dir/usr/local/libexec/dinx-install-smoke-marker"
cat > "$target_dir/etc/dinit.d/dinx-install-smoke-marker" <<'EOF'
type = scripted
command = /usr/local/libexec/dinx-install-smoke-marker
restart = false
EOF
ln -sfn ../dinx-install-smoke-marker "$target_dir/etc/dinit.d/boot.d/dinx-install-smoke-marker"

printf '\nMODULES=(virtio virtio_pci virtio_blk ata_generic ata_piix ext4)\n' >> "$target_dir/etc/mkinitcpio.conf"
printf '\nGRUB_CMDLINE_LINUX="console=tty0 console=ttyS0"\nGRUB_TIMEOUT=1\nGRUB_TIMEOUT_STYLE=hidden\n' >> "$target_dir/etc/default/grub"
printf 'smoke-install: generating the installed initramfs\n'
chroot "$target_dir" /usr/bin/mkinitcpio -P >/dev/null

if [[ "$firmware_mode" == bios ]]; then
  printf 'smoke-install: installing BIOS GRUB into the disposable disk\n'
  chroot "$target_dir" /usr/bin/grub-install \
    --target=i386-pc --no-floppy --recheck --disk-module=biosdisk \
    --boot-directory=/boot "$loop_device" >/dev/null
else
  printf 'smoke-install: installing UEFI GRUB into the disposable disk\n'
  chroot "$target_dir" /usr/bin/grub-install \
    --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --bootloader-id=DINX \
    --no-nvram --removable --recheck >/dev/null
fi
chroot "$target_dir" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
if [[ "$firmware_mode" == uefi ]]; then
  mkdir -p "$target_dir/boot/efi/EFI/BOOT" "$target_dir/boot/efi/EFI/DINX"
  cat > "$target_dir/boot/efi/EFI/BOOT/grub.cfg" <<EOF
set timeout_style=hidden
set timeout=1
set root=(hd0,gpt2)
insmod ext2
insmod linux
menuentry 'DINX installed smoke' {
    linux /boot/vmlinuz-linux root=UUID=$root_uuid rw console=tty0 console=ttyS0 loglevel=3
    initrd /boot/intel-ucode.img /boot/amd-ucode.img /boot/initramfs-linux.img
}
EOF
  cp "$target_dir/boot/efi/EFI/BOOT/grub.cfg" \
    "$target_dir/boot/efi/EFI/DINX/grub.cfg"
  chroot "$target_dir" /usr/bin/grub-mkimage \
    -O x86_64-efi -d /usr/lib/grub/x86_64-efi \
    -p '(hd0,gpt1)/EFI/BOOT' \
    -o /boot/efi/EFI/BOOT/BOOTX64.EFI \
    part_gpt fat ext2 normal configfile linux
fi
if [[ "$firmware_mode" == bios ]] && ! grep -Eq '^[[:space:]]*linux[[:space:]]' "$target_dir/boot/grub/grub.cfg"; then
  printf 'smoke-install: generated GRUB config has no Linux entry; writing deterministic smoke entry\n'
  cat > "$target_dir/boot/grub/grub.cfg" <<EOF
set timeout_style=hidden
set timeout=1
insmod part_msdos
insmod ext2
search --no-floppy --fs-uuid --set=root $root_uuid
menuentry 'DINX installed smoke' {
    linux /boot/vmlinuz-linux root=UUID=$root_uuid rw console=tty0 console=ttyS0 loglevel=3
    initrd /boot/intel-ucode.img /boot/amd-ucode.img /boot/initramfs-linux.img
}
EOF
fi
if [[ "$firmware_mode" == bios ]]; then
  cat > "$target_dir/tmp/dinx-grub-early.cfg" <<EOF
search.fs_uuid $root_uuid root
set prefix=(\$root)/boot/grub
EOF
  chroot "$target_dir" /usr/bin/grub-mkimage \
    -O i386-pc -d /usr/lib/grub/i386-pc -p '(hd0,msdos1)/boot/grub' \
    -c /tmp/dinx-grub-early.cfg -o /boot/grub/i386-pc/core.img \
    biosdisk part_msdos ext2 search search_fs_uuid normal configfile linux
  chroot "$target_dir" /usr/bin/grub-bios-setup \
    --directory=/boot/grub/i386-pc \
    --boot-image=boot.img \
    --core-image=core.img \
    --skip-fs-probe "$loop_device" >/dev/null
fi
if [[ "$firmware_mode" == uefi ]]; then
  [[ -s "$target_dir/boot/efi/EFI/BOOT/BOOTX64.EFI" ]] || fail 'UEFI fallback bootloader is missing'
fi
printf 'smoke-install: target mkinitcpio configuration\n'
grep -E '^(MODULES|HOOKS)=' "$target_dir/etc/mkinitcpio.conf" || true
printf 'smoke-install: installed initramfs storage modules\n'
chroot "$target_dir" /usr/bin/lsinitcpio -n -l /boot/initramfs-linux.img \
  | grep -E '(^|/)(virtio(_pci|_blk)?|ata(_generic|_piix)?|ext4)(\.ko|/)' || true
if [[ "$firmware_mode" == bios ]]; then
  printf 'smoke-install: target BIOS GRUB modules\n'
  find "$target_dir/boot/grub/i386-pc" -maxdepth 1 -type f \
    \( -name 'biosdisk.mod' -o -name 'normal.mod' \
    -o -name 'part_msdos.mod' -o -name 'ext2.mod' -o -name 'search*.mod' -o -name 'linux.mod' \) \
    -printf '%f\n' | sort
else
  printf 'smoke-install: target UEFI bootloader\n'
  find "$target_dir/boot/efi/EFI" -type f -printf '%P\n' | sort
  [[ -s "$target_dir/boot/efi/EFI/BOOT/BOOTX64.EFI" ]] || fail 'UEFI fallback bootloader is missing'
fi
printf 'smoke-install: generated GRUB configuration\n'
wc -c "$target_dir/boot/grub/grub.cfg"
grep -E '^[[:space:]]*(set timeout|linux|linuxefi|search|set root)' \
  "$target_dir/boot/grub/grub.cfg" || true

[[ -s "$target_dir/boot/grub/grub.cfg" ]] || fail 'installed GRUB configuration is missing'
# The guest must start from the installed disk, not the live ISO.
umount -R "$target_dir/run"
mounted_run=false
umount -R "$target_dir/sys"
mounted_sys=false
umount -R "$target_dir/proc"
mounted_proc=false
umount -R "$target_dir/dev"
mounted_dev=false
if [[ "$mounted_efi" == true ]]; then
  umount "$target_dir/boot/efi"
  mounted_efi=false
fi
umount "$target_dir"
mounted_target=false
losetup -d "$loop_device"
loop_device=

printf 'smoke-install: booting installed %s disk\n' "$firmware_mode"
if [[ -r /dev/kvm ]]; then
  accel=(-accel kvm)
else
  accel=(-accel tcg,thread=multi)
fi
monitor_dir=$(mktemp -d)
monitor_path="$monitor_dir/qemu.monitor"
qemu_args=(
  "${accel[@]}"
  -m "$memory_mb"
  -drive "file=$disk_image,format=raw,if=ide"
  -display none
  -monitor "unix:$monitor_path,server=on,wait=off"
  -serial "file:$serial_log"
  -netdev user,id=net0
  -device virtio-net-pci,netdev=net0
  -no-reboot
  -no-shutdown
)
if [[ "$firmware_mode" == uefi ]]; then
  ovmf_code=${DINX_INSTALL_OVMF_CODE:-}
  ovmf_vars_template=${DINX_INSTALL_OVMF_VARS:-}
  if [[ -z "$ovmf_code" ]]; then
    for candidate in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
      if [[ -r "$candidate" ]]; then
        ovmf_code=$candidate
        break
      fi
    done
  fi
  if [[ -z "$ovmf_vars_template" ]]; then
    for candidate in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do
      if [[ -r "$candidate" ]]; then
        ovmf_vars_template=$candidate
        break
      fi
    done
  fi
  [[ -r "$ovmf_code" ]] || fail 'OVMF code firmware is missing'
  [[ -r "$ovmf_vars_template" ]] || fail 'OVMF variables template is missing'
  ovmf_vars="$work_dir/OVMF_VARS.fd"
  cp "$ovmf_vars_template" "$ovmf_vars"
  qemu_args+=(
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
    -drive "if=pflash,format=raw,file=$ovmf_vars"
  )
fi
set +e
timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 "${qemu_args[@]}" &
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
if [[ "$firmware_mode" == bios ]]; then
  root_device="${loop_device}p1"
else
  root_device="${loop_device}p2"
fi
for _ in {1..20}; do
  [[ -b "$root_device" ]] && break
  udevadm settle 2>/dev/null || true
  sleep 1
done
[[ -b "$root_device" ]] || fail "installed partition device did not reappear: $root_device"
mkdir -p "$target_dir"
mount "$root_device" "$target_dir"
mounted_target=true
if [[ -s "$target_dir/var/lib/dinx/install-smoke.failed" ]]; then
  cat "$target_dir/var/lib/dinx/install-smoke.failed" >&2
  fail 'installed runtime lifecycle checks failed'
fi
[[ -s "$target_dir/var/lib/dinx/install-smoke.booted" ]] || {
  [[ -s "$serial_log" ]] && cat "$serial_log" >&2 || true
  fail 'dinit first-boot marker was not created'
}
[[ -L "$target_dir/etc/dinit.d/boot.d/getty@tty2" ]] || fail 'recovery TTY service is not enabled'
grep -Fqx 'pacman_database=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'installed pacman database check did not pass'
grep -Fqx 'core_packages=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'installed core package check did not pass'
grep -Fqx 'dinit_services=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'installed dinit service check did not pass'
grep -Fqx 'dynamic_libraries=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'installed dynamic library check did not pass'
grep -Fqx 'optional_base_absent=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'optional package leaked into the base ISO'
grep -Fqx 'lifecycle_checks=true' "$target_dir/var/lib/dinx/install-smoke.booted" \
  || fail 'installed lifecycle checks did not complete'
printf 'smoke-install: installed pacman, dinit service, library and optional-package contracts passed\n'
printf 'smoke-install: persistent install and first-boot recovery contract passed\n'

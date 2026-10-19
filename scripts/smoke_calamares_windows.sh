#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || {
    printf 'smoke-calamares-windows: root or sudo is required\n' >&2
    exit 1
  }
  exec sudo "$0" "$@"
fi

fail() {
  printf 'smoke-calamares-windows: %s\n' "$*" >&2
  exit 1
}

for command in losetup sfdisk blkid mkfs.ext4 mkfs.fat mkntfs ntfsresize mount umount grub-install udevadm; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

work_dir=$(mktemp -d)
loop_devices=()
mount_points=()
cleanup() {
  set +e
  for mount_point in "${mount_points[@]}"; do
    umount "$mount_point" 2>/dev/null || true
  done
  for loop_device in "${loop_devices[@]}"; do
    losetup -d "$loop_device" 2>/dev/null || true
  done
  rm -rf "$work_dir"
}
trap cleanup EXIT

wait_for_block_device() {
  local device=$1
  for _ in {1..20}; do
    [[ -b "$device" ]] && return 0
    udevadm settle 2>/dev/null || true
    sleep 1
  done
  fail "partition device did not appear: $device"
}

attach_image() {
  local image=$1
  attached_device=$(losetup --find --show --partscan "$image")
  loop_devices+=("$attached_device")
}

detach_image() {
  local device=$1
  losetup -d "$device"
  for index in "${!loop_devices[@]}"; do
    if [[ "${loop_devices[index]}" == "$device" ]]; then
      unset 'loop_devices[index]'
      break
    fi
  done
}

create_windows_table() {
  local image=$1
  local include_root=$2
  truncate -s 6G "$image"
  if [[ "$include_root" == true ]]; then
    printf 'label: gpt\n, 512M, U\n, 2G, EBD0A0A2-B9E5-4433-87C0-68B6B72699C7\n, 2G, L\n' |
      sfdisk --wipe always "$image" >/dev/null
  else
    printf 'label: gpt\n, 512M, U\n, 2G, EBD0A0A2-B9E5-4433-87C0-68B6B72699C7\n' |
      sfdisk --wipe always "$image" >/dev/null
  fi
}

seed_windows_layout() {
  local image=$1
  local loop_device efi_device windows_device efi_mount
  attach_image "$image"
  loop_device=$attached_device
  efi_device="${loop_device}p1"
  windows_device="${loop_device}p2"
  wait_for_block_device "$efi_device"
  wait_for_block_device "$windows_device"
  mkfs.fat -F 32 -n SYSTEM "$efi_device" >/dev/null
  mkntfs -F -L WINDOWS "$windows_device" >/dev/null 2>&1
  ntfsresize --info "$windows_device" >/dev/null
  efi_mount="$work_dir/seed-efi"
  mkdir -p "$efi_mount"
  mount "$efi_device" "$efi_mount"
  mount_points+=("$efi_mount")
  mkdir -p "$efi_mount/EFI/Microsoft/Boot"
  printf 'dinx-windows-boot-manager\n' > "$efi_mount/EFI/Microsoft/Boot/bootmgfw.efi"
  sync
  umount "$efi_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  detach_image "$loop_device"
}

simulate_side_by_side_shrink() {
  local image=$1
  local loop_device windows_device
  attach_image "$image"
  loop_device=$attached_device
  windows_device="${loop_device}p2"
  wait_for_block_device "$windows_device"
  ntfsresize --size 1G "$windows_device" >/dev/null
  detach_image "$loop_device"
  printf 'label: gpt\n, 512M, U\n, 1G, EBD0A0A2-B9E5-4433-87C0-68B6B72699C7\n, 2G, L\n' |
    sfdisk --wipe never "$image" >/dev/null
}

assert_windows_preserved() {
  local image=$1
  local mode=$2
  local loop_device efi_device windows_device root_device efi_mount root_mount boot_dir
  local root_uuid efi_uuid table_dump
  attach_image "$image"
  loop_device=$attached_device
  efi_device="${loop_device}p1"
  windows_device="${loop_device}p2"
  root_device="${loop_device}p3"
  wait_for_block_device "$efi_device"
  wait_for_block_device "$windows_device"
  wait_for_block_device "$root_device"
  table_dump="$work_dir/${mode}.sfdisk"
  sfdisk --dump "$image" > "$table_dump"
  grep -Fq 'type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "$table_dump" || fail "$mode lost the existing EFI System Partition"
  grep -Fq 'type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7' "$table_dump" || fail "$mode lost the Windows partition type"
  grep -Fq 'type=0FC63DAF-8483-4772-8E79-3D69D8477DE4' "$table_dump" || fail "$mode did not create the Linux root partition"
  [[ "$(blkid -s TYPE -o value "$windows_device")" == ntfs ]] || fail "$mode reformatted the Windows partition"
  [[ "$(blkid -s LABEL -o value "$windows_device")" == WINDOWS ]] || fail "$mode changed the Windows partition label"
  mkfs.ext4 -F -L DINX_ROOT "$root_device" >/dev/null
  root_mount="$work_dir/${mode}-root"
  efi_mount="$work_dir/${mode}-efi"
  boot_dir="$work_dir/${mode}-boot"
  mkdir -p "$root_mount" "$efi_mount" "$boot_dir"
  mount "$root_device" "$root_mount"
  mount_points+=("$root_mount")
  root_uuid=$(blkid -s UUID -o value "$root_device")
  mount "$efi_device" "$efi_mount"
  mount_points+=("$efi_mount")
  efi_uuid=$(blkid -s UUID -o value "$efi_device")
  printf 'UUID=%s / ext4 defaults 0 1\nUUID=%s /boot/efi vfat umask=0077 0 2\n' \
    "$root_uuid" "$efi_uuid" > "$root_mount/fstab"
  printf 'dinx-windows-%s-root\n' "$mode" > "$root_mount/partition-smoke.marker"
  grub-install \
    --target=x86_64-efi \
    --efi-directory="$efi_mount" \
    --boot-directory="$boot_dir" \
    --bootloader-id=DINX \
    --no-nvram \
    --removable \
    --recheck >/dev/null
  grep -Fq 'dinx-windows-boot-manager' "$efi_mount/EFI/Microsoft/Boot/bootmgfw.efi" ||
    fail "$mode overwrote the existing Windows Boot Manager path"
  [[ -f "$efi_mount/EFI/BOOT/BOOTX64.EFI" ]] || fail "$mode did not install the DINX EFI fallback"
  umount "$efi_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  umount "$root_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  detach_image "$loop_device"

  attach_image "$image"
  loop_device=$attached_device
  root_device="${loop_device}p3"
  efi_device="${loop_device}p1"
  windows_device="${loop_device}p2"
  wait_for_block_device "$root_device"
  mount "$root_device" "$root_mount"
  mount_points+=("$root_mount")
  grep -Fq "dinx-windows-${mode}-root" "$root_mount/partition-smoke.marker" || fail "$mode root transaction did not survive remount"
  grep -Fq "$root_uuid / ext4" "$root_mount/fstab" || fail "$mode fstab transaction did not survive remount"
  umount "$root_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  mount "$efi_device" "$efi_mount"
  mount_points+=("$efi_mount")
  grep -Fq 'dinx-windows-boot-manager' "$efi_mount/EFI/Microsoft/Boot/bootmgfw.efi" || fail "$mode lost Windows EFI content after remount"
  umount "$efi_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  [[ "$(blkid -s TYPE -o value "$windows_device")" == ntfs ]] || fail "$mode changed the Windows filesystem after remount"
  detach_image "$loop_device"
  printf 'smoke-calamares-windows: %s preserved Windows ESP/NTFS and completed DINX boot transaction\n' "$mode"
}

side_by_side_image="$work_dir/dinx-windows-side-by-side.img"
manual_image="$work_dir/dinx-windows-manual.img"
create_windows_table "$side_by_side_image" false
seed_windows_layout "$side_by_side_image"
simulate_side_by_side_shrink "$side_by_side_image"
assert_windows_preserved "$side_by_side_image" side-by-side
create_windows_table "$manual_image" true
seed_windows_layout "$manual_image"
assert_windows_preserved "$manual_image" manual
printf 'calamares_windows_smoke=existing_esp=true ntfs_preserved=true side_by_side=true manual=true grub_preserved=true\n'

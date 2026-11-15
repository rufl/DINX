#!/usr/bin/env bash
set -euo pipefail

# Reproducible DINX-BSD VirtualBox path. The guest desktop is exposed by
# wayvnc because FreeBSD 15.1 has no VirtualBox DRM driver.

usage() {
  cat <<'EOF'
Usage:
  virtualbox-visual-test.sh install [ISO]
  virtualbox-visual-test.sh start
  virtualbox-visual-test.sh detach-iso
  virtualbox-visual-test.sh status
  virtualbox-visual-test.sh stop
  virtualbox-visual-test.sh vnc

Environment overrides: DINX_VBOX_NAME, DINX_VBOX_DIR, DINX_VBOX_MEMORY,
DINX_VBOX_CPUS, DINX_VBOX_DISK_GB, DINX_VBOX_VNC_PORT.
EOF
}

die() { printf 'virtualbox-visual-test: %s\n' "$*" >&2; exit 1; }
need_vbox() { command -v VBoxManage >/dev/null 2>&1 || die 'VBoxManage não encontrado'; }

command_name=${1:-}
iso=${2:-${DINX_BSD_ISO:-dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso}}
name=${DINX_VBOX_NAME:-DINX-BSD}
vm_dir=${DINX_VBOX_DIR:-${HOME}/VirtualBox VMs/${name}}
memory=${DINX_VBOX_MEMORY:-4096}
cpus=${DINX_VBOX_CPUS:-4}
disk_gb=${DINX_VBOX_DISK_GB:-32}
vnc_port=${DINX_VBOX_VNC_PORT:-5900}
disk=${vm_dir}/${name}.vdi

exists() { VBoxManage showvminfo "$name" >/dev/null 2>&1; }

configure_forwarding() {
  VBoxManage modifyvm "$name" --nic1 nat
  VBoxManage modifyvm "$name" --natpf1 delete dinx-vnc >/dev/null 2>&1 || true
  VBoxManage modifyvm "$name" --natpf1 "dinx-vnc,tcp,127.0.0.1,${vnc_port},,5900"
}

create_vm() {
  [ -r "$iso" ] || die "ISO não encontrada: $iso"
  exists && return 0
  mkdir -p "$vm_dir"
  VBoxManage createvm --name "$name" --ostype FreeBSD_64 --basefolder "$vm_dir" --register
  VBoxManage modifyvm "$name" \
    --memory "$memory" --cpus "$cpus" --firmware efi \
    --graphicscontroller vboxsvga --vram 128 --boot1 dvd --boot2 disk \
    --nic1 nat
  VBoxManage storagectl "$name" --name SATA --add sata --controller IntelAhci
  VBoxManage createhd --filename "$disk" --size "$((disk_gb * 1024))" --format VDI
  VBoxManage storageattach "$name" --storagectl SATA --port 0 --device 0 \
    --type hdd --medium "$disk"
  VBoxManage storageattach "$name" --storagectl SATA --port 1 --device 0 \
    --type dvddrive --medium "$iso"
  configure_forwarding
  printf 'VM criada: %s\nISO anexada: %s\nVNC: 127.0.0.1:%s -> guest:5900\n' \
    "$name" "$iso" "$vnc_port"
}

start_vm() {
  exists || die "VM não existe; use install primeiro"
  configure_forwarding
  VBoxManage startvm "$name" --type gui
  printf 'Console VirtualBox iniciado. Depois conecte VNC em 127.0.0.1:%s\n' "$vnc_port"
}

if [ "$command_name" = -h ] || [ "$command_name" = --help ] || [ "$command_name" = help ]; then
  usage
  exit 0
fi
need_vbox
case "$command_name" in
  install)
    create_vm
    start_vm
    ;;
  start)
    start_vm
    ;;
  detach-iso)
    exists || die "VM não existe"
    VBoxManage controlvm "$name" acpipowerbutton >/dev/null 2>&1 || true
    sleep 2
    VBoxManage storageattach "$name" --storagectl SATA --port 1 --device 0 \
      --type dvddrive --medium none
    VBoxManage modifyvm "$name" --boot1 disk --boot2 none
    printf 'ISO removida; próximo boot usa o disco instalado.\n'
    ;;
  status)
    exists || die "VM não existe"
    VBoxManage showvminfo "$name" --machinereadable \
      | grep -E '^(VMState|VMName|nic1|Forwarding)' || true
    ;;
  stop)
    exists || die "VM não existe"
    VBoxManage controlvm "$name" acpipowerbutton
    ;;
  vnc)
    if command -v vncviewer >/dev/null 2>&1; then
      exec vncviewer "127.0.0.1::${vnc_port}"
    fi
    printf 'Conecte um cliente VNC a 127.0.0.1:%s\n' "$vnc_port"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

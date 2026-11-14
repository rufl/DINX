# DINX-BSD no VirtualBox — como testar

Alvo: FreeBSD 15.1-RELEASE amd64. ISO: `dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso`.

## Restrição fundamental do FreeBSD no VirtualBox

Não existe driver DRM para a GPU virtual do VirtualBox no FreeBSD 15.1:
`vboxvideo` e `vmwgfx` foram removidos do `drm-kmod`
([freebsd/drm-kmod#356](https://github.com/freebsd/drm-kmod/issues/356)) e o
`drm-612-kmod` disponível fornece apenas `amdgpu`, `i915kms` e `radeonkms`.
Sem `/dev/dri`, nenhum compositor wlroots consegue fazer scanout no console da
VM. O mesmo vale para QEMU, exceto com `virtio-gpu` + driver do PR
[drm-kmod#499](https://github.com/freebsd/drm-kmod/pull/499) (ainda não está nos
ports).

Consequência prática: **no VirtualBox o desktop é acessado por VNC, não pela
janela da VM.** A sessão detecta a ausência de `/dev/dri`, roda o Aqueous no
backend headless (renderização em software, llvmpipe) e o `wayvnc` publica a
sessão na porta 5900. É o mesmo desenho que `dinx-pearl-session` aplica.

## Configuração da VM

| Item | Valor |
|---|---|
| Tipo/versão | Other → FreeBSD (64-bit) |
| Firmware | **UEFI** (o sistema instalado exige UEFI) |
| RAM | 4096 MB (renderização em software; 2 GB funciona mas é lento) |
| CPU | 4 vCPU |
| Disco | ≥ 32 GB |
| Rede | NAT |
| Controlador gráfico | VBoxSVGA (irrelevante: não há driver DRM) |

Forwarding de porta (obrigatório para ver o desktop):

```sh
VBoxManage modifyvm "DINX-BSD" --nic-forward "hostport=5900,guestport=5900"
```

Ou na GUI: Configurações → Rede → NAT → Port Forwarding → adicionar
`TCP host 127.0.0.1:5900 → guest 5900`.

## Instalação

1. Anexe a ISO e dê boot. O sistema sobe como live (autologin no console).
2. Rode o instalador: `dinx-installer` (ou o atalho "Install DINX" no desktop,
   quando houver saída de vídeo). O particionamento é scriptado e apaga o disco.
3. Após o fim, remova a ISO e reinicie.

O primeiro boot do sistema instalado dispara `rc.d/dinx_firstboot`, que instala
em background (log em `/var/log/dinx-firstboot.log`):

- deps de runtime auditadas (`scripts/bsd-vm/check-shlibs.py`): seatd, wayland,
  libxkbcommon, xkeyboard-config, libxcb + xcb-util-*, libdrm, libdisplay-info,
  libliftoff, mesa-libs, mesa-dri, vulkan-loader, libinput, libevdev,
  libudev-devd, pixman, png, cairo, gdk-pixbuf2, glib, gtk4, gtk4-layer-shell,
  lcms2, libarchive, libxml2, libsecret, polkit, curl, cups, pulseaudio,
  pipewire, wireplumber, xwayland, wayvnc, basu, jq
- pacotes nativos do repo local embarcado na ISO: `dinx-compat`, `dinx-wlroots`,
  `dinx-aqueous`, `dinx-pearl`, `dinx-greetd`

Isso leva alguns minutos (download dos pacotes + primeira indexação). Acompanhe:

```sh
tail -f /var/log/dinx-firstboot.log
```

## Acessando o desktop

Quando o firstboot terminar, ele habilita e inicia `seatd` e `dinx_greetd`.
O greetd roda a sessão em `vt1`; sem `/dev/dri` o wrapper cai em headless e
sobe o `wayvnc` na porta 5900.

Verifique no guest:

```sh
pgrep -l "aqueous|pearl|wayvnc"
sockstat -4l | grep 5900
```

No host, conecte qualquer cliente VNC a `127.0.0.1:5900` (sem senha por padrão
— rede NAT da VM, não exponha a porta).

## O que já está verificado

Validado em VM FreeBSD 15.1 (QEMU, headless, llvmpipe) com os binários nativos
desta ISO:

- Aqueous sobe e cria `WAYLAND_DISPLAY=wayland-1` e
  `AQUEOUS_SOCKET=/home/dinx/.run/aqueous/<hash>/ipc.sock`
- Xwayland funcional: `XWAYLAND_OK version number: 11.0`, cliente X11 real
  anexa (`XTERM_WINDOWS=1`) e exibe texto na tela
- Pearl inicia: `event=ready mode=session`, `app-index-ready entries=5`
- Captura por `wlr-screencopy` (grim) produz PNG 1280×720
- Acesso remoto do host por VNC: handshake RFB 3.8 OK (desktop `WayVNC`,
  1280×720) e framebuffer completo decodificado (921600/921600 pixels)

Evidências: `docs/proof/aqueous-desktop-xwayland.png`,
`docs/proof/vnc-host-desktop.png`. Scripts: `scripts/bsd-vm/aqueous-proof.sh`,
`scripts/bsd-vm/vnc-proof.sh`, `scripts/bsd-vm/vnc-framebuffer-grab.py`.

## O que ainda não foi verificado no VirtualBox

- **greetd no `vt1`**: instala e habilita, mas o greeter em tela não foi
  validado (exige o console vt(4) do boot gráfico da VBox).
- **Boot live + `dinx-installer` na VBox**: o gate automatizado roda em QEMU
  (serial); o fluxo UEFI na VBox não foi exercitado.
- **Aceleração 3D**: inexistente — tudo em llvmpipe (software). Espere
  animações lentas.
- **Áudio por VNC**: não há canal de áudio no VNC; PipeWire/Pulse rodam no
  guest sem saída.
- **Hardware real com GPU AMD/Intel**: caminho que daria scanout direto
  (`i915kms`/`amdgpu`), não testado.

## Se algo não subir

Ordem de diagnóstico dentro do guest:

```sh
tail -40 /var/log/dinx-firstboot.log      # deps + pacotes nativos
mount | grep linprocfs                     # /proc precisa estar montado
pgrep -l "aqueous|pearl|wayvnc|greetd"
cat /var/log/dinx-firstboot.log | grep WARNING
```

`/proc` é obrigatório: o Pearl resolve o próprio executável por
`/proc/self/exe` e lê `/proc/stat`, `/proc/meminfo`, `/proc/cpuinfo`. O
`installerconfig` grava a entrada de `linprocfs` no `/etc/fstab`; se estiver
ausente, monte manualmente:

```sh
mount -t linprocfs linprocfs /proc
```

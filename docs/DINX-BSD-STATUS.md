# DINX-BSD — Status completo: o que funciona e o que não funciona

Data: 2026-11-20 (rodada river + kwm + kwim + morghulis + KwmTags; publisher+consumer; river como sessão padrão). Branch `feat/bsd`. Alvo: FreeBSD 15.1-RELEASE amd64.
Este documento consolida o estado real do effort BSD, separado por nível de
evidência. Nada aqui é claim de roadmap: cada item cita a evidência observada
ou a limitação encontrada. O journal detalhado de causas raiz está em
`docs/DINX-BSD-PROCESS.md` (§§1–26).

Legenda:
- **[V]** verificado nesta rodada por execução (log/saída citada).
- **[I]** implementado em milestones anteriores; não re-verificado nesta rodada.
- **[B]** bloqueado / não funciona; causa e evidência citadas.
- **[D]** funciona com degradação ou restrição operacional.

---

## 1. Pipeline de ISO

### Funciona
- **[V]** `scripts/build-bsd-iso.sh`: remaster do disc1 FreeBSD 15.1 (SHA-256
  pinado `fa27646f05a1440f…`), embed de `base.txz`/`kernel.txz` (install
  offline, sem prompt de mirror), overlay `dinx-bsd-overlay.txz` com 192
  arquivos, `installerconfig` scriptado, boot BIOS+UEFI preservado.
  Evidência: `check-bsd-iso: boot=BIOS+UEFI installer=scripted
  overlay_sha256=e7a20e130924c05ea87c779c1cbd59b31ebe67e450c3867cf456c2c0a2f0666b
  overlay_files=192`.
- **[V]** ISO final: `dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso`,
  sha256 `32a58e9432599d50055c19a7475ab4b19aaa847bb625fe94e8fc92615fa342e8`,
  checksum verificado pelo próprio build.
- **[V]** `scripts/check-bsd-iso.sh`: valida paths obrigatórios do overlay
  (incl. `usr/local/share/themes/DINX/index.theme`), manifesto e boot.
- **[V]** Repo local de pacotes nativos embarcado no overlay em
  `usr/local/share/dinx-bsd/distro/bsd/ports/pkg/repo/` (5 `.pkg` +
  `packagesite.pkg` + `data.pkg`), confirmado por `ls` no sistema instalado.
- **[I]** Live system com wizard de first-run (`dinx-first-run`), persistência
  em USB (`dinx-live-persist`), installer a partir da sessão live
  (`dinx-installer`): implementados em milestones anteriores; não re-executados
  nesta rodada (o gate desta rodada usa o caminho unattended).

### Não funciona / restrições
- **[B]** Nada quebrado no pipeline em si; a restrição é de conteúdo: a ISO
  instala o stack gráfico, mas a sessão gráfica não sobe (ver §4).

---

## 2. Instalação unattended e gate QEMU

### Funciona
- **[V]** `scripts/build-bsd-iso-unattended.py`: gate em duas fases (boot live
  → install scriptado → boot do instalado). Marcadores exigidos:
  `dinx-bsd: first-boot-ready release=foundation` + prompt `login:`.
  Evidência: execuções de 127 s e 147 s com sucesso.
- **[V]** Shutdown limpo do guest no gate: login `root` + `shutdown -p now`
  repetido 2× com espera, `process.wait(timeout=90)`. Eliminou a corrupção de
  UFS que ocorria com kill hard do QEMU (journal §18).
- **[V]** `installerconfig` em duas partes (preamble antes do `#!`, script
  POSIX chrooted): hostname, DHCP, console serial 115200, `dinx_marker`,
  `dinx_firstboot`, `dinx_first_run`, remoção de `resolv.conf` vazio.
- **[V]** Firstboot destacado via `daemon(8)` (`rc.d/dinx_firstboot`): não
  bloqueia o boot; log em `/var/log/dinx-firstboot.log`.

### Não funciona / restrições
- **[D]** `cache=writeback` no QEMU torna a extração do `base.txz` lenta demais
  (>21 min, morto no timeout de 1300 s) vs 142 s com `cache=unsafe`. O gate usa
  `unsafe` + unmount limpo (durabilidade vem do guest, não do cache).
- **[D]** Console serial do QEMU trunca linhas de entrada longas (~256 chars):
  comandos grandes viram prompt de continuação e travam o shell. Operação
  correta: enviar scripts via HTTP/fetch e executar com linhas curtas.
- **[B]** SSH por pubkey para a VM nunca autenticou (`Server accepts key` e
  depois falha, sem linha de publickey no auth.log; causa não identificada).
  Contorno em uso: serial + HTTP (host→guest) + netcat (guest→host).

---

## 3. Build nativo dos ports (dentro da VM FreeBSD)

### Funciona
- **[V]** `scripts/bsd-vm/setup-build-vm.sh`: deps (wlroots020, wayland,
  gtk4, gtk4-layer-shell, meson, ninja, rust, bash, libsecret, libarchive,
  glslang, …), Zig 0.17.0 FreeBSD, clones de Aqueous/pearl/greetd.
- **[V]** `scripts/bsd-vm/build-native.sh` + `patch-freebsd.py` (21 patches) +
  `dinxcompat.c`: todos os alvos compilam no FreeBSD:
  - wlroots 0.20.2 patcheado (render/presentation hook, meson+vulkan+glslang);
  - Aqueous 1.0.5 (Zig, `zig build exit=0`);
  - Pearl 0.3.9 (Zig/GTK4, `zig build exit=0`, 11 binários: pearl, pearl-agent,
    pearl-lock, pearl-settings, pearlctl, pearl-themes, pearl-capture-picker,
    pearl-preview-helper, pearl-t00, xdg-desktop-portal-pearl, …);
  - greetd 0.10.3 (cargo, `cargo exit=0`, binários greetd + agreety);
  - libdinxcompat (cc, shims statx/mallopt/`__progname`/`__errno_location`/
    `sd_pidfd_get_user_unit`/`environ`).
- **[V]** Pacotes reais: `pkg create` + repack com injeção de
  `shlibs_provided`; `pkg repo` gera catálogo. `pkg add` dos 5 pacotes = 0
  (compat, wlroots, aqueous, pearl, greetd), na ordem de dependência.
- **[V]** Patches de porting que funcionam: headers Linux shim
  (input-event-codes, sysmacros), prctl→procctl (Pearl e greetd), ioctls de VT
  stubados no FreeBSD com `*const` (nix write_ptr), `/dev/ttyvN`, basu no lugar
  de sd-bus, `AT.EMPTY_PATH`/siginfo/PTHREAD_ONCE_INIT/`AT_CLKTCK`,
  `--as-needed`→`.needed = true` para o shim, e roteamento de
  `std.os.linux.statx` para o statx libc do shim
  (`@extern(*const fn … callconv(.c) c_int, .{ .name = "statx" })`).
- **[I]** Linter de Makefiles (`scripts/check_bsd_ports_syntax.py`, 54 ports)
  integrado ao `check_dinx_bsd.sh`: milestone anterior.

### Não funciona / restrições (bugs de empacotamento descobertos e corrigidos)
- **[V→corrigido]** `pkg create -m` não varre rootdir; com `-p` o plist usa
  paths absolutos de instalação e o rootdir é o stage; `shlibs_provided` nunca
  é calculado com `-p` e campo escrito à mão é descartado → pós-injeção via
  bsdtar (`tar -P -cf … -s '|^usr|/usr|'`, editando +MANIFEST e
  +COMPACT_MANIFEST). Sem isso: "Missing shlib libdinxcompat.so" ou
  "//usr/local/… not specified in the manifest".
- **[V→corrigido]** bsdtar remove `/` inicial sem `-P`; `-s` agrupado em `-cfP`
  é parseado como arquivo; `+DESC` pode não existir no repack.
- **[V→corrigido]** `dinx-wlroots` conflita com `wlroots020` (mesmos arquivos):
  firstboot não instala mais `wlroots020`.
- **[V→corrigido]** Ordem de build: `dinxcompat` precisa existir antes do
  Aqueous (linka `-ldinxcompat`); `pkg delete` remove a lib entre rodadas.
- **[D]** Zig 0.16 vs 0.17: o toolchain da VM é 0.17.0 (tarball FreeBSD); o
  Pearl upstream exigia 0.16.0 em milestones antigos — os fontes atuais
  (Seafoam-Labs) compilam com 0.17 após os patches.

---

## 4. Sessão gráfica (Aqueous + Xwayland + Pearl) — estado atual

O compositor da sessão é o **Aqueous** com `-Dxwayland=true`, lançando o shell
via `aqueous -c <init>` (contrato do compositor: ele cria os sockets e injeta
`WAYLAND_DISPLAY`/`AQUEOUS_SOCKET`/`DISPLAY` no filho init). O Weston nativo
foi construído como alternativa enquanto o crash do Aqueous estava sem
diagnóstico; a causa real era SIGSYS por syscalls Linux crus, não o socket.

### Funciona (verificado em VM FreeBSD 15.1)
- **[V]** **Aqueous sobe e serve clientes.** Sockets criados pelo compositor:
  `WAYLAND_DISPLAY=wayland-1`, `AQUEOUS_SOCKET=/home/dinx/.run/aqueous/<hash>/ipc.sock`,
  `DISPLAY=:0`. Processos vivos simultaneamente: `aqueous`, `pearl`, `wayvnc`, `xterm`.
- **[V]** **Xwayland funcional:** `XWAYLAND_OK version number: 11.0` e um cliente
  X11 real anexa (`XTERM_WINDOWS=1`), exibindo `DINX_X11_OK` na tela.
- **[V]** **Pearl shell inicia:** `PEARL_ALIVE=yes`,
  `info(pearl): event=ready mode=session`, `app-index-ready entries=5`.
- **[V]** **Captura do compositor:** `GRIM_RC=0` via `wlr-screencopy` →
  `docs/proof/aqueous-desktop-xwayland.png` (1280×720): janela xterm com cantos
  arredondados e contorno teal do pipeline Vulkan, cursor, texto do X11.
- **[V]** **Desktop acessível remotamente do host (caminho VirtualBox):**
  Aqueous headless + `wayvnc` em `*:5900` →
  `scripts/bsd-vm/vnc-handshake-check.py` retorna `VNC_HANDSHAKE_OK`
  (desktop `'WayVNC'`, 1280×720) e `vnc-framebuffer-grab.py` decodifica
  **921600/921600 pixels** com 58 cores distintas → `docs/proof/vnc-host-desktop.png`.
  Nenhum driver DRM é necessário nesse caminho.
- **[V]** Weston 14.0.2 também compila/instala nativamente (alternativa), com
  socket Wayland escutando e `weston-desktop-shell`/`weston-keyboard` vivos.
- **[V]** Build nativo completo do repo: `dinx-aqueous`, `dinx-pearl`,
  `dinx-greetd`, `dinx-wlroots`, `dinx-compat`, `dinx-weston` + catálogo `pkg repo`.

### Não funciona (blockers abertos)
- **[B]** **Sem scanout local em VM:** `drm-612-kmod` no FreeBSD 15.1 fornece só
  `amdgpu`/`i915kms`/`radeonkms`; `vboxvideo`/`vmwgfx` foram removidos
  ([drm-kmod#356](https://github.com/freebsd/drm-kmod/issues/356)) e `virtio_gpu`
  é PR não-mergeado (#499). Logo VirtualBox e QEMU padrão não têm `/dev/dri` →
  o desktop só aparece por VNC (wayvnc) ou X11 nested, não no console da VM.
- **[B]** **Backend x11 do wlroots sem Xorg:** `wlr_x11_backend_create` existe na
  lib, mas `WLR_BACKENDS=x11` falha com `Failed to open xcb connection` porque o
  Xorg não subiu — o driver `scfb` precisa de `/dev/fb0`, que só existe com
  `graphics/virtio-gpu-qemu-kmod` (QEMU/UTM, sem equivalente VBox).
- **[B]** **Weston + Xwayland:** segfault (signal 11) ao lançar o filho Xwayland
  (`Couldn't unset CLOEXEC on child FDs`); não reproduz sob gdb (race). Por isso
  o Weston não é o compositor da sessão.
- **[V]** **greetd inicia após o first-run:** com `first-run-done`, o gate
  observou `greetd`, `greetd --session-worker` e `agreety` persistentes no
  disco instalado; o serviço não inicia antes desse marcador.
- **[B]** **Login greetd → sessão Pearl:** a transição interativa ainda não foi
  comprovada no QEMU; sem DRM local, a validação visual continua dependente de
  VNC/teclado virtual ou hardware AMD/Intel.
- **[B]** **Hardware real (AMD/Intel com DRM):** não testado — é o caminho que
  daria scanout direto sem VNC.

### Restrições operacionais (documentadas, com contorno aplicado)
- **[D]** `linprocfs` em `/proc` é **obrigatório**: o Pearl lê `/proc/self/exe`
  (14 usos) e `/proc/stat`, `/proc/meminfo`, `/proc/cpuinfo`. Sem isso ele morre
  com `error=ExecutableUnavailable`. O usuário da sessão não pode montar, então o
  `installerconfig` grava a entrada no `/etc/fstab`.
- **[D]** O compositor **não seta** `XDG_CURRENT_DESKTOP`; o init da sessão o
  exporta como `Aqueous`, senão o Pearl recusa a sessão.
- **[D]** O Aqueous tem idle-exit: só um cliente IPC conectado renova o timer.
  Por isso o shell é lançado **pelo init** (`aqueous -c`), nunca em paralelo.
- **[D]** `su -m dinx` preserva `HOME=/root` → `AccessDenied`; setar
  `HOME=/home/dinx`. `XDG_RUNTIME_DIR` deve ser 0700 sob o home (não `/tmp`),
  e o subdir `aqueous/` também (checagem `InsecureRuntimeDirectory`).
- **[D]** Helpers Zig (`aqueousctl`) não exportam `environ` → usar `LD_PRELOAD`
  do shim neles; **nunca** no compositor.
- **[D]** GTK nos ports é 4.20.4 (Pearl pede 4.22.5): `backdrop-filter` removido
  do CSS e floor baixado (patches #27/#28) — o blur cosmético fica indisponível.
- **[D]** Serial do QEMU trunca linhas >~256 chars e o read fica defasado um
  comando; usar `fetch` + `push.sh` e comandos curtos.

---

## 5. Firstboot / stack de runtime no sistema instalado

### Funciona
- **[V]** `scripts/install-dinx-bsd.sh` (via `rc.d/dinx_firstboot`) instala as
  **46 shlibs_required auditadas** dos pacotes nativos (30 provedores:
  seatd, wayland, libxkbcommon, xkeyboard-config, libxcb + xcb-util-errors/
  renderutil/wm, libdrm, libdisplay-info, libliftoff, mesa-libs, mesa-dri,
  vulkan-loader, libinput, libevdev, libudev-devd, pixman, png, cairo,
  gdk-pixbuf2, glib, gtk4, gtk4-layer-shell, lcms2, libarchive, libxml2,
  libsecret, polkit, curl, cups, pulseaudio, pipewire, wireplumber) mais
  xwayland, wayvnc, basu, jq; habilita o repo local e instala dinx-compat,
  dinx-wlroots, dinx-greetd, dinx-aqueous, dinx-pearl; instala drm-kmod e
  vulkan-tools; cria `dinx` (grupo `video`)/`greeter`; escreve o PAM do greetd
  e o config.toml; habilita seatd + dinx_greetd.
  Auditoria: `scripts/bsd-vm/check-shlibs.py` (MISSING: 0) e
  `scripts/bsd-vm/check-dep-names.sh` (`bad=0`, todos os 41 nomes existem no
  catálogo do 15.1). Sem essa lista o `pkg add` falharia com "Missing shlib",
  porque os manifests declaram `shlibs_required` mas nenhum `deps`.
- **[V]** `installerconfig` grava `linproc` no `/etc/fstab`: o usuário da
  sessão não pode montar filesystems, e o Pearl exige `/proc/self/exe`.
- **[V]** Contas, PAM (`pam_unix` auth + `pam_permit` account/session) e
  config do greetd (`vt=8`, `switch=false`, `agreety` → `dinx-session-select`);
  o serviço é bloqueado até `first-run-done`.

- **[V]** O firstboot do gate final concluiu (`DINX_COMPLETE`) após instalar o
  stack nativo e habilitar seatd/greetd; a lista detalhada permanece no log.
- **[V]** O wizard executa no disco instalado (`dinx-first-run` + `bsddialog`);
  `ttyv0` fica reservado ao wizard e `TERM=xterm` é definido explicitamente.
- **[I]** Stack gaming/Linuxulator (wine-proton, libc6-shim, linux-steam-utils,
  rl9, sysctls LSU, kld_list, conta games): implementado em milestone
  anterior; firstboot instala os pacotes, mas **nenhum jogo/sessão Linux foi
  exercitado** nesta rodada.

### Não funciona / notas
- **[D]** `noctalia` (shell alternativo) não existe no repo → firstboot registra
  NOTE e segue (comportamento esperado, não falha).
- **[B]** Login greetd → sessão Pearl no disco instalado ainda não foi
  comprovado; o serviço e seus workers iniciam, mas a autenticação/transição
  interativa no VT8 não foi capturada de ponta a ponta.
- **[D]** `dinx-weston` continua buildável (`build-weston.sh`) mas não é
  embarcado nem instalado: o Xwayland dele segfaulta no FreeBSD.

---

## 6. Temas e identidade visual

### Funciona
- **[V]** Overlay de temas em `usr/local/share/themes/DINX` (gtk-3.0/gtk-4.0
  css), `usr/local/share/color-schemes/DINXDark.colors`,
  `usr/local/share/dinx/theme/DINX.json`, seed qt6ct em `etc/skel`,
  `index.theme` criado nesta rodada (exigência do check da ISO).
- **[V]** `check-bsd-iso.sh` passa com o overlay corrigido (192 arquivos).

### Não funciona
- **[B]** Aplicação visual dos temas na sessão: não verificável sem sessão
  gráfica (§4). Os arquivos estão instalados; o efeito em tela não foi visto.

---

## 7. Infraestrutura de teste/VM (ferramentas desta rodada)

### Funciona
- **[V]** Controle por serial (`proc://` write/read), screendump via QMP
  (`screendump` + pnmtopng), powerdown ACPI limpo.
- **[V]** Transferência host→guest: `python3 -m http.server 8099 --bind
  0.0.0.0` servindo `/tmp` no host + `fetch` no guest (rota
  `/dinx-vm-scripts/<arquivo>`). Guest→host: `curl -X PUT` / `-T` contra um
  sink **com handler PUT** na 8097 (`scripts/bsd-vm/host-put-sink.py`),
  gravando em `/tmp/guest-uploads`. Nota de operação: `python3 -m http.server`
  **não** aceita PUT — um sink sem `do_PUT` devolve 501 e o probe silenciosamente não
  chega, o que foi a causa do travamento da sessão anterior no meio de uma
  sondagem de API. `nc -N` segue como alternativa.
- **[V]** Scripts de prova: `headless-proof.sh`, `proof2.sh` (keepalive IPC +
  grim cedo), `proof3.sh` (aninhado Weston — indisponível),
  `reinstall-proof.sh` (reempacote + reinstall ordenado + prova headless),
  `kwm-port-build.sh` (patch + `zig build` do kwm) e `kwm-runtime-proof.sh`
  (river headless + prova de `SIGTERM` via self-pipe). Driver do serial no
  host: `scripts/bsd-vm/serial-run.py SOCK "cmd" [segundos]`.
- **[V]** Marcadores de conclusão via HTTP de volta ao host (listener 8001).

### Não funciona / restrições
- **[D]** Read do serial fica defasado um comando e trunca linhas longas;
  usar marcadores (`echo MARK_x`) e scripts via fetch.
- **[D]** `pgrep -f` casa zumbis e o próprio watcher → watchers por pgrep são
  não confiáveis; preferir wrapper `sh script; fetch /done`.
- **[B]** SSH pubkey (ver §2).

---

## 8. Resumo executivo

| Área | Estado |
|---|---|
| Build da ISO + check + checksum | **Funciona** [V] |
| Install unattended + gate + shutdown limpo | **Funciona** [V] |
| Build nativo (Aqueous/Pearl/greetd/wlroots/compat/Weston) | **Funciona** [V] |
| Pacotes reais + repo local (incl. dinx-weston) | **Funciona** [V] |
| Firstboot instala stack + dinx no instalado | **Funciona** [V] |
| Weston headless + socket Wayland + desktop-shell | **Funciona** [V] |
| **Aqueous: socket Wayland + IPC (SIGSYS corrigido)** | **Funciona** [V] |
| **Aqueous + Xwayland (X server 11.0 + xterm anexado)** | **Funciona** [V] |
| **Captura da tela do compositor (grim/wlr-screencopy)** | **Funciona** [V] |
| **Pearl shell inicia (`event=ready mode=session`, app-index 5)** | **Funciona** [V] |
| **Screenshot verificado (xterm Xwayland + bordas Vulkan)** | **Funciona** [V] |
| kwm (WM do river) compila e roda no FreeBSD 15.1 | **Funciona** [V] |
| kwim compila sem patch (commit a802d2d) | **Funciona** [V] |
| river-shifttags porta e roda (cc, wayland-scanner) | **Funciona** [V] |
| Astal 0.1 (16 módulos) + glycin + translator compilam | **Funciona** [V] |
| **morghulis compila/linka (150 deps, 0 não resolvidas)** | **Funciona** [V] |
| **river+kwm+morghulis rodam juntos e DESENHAM (framebuffer)** | **Funciona** [V] |
| Empacotamento: `pkg install` real → 12/12, schema compilado | **Funciona** [V] |
| Barra de tags do morghulis com kwm (KwmTags via socket dinx-kwm-tags.sock: publisher `kwm-tags.patch` + consumer `morghulis-kwm-tags.patch`) | **Implementado; ambos os lados no repo; patch chain byte-idêntico ao build dourado /tmp/kwm-build** [I] |
| Barra de tags do morghulis (AstalRiver) com kwm | **Impossível** (conflito de protocolo upstream; substituído por KwmTags) [B] |
| Painel Network do morghulis | **Não funciona** (libnm do FreeBSD é stub) [B] |
| Xwayland no Weston (segfault no launch do filho) | **Não funciona** [B] |
| DRM em QEMU/VirtualBox (GPU virtual) | **Não existe no FreeBSD 15.1** [B] |
| greetd greeter em tela | **Não verificado** (sem VT/DRM em VM) [B] |
| Temas aplicados em tela | **Não verificável sem scanout** [B] |
| Gaming/Linuxulator exercitado | **Não testado** [I] |
| Live/first-run/persist | **Implementado; gate final re-verificado** [V] |
| Sessão padrão do ISO = river+kwm (dxinx-session-select) | **Fonte alterada; runtime pendente de VM** [I] |

1. **[V]** ISO 15.1 atual (`sha256=749a95310a1eab6b10412e28aed5c77179c0a4411efa14702075a5f1294b56a2`): gate unattended final executado em QEMU/KVM com 2 GiB, instalação completa, primeiro boot com `dinx-bsd: first-boot-ready` + `login:` e shutdown limpo.
2. **VirtualBox (sem DRM)**: dois caminhos, ambos sem driver DRM:
   a. `WLR_BACKENDS=x11` → Aqueous renderiza numa janela do Xorg com driver
      `scfb`/`vesa` (X11 não exige KMS) → desktop visível no console da VBox.
      Requer que o wlroots patcheado tenha o backend x11 habilitado.
   b. `WLR_BACKENDS=headless` + **wayvnc** (já nos ports, `net/wayvnc` 0.10.1)
      → sessão exposta por VNC, acessível do host; já preparado no wrapper
      `dinx-pearl-session` (fallback quando `/dev/dri/card0` não existe).
3. **greetd/VT**: validar o greeter em ttyv1 com o console vt(4) (não requer
   DRM) e a transição greeter → sessão.

## 9. Stack river: compositor river + kwm + kwim + shell morghulis

### Funciona
- **[V]** `river` existe no catálogo FreeBSD e instala: `river-0.4.8`, origin
  `x11-wm/river`, confirmado por `pkg which /usr/local/bin/river` e
  `pkg rquery '%n %o %v' river`.
- **[V]** `kwm` compila para FreeBSD 15.1 com os patches de
  `scripts/bsd-vm/patch-kwm-freebsd.py`: `build_rc=0` com
  `zig build -Doptimize=ReleaseSafe -Dbar=true -Dkwim=true` (zig 0.17.1,
  `--fetch` rc=0); artefato `kwm` ELF "for FreeBSD 15.1", `ldd` sem
  "not found", zero dependência de `libdinxcompat.so`.
- **[V]** Ciclo de runtime sob `river -c kwm` (backend headless): o WM entra
  no loop (`info(kwm): start running`), permanece vivo 6 s (`ps -o stat` =
  `Ss`) e sai pelo caminho limpo após `kill -TERM` (`stop running` +
  `deinit context`), provando a emulação de `signalfd` por self-pipe em
  execução, não só em compilação. Evidência:
  `/root/kwmbuild/kwm-runtime3.out`.
- **[V]** `NoFont=0` após instalar `terminus-font` + `fontconfig`
  (`fc-match monospace` → Terminus): as duas quedas anteriores do kwm eram a
  VM sem fontes, não o port.
- **[V]** `kwim` (input manager, repositório separado `kewuaa/kwim`) compila
  sem patch no commit `a802d2d` ("Update for Zig 0.17"): `build_rc=0`, `ldd`
  limpo, único linuxismo `memfd_create` já nativo no FreeBSD 13+. O kwm o spawna
  sozinho (`context.zig:1391`, quando construído em `-Dkwim=true`), então só
  precisa estar no PATH — que `dinx-kwim` provê.
- **[V]** `river-shifttags` (CLI que o shell chama para trocar tags) porta e
  roda: `cc_rc=0`, binário 20 KB, `ldd` limpo. O Makefile upstream não serve no
  FreeBSD (GNU pattern rules que o bmake rejeita, `-lrt` inexistente,
  `-lpixman-1` com zero usos no fonte); o port gera os protocolos com
  wayland-scanner e linka só wayland-client.
- **[V]** **morghulis** (shell GTK4/Libadwaita/Astal) compila e linka: ELF
  "for FreeBSD 15.1", `ldd` com 150 deps e 0 não resolvidas. Dois patches
  (network carve + memfd). A espinha Astal (16 módulos) + glycin + translator
  compilam do fonte; nada existe no catálogo FreeBSD.
- **[I]** **KwmTags** (substitui `RiverTags`/`AstalRiver`): widget GTK4 que lê
  o estado de tags do kwm sobre `$XDG_RUNTIME_DIR/dinx-kwm-tags.sock` e envia
  "F"/"X" de volta. **Ambos os lados no repo**: consumer
  `distro/bsd/ports/files/morghulis-kwm-tags.vala` + patch
  `morghulis-kwm-tags.patch` (aplicado por
  `scripts/bsd-vm/build-astal-morghulis.sh`); publisher
  `distro/bsd/ports/files/kwm-tags.patch` (aplicado pelo `Makefile.kwm`
  `post-patch`, -p1, depois de `kwm-freebsd.patch`). Patch chain verificada:
  `kwm-freebsd.patch` + `kwm-tags.patch` sobre o trunk pinado 8dafe7ec gera
  arquivos **byte-idênticos** ao build dourado `/tmp/kwm-build` (src/kwm.zig,
  src/kwm/context.zig, src/kwm/output.zig). Consumer compilado no host com
  valac 0.56.19 + gtk4 + gio-unix (rc=0). Ainda não executado em FreeBSD real
  (sem VM livre p/ sessão gráfica).
- **[V] — PROVA VISUAL**: river 0.5.2 (fonte) + kwm + morghulis + wayvnc, vivos
  juntos 8+ min sem core. Framebuffer capturado
  (`docs/proof/river-kwm-morghulis-freebsd.png`): barra de tags do kwm no topo
  (`1-9 []=`), NavBar do morghulis embaixo (âncora 14, 200 px) com launcher,
  volume, **relógio `00:59→01:05`** e power. Render **vivo**, não cache: dois
  grabs 6 min apart diferem em 122 px **todos** nas linhas 695-702 (o relógio).
  `WAYLAND_DEBUG` confirma `get_layer_surface "Morghulis.NavBar"` + commit +
  attach/frame-callback. `gtk4-layer-demo` (controle) também pinta.
- **[V] — empacotamento ponta-a-ponta**: `pkg install` real (não dry-run) do
  repo gerado → 12/12 pacotes, DB lista 12, `ldd` do binário instalado = 0 não
  resolvidas, catálogo 19 pacotes. Trigger do glib compila o schema
  (`gschemas.compiled` 47775 B); `gsettings get com.arkye.morghulis night-temp`
  → 4000; binário instalado roda sem o abort "schema not installed".
- **[I]** Ports: `Makefile.kwm` (+ `kwm-freebsd.patch`, `kwm-tags.patch`),
  `Makefile.river-shifttags`, `Makefile.morghulis`; build Astal/glycin/morghulis via
  `scripts/bsd-vm/build-astal-morghulis.sh` → `dinx-*` `.pkg`; wiring em
  `build-native.sh`, manifesto, `install-dinx-bsd.sh`, `check_dinx_bsd.sh`,
  sessão `dinx-river-session` + `dinx-session-set river`.

### Não funciona / restrições
- **[B]** `signalfd(2)` não existe no FreeBSD (sem `<sys/signalfd.h>`): só
  emulação por self-pipe. Consequência obrigatória: a máscara que o kwm monta
  com `sigprocmask(BLOCK)` precisa ser **limpa**, senão o handler nunca roda.
- **[B]** `system.TFD` é `void` no FreeBSD (o bitfield de flags do timerfd só
  existe para Linux) e `E.LIBBAD` não é membro do enum do FreeBSD — ambos no
  fonte upstream do kwm, corrigidos pelo patch.
- **[D]** Zig 0.17 removeu `std.posix.pipe`/`write`/`close`/`fcntl`: o shim
  precisa de `extern "c"`, e `O` no FreeBSD aceita `@bitOffsetOf` mas não
  expõe `O.NONBLOCK` como valor plano.
- **[I] — barra de tags via socket (substitui RiverTags):** o `AstalRiver` do
  morghulis liga `river-status-unstable-v1` (removido pelo river em `a309d18e`),
  enquanto o kwm exige `river-window-management-v1` (só river ≥0.4). Nenhuma
  release do river tem os dois, então `RiverTags`/`--define=river` está
  desativado. Em vez disso, o `KwmTags` (files/morghulis-kwm-tags.vala, aplicado
  por `scripts/bsd-vm/build-astal-morghulis.sh`) lê o estado de tags do kwm
  sobre `$XDG_RUNTIME_DIR/dinx-kwm-tags.sock` ("T <focused_hex>
  <occupied_hex>" → 9 botões com destaque do foco) e envia "F"/"X" de volta
  para focar/trocar tags. Implementado e compilado no host (valac 0.56 +
  gtk4 + gio-unix); ainda não executado em FreeBSD real (sem VM livre para a
  sessão gráfica).
- **[B]** river 0.4.8 (catálogo) SIGSEGV em qualquer cliente de screencopy
  (`Server.zig:626`, `else unreachable`; fix no 0.5.x → `error.NotOutputOrToplevel`).
  Não impede a sessão (sem captura fica estável), só a prova visual via
  wayvnc/grim. Daí a prova usar river 0.5.2 do fonte (precisa Zig 0.17, não o
  0.16 do catálogo) e o `dinx-river-session` deixar o VNC opt-in
  (`DINX_RIVER_VNC=1`) até o port subir para 0.5.x.

- **[B]** `libnm` do FreeBSD (`networkmanager-shim`) é stub sem símbolos
  (`nm_client_new` undefined; 2 símbolos totais, sem `NM-1.0.typelib`/`libnm.vapi`)
  e NetworkManager é Linux-only → o painel **Network** do morghulis é removido
  (`network-carve.patch`). Bluetooth/power-profiles compilam mas são inertes sem
  `org.bluez`/`power-profiles-daemon`; battery funciona se upower presente.
- **[D]** scss do morghulis exige **dart-sass** (`@use` modules); `sassc`/libsass
  não interpreta e `rubygem-dartsass` recusa amd64-freebsd. O build usa
  `npm install sass` local + wrapper `sass`→node (dart-sass puro JS).
- **[I]** Não verificado: janelas de aplicação reais sendo gerenciadas pelo kwm
  (o framebuffer prova o shell desenhado, não um app tiling), e os daemons
  ausentes na VM (bluetooth/battery/power-profiles/pipewire logam `Could not
  connect` e degradam sem crash).

---

## 10. Como reproduzir

```sh
# ISO (host Linux, precisa xorriso/bsdtar + cache do disc1/base/kernel)
bash scripts/build-bsd-iso.sh

# Gate unattended (instala em disco descartável e exige first-boot + login)
python3 scripts/build-bsd-iso-unattended.py --disk /tmp/gate.qcow2 \
  --disk-size 32G --keep-disk --log /tmp/gate.log --timeout 1200 \
  dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso

# Dentro da VM FreeBSD (root): deps + toolchain + fontes + build + pkgs
sh setup-build-vm.sh          # scripts/bsd-vm/
sh build-native.sh            # idem; patches via patch-freebsd.py
sh reinstall-proof.sh         # reempacote + reinstall ordenado + prova headless
```

Stack river + shell (também dentro da VM; produz 19 `.pkg` em `$W/repo`):

```sh
# deps do catálogo que a lista base não cobre (ver §9)
pkg install -y vala meson ninja blueprint-compiler gobject-introspection \
  gsound libadwaita libgtop cmark muparser libportal json-glib libsoup3 \
  glib-networking rust node terminus-font fontconfig fcft dbus river
pkg install -y terminus-font fontconfig && fc-cache -f   # sem fonte o kwm morre (NoFont)

# espinha Astal + glycin + translator + morghulis -> pacotes dinx-*
SHIM_SRC=distro/bsd/ports/files/astal-valadoc-shim \
  PATCH_DIR=distro/bsd/ports/files \
  sh scripts/bsd-vm/build-astal-morghulis.sh /root/astal
#   requer node/npm: o scss usa @use (dart-sass); sassc/libsass não serve

# instalar do repo gerado (prova real, não dry-run) e conferir
pkg repo /root/astal/repo
pkg install -y -r dinx dinx-morghulis   # puxa 12 pacotes; trigger compila o schema
gsettings get com.arkye.morghulis night-temp   # -> 4000
```

river 0.5.2 (só necessário para captura/screencopy; o 0.4.8 do catálogo crasha
em wayvnc/grim): build do fonte com o Zig 0.17.1 pinado do kwm, pois o
`zig:016` do catálogo falha em `OptimizeMode.debug`.

```sh
# sessão completa + prova de framebuffer (host captura via VNC forward)
WLR_BACKENDS=headless dbus-run-session river -c init   # init: kwm + morghulis [+ wayvnc]
python3 scripts/bsd-vm/vnc-framebuffer-grab.py 127.0.0.1 5907 /tmp/fb.ppm
```

Transferências (tudo que a fila usa está versionado em `scripts/bsd-vm/`):

```sh
# host: servir scripts/bsd-vm/ na 8099 e abrir o sink PUT na 8097
python3 -m http.server 8099 --bind 0.0.0.0 --directory scripts/bsd-vm &
python3 scripts/bsd-vm/host-put-sink.py &
python3 scripts/bsd-vm/serial-run.py /tmp/dinx-s9.sock 'uname -K' 20
```

`http.server` **não** aceita PUT: sem o `do_PUT` do sink o `curl` devolve 501 e
o resultado do probe nunca chega ao host — foi a causa do travamento no meio de
uma sondagem de API. O console serial do QEMU trunca linhas acima de ~256 chars,
então comando longo vai sempre por script (`fetch -q -o /tmp/x.sh
http://10.0.2.2:8099/x.sh && sh /tmp/x.sh`; volta `curl -s -X PUT
--data-binary @/tmp/x.out http://10.0.2.2:8097/x.out`).

Port do kwm (§26), na VM de build:

```sh
fetch -q -o /tmp/kb.sh http://10.0.2.2:8099/kwm-port-build.sh
sh /tmp/kb.sh http://10.0.2.2:8099/patch-kwm-freebsd.py
#   patch_rc=0 (7 blocos), build_rc=0, zig-out/bin/kwm
pkg install -y terminus-font fontconfig && fc-cache -f
fetch -q -o /tmp/kr.sh http://10.0.2.2:8099/kwm-runtime-proof.sh
sh /tmp/kr.sh   #   NoFont=0, KWM_ALIVE=yes, SIGNAL_HANDLED=yes
```

Liveness do kwm só com `ps -o stat` (`Z` = morto); `pgrep -x`/`pgrep -f`
respondem zumbis.

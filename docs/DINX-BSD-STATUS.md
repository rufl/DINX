# DINX-BSD — Status completo: o que funciona e o que não funciona

Data: 2026-11-14. Branch `feature/dinx-bsd`. Alvo: FreeBSD 15.1-RELEASE amd64.
Este documento consolida o estado real do effort BSD, separado por nível de
evidência. Nada aqui é claim de roadmap: cada item cita a evidência observada
ou a limitação encontrada. O journal detalhado de causas raiz está em
`docs/DINX-BSD-PROCESS.md` (§§1–21).

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

## 4. Sessão gráfica (Weston + Xwayland + Pearl) — estado atual

Decisão de produto: o compositor da sessão passou a ser **Weston** (build
nativo, `scripts/bsd-vm/build-weston.sh`), com **Xwayland habilitado**; o
Aqueous permanece empacotado como alternativa, mas o socket Wayland dele não
escuta no FreeBSD (blocker original, journal §20). O wrapper
`dinx-pearl-session` sobe Weston (headless sem `/dev/dri/card0`) + Pearl.

### Funciona
- **[V]** Weston 14.0.2 compila e instala nativamente no FreeBSD 15.1
  (`meson`/`ninja` exit=0) com Xwayland, shell desktop/kiosk, backend headless
  e wayland; renderer pixman (`renderer-gl=false`). Patches de porting
  aplicados pelo script: `ETIME`→`ETIMEDOUT`, `program_invocation_short_name`
  →`getprogname()`, `pty.h`→`libutil.h` (+`-lutil`), `CLOCK_MONOTONIC_RAW`→
  `CLOCK_MONOTONIC`, shims `linux/ioctl.h`/`linux/types.h`, `environ` como
  **weak extern** (definir no objeto sobrescreve o crt1 e segfaulta),
  `-lepoll-shim` em todos os alvos; opções meson válidas do 14.0.2
  (sem `colord`/`elogind`/`werror`/`shell-lua`), `backend-drm=false` +
  `backend-default=headless`, `tools=[]` e `simple-clients=[]`.
- **[V]** **Socket Wayland do Weston escuta**: `connect()` UNIX em
  `$XDG_RUNTIME_DIR/wl-x` retorna `CONNECT_OK`; `weston`, `weston-keyboard` e
  `weston-desktop-shell` ficam vivos (pgrep). Diferente do Aqueous, o caminho
  socket/event-loop do Weston funciona no FreeBSD.
- **[V]** Pacote `dinx-weston-14.0.2.pkg` gerado com `shlibs_provided`
  (libweston-14) e sem `shlibs_required` (libpulsecommon é lib privada do
  pulseaudio); firstboot instala `dinx-weston` + `xwayland` + `pulseaudio`.
- **[V]** No sistema instalado pela ISO: pearl/aqueous/greetd/config.toml
  presentes; `seatd_enable=YES`, `dinx_greetd_enable=YES`.
- **[V]** Aqueous headless renderiza frames (llvmpipe, HEADLESS-1 1280×720) e
  o IPC dele responde via `aqueousctl` com `LD_PRELOAD` do shim.

### Não funciona (blockers abertos)
- **[B]** **Weston segfaulta (signal 11) ao lançar o Xwayland** com
  `xwayland=true`: o log chega a "launching '/usr/bin/Xwayland'" / "Couldn't
  unset CLOEXEC on child FDs" e o processo morre; sob gdb o crash não
  reproduz (race no caminho de FDs do filho Xwayland). Com `xwayland=false` o
  Weston sobrevive. **Xwayland ainda não funcional no FreeBSD.**
- **[B]** **`xwayland-path` do weston.ini não é respeitado** no build atual
  (log continua `/usr/bin/Xwayland`, path Linux; no FreeBSD é
  `/usr/local/bin/Xwayland`) — investigar parsing da seção `[core]`.
- **[B]** **Pearl instalado ainda rejeita a sessão**: o binário em
  `/usr/local/bin/pearl` continua emitindo `AQUEOUS_SOCKET must identify this
  runtime's aqueous` mesmo com os patches #22 (aceita Weston) e #23 (pula
  checks de IPC do Aqueous) presentes no fonte — o binário instalado está
  stale; falta rebuild+reinstall verificado do Pearl após o #23.
- **[B]** **`weston-screenshooter` aborta** com `Assertion failed: (width > 0)`
  (output headless sem mode corrente no protocolo de capture); sem screenshot
  do desktop por esse caminho. `xwd` via Xwayland depende do blocker acima.
- **[B]** **Sem DRM no QEMU:** `drm-612-kmod` só fornece amdgpu/i915/radeon;
  nenhum GPU emulado pelo QEMU tem driver DRM no FreeBSD 15.1 → backend DRM
  impossível em VM (headless é o caminho de prova). Hardware real não testado.
- **[B]** **greetd greeter gráfico:** daemon instala/habilita, mas a sessão
  não aparece pelos blockers acima.

### Restrições operacionais (contornáveis, documentadas)
- **[D]** Helpers Zig (aqueousctl) não exportam `environ`; usar `LD_PRELOAD`
  do shim apenas neles. Nunca no compositor.
- **[D]** `su -m dinx` preserva `HOME=/root`; setar `HOME=/home/dinx`.
- **[D]** `XDG_RUNTIME_DIR` deve ser 0700 sob o home (não `/tmp`).
- **[D]** `dinx` no grupo `video` (firstboot já faz `pw groupmod video -m dinx`).
- **[D]** Provas via serial: linhas >~256 chars truncam; usar scripts via
  fetch + output redirecionado; screenshooter/perl alarm para não travar.
- **[D]** Aqueous tem idle-exit (~5 s sem cliente IPC).

---

## 5. Firstboot / stack de runtime no sistema instalado

### Funciona
- **[V]** `scripts/install-dinx-bsd.sh` (via `rc.d/dinx_firstboot`): instala
  seatd, pipewire, wireplumber, wayland, mesa-dri, libxkbcommon,
  xkeyboard-config, jq, gtk4, gtk4-layer-shell, libsecret, libarchive, basu;
  habilita o repo `dinx` local e instala dinx-compat, dinx-wlroots,
  dinx-greetd, dinx-aqueous, dinx-pearl; instala drm-kmod, vulkan-loader,
  vulkan-tools; cria `dinx`/`greeter`; escreve PAM do greetd e config.toml;
  habilita seatd + dinx_greetd. Evidência: `/var/log/dinx-firstboot.log` e
  `pkg info | grep dinx` no disco do gate (5 pacotes presentes).
- **[V]** Contas, PAM (`pam_unix` auth + `pam_permit` account/session) e
  config do greetd (`initial_session` → `dinx-session-select`, user dinx).
- **[I]** Stack gaming/Linuxulator (wine-proton, libc6-shim, linux-steam-utils,
  rl9, sysctls LSU, kld_list, conta games): implementado em milestone
  anterior; firstboot instala os pacotes, mas **nenhum jogo/sessão Linux foi
  exercitado** nesta rodada.

### Não funciona / notas
- **[D]** `noctalia` (shell alternativo) não existe no repo → firstboot registra
  NOTE e segue (comportamento esperado, não falha).
- **[B]** Sessão Pearl de ponta a ponta: bloqueada pelo §4.
- **[D]** `dinx` sem grupo `video` na criação do firstboot (ver §4).

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
- **[V]** Transferência host→guest: `python3 -m http.server 8000` no host +
  `fetch` no guest. Guest→host: `tar -cf - … | nc -N 10.0.2.2 9000` + listener
  python com idle-timeout (o probe de readiness consome o primeiro accept;
  `nc` sem `-N` deadloca).
- **[V]** Scripts de prova: `headless-proof.sh`, `proof2.sh` (keepalive IPC +
  grim cedo), `proof3.sh` (aninhado Weston — indisponível), `reinstall-proof.sh`
  (reempacote + reinstall ordenado + prova).
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
| Xwayland no FreeBSD (launch do filho) | **Não funciona (segfault)** [B] |
| Pearl sob Weston (binário instalado stale) | **Não funciona** [B] |
| Screenshot do desktop (screenshooter/xwd) | **Não funciona** [B] |
| DRM em QEMU (qualquer GPU emulado) | **Não existe no FreeBSD** [B] |
| greetd greeter em tela | **Não funciona** (consequência) [B] |
| Temas aplicados em tela | **Não verificável** [B] |
| Gaming/Linuxulator exercitado | **Não testado** [I] |
| Live/first-run/persist | **Implementado, não re-verificado** [I] |

## 9. Próximo passo técnico (para fechar o objetivo)

1. **Xwayland no Weston/FreeBSD**: depurar o segfault no launch do filho
   (`Couldn't unset CLOEXEC on child FDs`, race; não reproduz sob gdb) e o
   parsing de `xwayland-path` na seção `[core]` do weston.ini.
2. **Pearl**: rebuild + reinstall verificado após os patches #22/#23 (o
   binário instalado ainda é anterior ao #23) e validar a sessão sob Weston.
3. **Captura**: resolver o `width > 0` do weston-screenshooter (mode corrente
   do output headless) ou capturar via Xwayland assim que o item 1 fechar.
4. Só então: prova visual do desktop + gate gráfico da ISO.

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

Transferências: host `python3 -m http.server 8000 --directory scripts/bsd-vm`;
guest `fetch http://10.0.2.2:8000/<arquivo>`; volta `tar -cf - -C /root/build
repo | nc -N 10.0.2.2 9000` com listener no host.

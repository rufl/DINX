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

## 4. Sessão gráfica (compositor + shell) — o blocker central

### Funciona (parcial)
- **[V]** Aqueous sobe com `WLR_BACKENDS=headless`: backend headless criado,
  Vulkan llvmpipe (LLVM 19.1.7), pipelines de efeitos (rounded, backdrop-blur)
  inicializados, output `HEADLESS-1` 1280×720 com frames committed
  (`/tmp/aqueous.log`).
- **[V]** IPC do Aqueous funciona: `aqueousctl` conecta e responde
  (usage/windows), **desde que** com `LD_PRELOAD=/usr/local/lib/libdinxcompat.so`
  (ver abaixo).
- **[V]** No sistema instalado pela ISO: `/usr/local/bin/pearl`,
  `/usr/local/bin/aqueous`, `/usr/local/sbin/greetd`,
  `/usr/local/etc/greetd/config.toml` presentes; `seatd_enable=YES` e
  `dinx_greetd_enable=YES` setados pelo firstboot.

### Não funciona
- **[B]** **Socket Wayland do Aqueous não escuta no FreeBSD.** O arquivo
  `wayland-1` é criado em `$XDG_RUNTIME_DIR`, mas `connect()` retorna
  `ECONNREFUSED` em todos os segundos de vida do compositor (sondagem 1–6 s) e
  `sockstat -l` não mostra listener unix. Consequência: nenhum cliente anexa —
  Pearl (`Pearl requires an Aqueous session` quando fora do init; dentro do
  init não chega a conectar), grim (`failed to create display`), e portanto
  **não há desktop interativo nem screenshot do desktop**. Causa raiz não
  fechada; hipótese: caminho socket/event-loop (kqueue) do wlroots patcheado.
  Evidência: journal §20; sondagens desta rodada.
- **[B]** **Sem DRM no QEMU:** `drm-612-kmod` só fornece amdgpu/i915/radeon;
  nenhum GPU emulado pelo QEMU (virtio-gpu, vmware, bochs) tem driver DRM no
  FreeBSD 15.1 → `/dev/dri` inexistente → backend DRM impossível em VM.
  Em hardware real o DRM existe, mas **não foi testado**.
- **[B]** **Prova aninhada com Weston indisponível:** `pkg install weston` →
  "No packages available … matching 'weston'" no repo pkg do FreeBSD 15.1.
- **[B]** **greetd greeter gráfico:** o daemon instala e habilita, mas a
  sessão/greeter não aparece pelos dois blockers acima (sem DRM na VM; sem
  socket Wayland utilizável).

### Restrições operacionais descobertas (contornáveis, documentadas)
- **[D]** `aqueousctl` (e helpers Zig) não exportam `environ`, que a libc do
  FreeBSD exige do executável → `ld-elf.so.1: /lib/libc.so.7: Undefined symbol
  "environ"`. Contorno: `LD_PRELOAD` do shim **apenas nos helpers**.
- **[D]** `LD_PRELOAD` do shim **no compositor o mata** (não usar no aqueous).
- **[D]** Aqueous tem idle-exit (~5 s sem cliente IPC): provas precisam de
  keepalive (`aqueousctl` em loop) ou captura muito cedo.
- **[D]** `su -m dinx` preserva `HOME=/root` → Aqueous tenta estado em
  `/root/.local/state` → `AccessDenied`. Setar `HOME=/home/dinx`.
- **[D]** `XDG_RUNTIME_DIR` sob `/tmp` → `InsecureRuntimeDirectory` (antes do
  fix de statx); usar diretório 0700 sob o home do usuário.
- **[D]** Pearl valida `XDG_CURRENT_DESKTOP` contendo `Aqueous`
  (`src/core/startup.zig`): só roda dentro da sessão/init do Aqueous (ou
  `--demo` para galeria standalone).
- **[D]** `dinx` precisa do grupo `video` para o socket do seatd
  (`pw groupmod video -m dinx`); o firstboot cria o usuário sem grupo.

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
| Build nativo (Aqueous/Pearl/greetd/wlroots/compat) | **Funciona** [V] |
| Pacotes reais + repo local | **Funciona** [V] |
| Firstboot instala stack + dinx no instalado | **Funciona** [V] |
| Compositor headless renderiza frames | **Funciona** [V] |
| IPC do Aqueous (aqueousctl) | **Funciona com LD_PRELOAD** [D] |
| Clientes Wayland anexam ao Aqueous | **Não funciona** [B] |
| Desktop Pearl interativo / screenshot | **Não funciona** [B] |
| DRM em QEMU (qualquer GPU emulado) | **Não existe no FreeBSD** [B] |
| greetd greeter em tela | **Não funciona** (consequência) [B] |
| Temas aplicados em tela | **Não verificável** [B] |
| Gaming/Linuxulator exercitado | **Não testado** [I] |
| Live/first-run/persist | **Implementado, não re-verificado** [I] |

## 9. Próximo passo técnico (para fechar o objetivo)

Instrumentar o caminho do socket Wayland no wlroots patcheado
(`wl_socket_init` / `wl_display_add_socket_auto` / `wl_event_loop_add_fd`)
para descobrir por que o fd não chega a listener no FreeBSD (kqueue). Sem
isso, nenhum cliente — incluindo o Pearl em hardware real — consegue anexar.
Alternativas de prova enquanto isso: compositor de referência aninhado
(indisponível no repo 15.1) ou backend DRM em hardware real.

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

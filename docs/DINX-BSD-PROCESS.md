# DINX-BSD — Journal do processo (branch BSD)

Este documento registra **todo o processo** de construção da DINX-BSD nesta
branch. Ela é **FreeBSD nativo** e não compartilha estrutura com a `main`
(Artix/Arch Linux + kernel Linux): da main vêm apenas filosofia, nomes de
produto e parte do manifesto de apps. Nada aqui depende de Linuxulator como
arquitetura de desktop; o Linuxulator entra apenas como camada de
compatibilidade para Steam/binários Linux (stack gaming).

## 1. Objetivo

- ISO amd64 bootável (BIOS/MBR + UEFI/GPT) baseada em FreeBSD RELEASE pinada.
- **Live persistente** (modelo NomadBSD/helloSystem) com wizard de primeiro
  boot no estilo macOS (idioma primeiro) e **installer permanente**
  (`dinx-installer`) — "best of both worlds".
- Desktop: compositor **Aqueous** (wlroots) + shell **Pearl**; **Noctalia**
  como shell alternativo.
- Gaming/compatibilidade Linux no padrão HyprBSD (LSU/Steam, wine-proton,
  libc6-shim, sysctls LSU, conta dedicada).

## 2. Pipeline de build e qualificação

- `scripts/cache-verified-download.sh`: baixa a ISO fonte com SHA-256 pinado
  e revalida o cache antes de reutilizar.
  - 14.5: `a7f360c8dbd4727a8d3213ac85f6eb9b51ee4ed2577a2c31aaebbcae3d921d56`
  - 15.1: `fa27646f05a1440fd26ffbb85e06a50bc86e128242a4e9cb7bb3ea76e1aa5fd9`
- `scripts/build-bsd-iso.sh`: overlay determinístico (`SOURCE_DATE_EPOCH`,
  bsdtar pax uid/gid 0), entrada extra no `MANIFEST` do freebsd-dist,
  remaster `xorriso` preservando El Torito BIOS+UEFI e system area híbrida,
  mapeia `/etc/installerconfig` e `/etc/rc.local` (live), emite ISO + sha256 +
  `build-metadata.txt`. Versão padrão atual: **15.1** (`DINX_BSD_FREEBSD_VERSION`).
- `scripts/check-bsd-iso.sh`: contratos estáticos — boot BIOS+UEFI, split do
  `installerconfig` (preâmbulo e script validados com `sh -n`), checksum e
  contagem do overlay vs MANIFEST, paths obrigatórios do overlay, e **gate de
  formato pkg**: qualquer `.pkg` embarcado precisa de `+COMPACT_MANIFEST` na
  raiz (rejeita tarballs de staging).
- `scripts/build-bsd.sh` = `build-bsd-iso.sh --validate`.
- `scripts/build-bsd-iso-unattended.py`: gate QEMU em **duas fases** —
  (1) boot live: marker `dinx-bsd: first-boot-ready` + banner + `login:` no
  serial; login root; espera o prompt `:~ #`; (2) envia `dinx-installer`,
  acompanha a instalação permanente e exige marker + `login:` do sistema
  instalado. Responde prompts de console contando ocorrências (não apenas a
  primeira). Cadeias de shell usam `pipefail` para não mascarar falha de gate
  e enviar ISO sem qualificação.

## 3. Contrato do `installerconfig` (bsdinstall)

O `bsdinstall script` divide o arquivo no primeiro `^#!`: antes = preâmbulo
(`PARTITIONS`, `DISTRIBUTIONS`, `nonInteractive`, …) sourced; depois = script
pós-instalação executado **chrooted** no alvo. Regras aprendidas na prática:

- Shebang no meio do arquivo, nunca na linha 1 (senão o preâmbulo esvazia e
  `PARTITIONS`/`DISTRIBUTIONS` somem → instalação quebra).
- O pós-instalação é POSIX sh puro: **sem bash, sem pkg, sem rede garantida**
  no chroot. Configuração de desktop/pacotes foi movida para o first boot do
  sistema instalado (`rc.d/dinx_firstboot`).
- `PARTITIONS=DEFAULT` escolhe MBR em boot BIOS e GPT em UEFI (não há GRUB no
  FreeBSD; o loader é o `loader(8)`/pmbr).

## 4. Modo live: root read-only e camadas graváveis

Descoberta central: o root do disc1 (14.5 **e** 15.1) é **cd9660 read-only**;
não existe mfsroot gravável. helloSystem resolve com uzip+ramdisk+reroot;
NomadBSD com imagem UFS no USB. Aqui: `rc.local.live` cria camadas graváveis
com `mdconfig -t malloc` + `newfs` sobre `/etc` (16m), `/var` (64m) e
`/usr/local` (128m): copia o conteúdo original para um mount tmp, desmonta
o tmp e monta o md por cima do diretório (UFS não aceita o mesmo device
montado duas vezes rw). `/home` não recebe camada (não há mountpoint no
root ro): homes do live ficam em `/tmp/home` (tmpfs) e a persistência faz
nullfs sobre esse alvo no live (sobre `/home` no instalado). Em seguida
extrai o overlay DINX no root live, cria a conta `dinx`, instala o
`greetd-live.toml` (autologin) e aplica hostname/marker/serviços **no boot
atual** (`sysrc` dentro do rc.local só valeria no próximo boot; `service …
onestart` resolve). O stdout do rc.local vai para o console de vídeo —
`exec > /dev/ttyu0 2>&1` espelha no serial para debug e para o marker.

- **Wizard** `dinx-first-run` (bsddialog da base, offline): idioma → teclado →
  fuso → hostname → conta+senha → sessão (Pearl/Noctalia) → oferta de
  persistência. Grava `locale.conf`/`keyboard.conf` (exportados pelos
  wrappers de sessão), `/etc/localtime`, hostname, sessão padrão; inicia o
  greetd ao final. Roda detached no console de vídeo (`rc.d/dinx_first_run`)
  no live e no primeiro boot do instalado. TUI por ora; wizard gráfico entra
  quando Pearl/Qt existirem.
- **Persistência** `dinx-live-persist` (modelo NomadBSD): partição UFS
  `DINX-DATA` no espaço livre do USB de boot; `rc.d/dinx_live_persist`
  remonta a cada boot com nullfs sobre o home (`/tmp/home` no live, `/home`
  no instalado), `/usr/local/etc/dinx` e `/var/db/dinx-bsd`.
- **Installer** `dinx-installer`: `bsdinstall script /etc/installerconfig` +
  reboot. No 15.1 o disc1 traz base/kernel apenas como pacotes **pkgbase**
  (`/usr/freebsd-packages/offline`); o caminho legado `DISTRIBUTIONS`
  disparava o prompt interativo de Mirror Selection. O build agora **embute
  `base.txz` e `kernel.txz` na ISO** (SHA-256 pinado do MANIFEST fonte), então
  a instalação permanente é offline e sem prompts. Migração para pkgbase
  nativo = trabalho futuro.
- Firstboot (pacotes) roda **só no sistema instalado**; as camadas md do live
  são pequenas de propósito. Live offline com apps criativos pré-instalados
  exige remaster com pkg root no lado FreeBSD — futuro, não fingido.

## 5. First boot do sistema instalado (`install-dinx-bsd.sh`)

POSIX sh, detached via `daemon(8)` para nunca bloquear o boot (marker/login).
- DNS: o bsdinstall copia o `resolv.conf` **vazio** do live para o alvo → todo
  `pkg` falhava com resolver error. O installer remove o vazio; o firstboot
  renova via dhcpcd (se presente) ou recupera nameservers do lease do
  dhclient (15.1 ainda traz dhclient), com retry ~120 s e **done flag só com
  sucesso** (retry no próximo boot caso contrário).
- Repo local UCL `/usr/local/etc/pkg/repos/dinx.conf` com `enabled: no` (repo
  vazio habilitado quebrava **todas** as operações pkg); habilitado apenas
  quando existe `packagesite.txz` real.
- Stack gráfico real: seatd, pipewire, wireplumber, wayland, **wlroots020**,
  mesa-dri (RADV/ANV; não existem pacotes mesa-vulkan-* separados),
  libxkbcommon, xkeyboard-config. **dxvk e gamemode não existem nos ports
  FreeBSD** — não instalados, documentado.
- Gaming HyprBSD: drm-kmod + kmod por GPU detectada (`pciconf class=0x03` →
  amdgpu/i915kms/nvidia-modeset), vulkan-loader/tools, wine-proton,
  libc6-shim, linux-steam-utils + deps rl9, ca_root_nss, ruby, mangohud
  (`benchmarks/mangohud`); sysctls LSU gravados em `/etc/sysctl.conf`
  (`compat.linux.use_real_ifnames`, `security.bsd.unprivileged_chroot`,
  `vfs.usermount`, limites shm) para valerem independente de como o suporte
  Linux carrega (bug HyprBSD de restart NVIDIA); `linux_enable=YES`; conta
  não-wheel `games`; `pkg32.sh` i386 só no 14, `PROTON_USE_WOW64=1` no 15+
  (patch do bug FreeBSD 288475 documentado como requisito).
- Contas `dinx`/`greeter`; `seatd` e `dinx_greetd` iniciados ao final.

## 6. Sessões e supervisão (mapping KaOS → FreeBSD)

KaOS 2026.09 = dinit > turnstile > seatd + Niri + Noctalia. turnstile é
Linux-only (cgroups/pidfd) e não existe nos ports; papéis cobertos sem fake:
seatd (seat/DRM/input), greetd (utmp/greeter), wrappers de sessão com
`XDG_RUNTIME_DIR` per-user e PipeWire/WirePlumber **session-scoped** (trap de
cleanup mata os filhos ao sair). Sem provedor logind no FreeBSD → features
dependentes degradam; nada emula logind.

- Sessão = compositor + shell: `dinx-pearl-session` / `dinx-noctalia-session`
  (áudio → Aqueous → espera socket Wayland → shell). O wrapper antigo só
  execs o Aqueous e **nunca subia o Pearl** — corrigido.
- `dinx-session-select` (greetd) lê `~/.config/dinx/session` →
  `/var/db/dinx-bsd/session` (default pearl); `dinx-session-set`; desktop
  entries em `wayland-sessions/`.
- **greetd não existe nos ports FreeBSD** (verificado via pkg search): o
  desenho prevê build from source (cargo) empacotado como `dinx-greetd` no
  repo local; até lá o `dinx_greetd` falha visivelmente, sem fallback fake.
- Units dinit embarcados como referência (dinit não é PID 1 aqui); deps
  inválidas (`graphical`, `devfs`) removidas; path do greetd corrigido.

## 7. Auditoria: falsos claims e bugs encontrados/corrigidos

1. `.pkg` "reais" eram tarballs de staging com manifesto em `var/db/pkg/` —
   **removidos**; `build-bsd-ports-local.sh` só emite pkg via `pkg create` em
   FreeBSD com binários de build bem-sucedido; caso contrário staging+log e
   exit não-zero. Gate de formato no check (teste negativo comprovou).
2. `pkg add-repo` não existe; repo YAML com path do host Linux → UCL com
   paths do alvo, `enabled: no`.
3. `installerconfig` com shebang na linha 1 (preâmbulo vazio) → contrato
   two-part restaurado + validação `sh -n` das duas metades no check.
4. Pós-instalação chamava script bash com pkg dentro do chroot → movido para
   firstboot POSIX detached.
5. `greetd.toml` com schema inválido (`command` em `[terminal]`, usuários
   inexistentes) → schema correto + contas provisionadas.
6. Makefiles: `MASTER_SITES= files:` inválido, `USES=zig` inexistente,
   origins erradas (`x11-toolkits/wlroots`, `x11/greetd`), cross-target
   `-Dtarget` em build nativo → corrigidos (distfile local em DISTDIR,
   `x11/wlroots020`, sem cross-target).
7. `newfs -q` (flag do mke2fs Linux) abortava `make_writable` → camadas md
   nunca montavam, overlay não extraía, `dinx-installer: not found` →
   `newfs` sem `-q`.
8. Hostname live `Amnesiac` e marker invisível no serial (stdout do rc.local
   = vídeo; redirect do onestart) → hostname aplicado no boot atual, marker
   escrito em `/dev/ttyu0`, `exec > /dev/ttyu0` no rc.local.
9. Validator enviava `dinx-installer` antes do shell existir → espera o
   prompt `:~ #`; prompts de console re-respondidos por contagem.
10. Cadeias `| tail` mascaravam falha de gate e enviavam ISO sem qualificação
    → `pipefail`; entregas sem gate verde foram marcadas superseded.
11. Claims de docs corrigidos: "root gravável do disc1" (é ro), "dhcpcd
    substitui dhclient no 15" (15.1 ainda traz dhclient), jogos removidos
    (xonotic/supertuxkart) por decisão de produto.
12. `make_writable` montava o mesmo device md duas vezes rw (tmp + destino);
    UFS recusa o segundo mount rw ("Device busy") → `umount` do tmp antes do
    mount final.

## 8. Evidência de verificação

- Gates 14.5 (install → reboot → marker + login): PASS, várias rodadas;
  firstboot verificado em guest real: stack gráfico instalado (158 pkgs),
  seatd running, contas/repo criados.
- **Gate 15.1 duas fases: PASS** (live com overlay/wizard → `dinx-installer`
  → boot do instalado com marker + login). ISO
  `DINX-BSD-15.1-RELEASE-amd64.iso` sha256
  `49dd35a2726c2d6056799c47e28f2debc6606e7689bfcbcbc551615164a13d7f`,
  entregue via taildrop em DDJARIN como `…-fix8.iso`. Log:
  `dist/bsd-iso/dinx-bsd-151-test.log`.
- Smoke tests host: wizard (happy path grava locale/teclado/sessão/flag;
  cancel não marca done); sessões (pearl/noctalia exit 0, zero processos
  órfãos; compositor ausente → erro explícito); gate de pkg rejeita fake.
- Linter de Makefiles: 55/55.
- Diagnóstico QEMU serial interativo usado para achar root ro / newfs -q /
  overlay ausente no live.
- Gate 15.1 duas fases: ver status final no CHANGELOG e no log
  `dist/bsd-iso/dinx-bsd-151-test.log` (preenchido ao fechar).

## 9. Limites declarados (sem fake)

- Binários nativos Aqueous/Pearl/greetd ainda não construídos (Zig 0.16 +
  wlroots020/gtk4 exigem build em VM FreeBSD; sources Linux-only em partes).
  Até lá as sessões falham visivelmente.
- Wizard é TUI (bsddialog) até Pearl/Qt existirem.
- Live offline com apps criativos pré-instalados e instalação pkgbase offline
  exigem remaster no lado FreeBSD — futuro.
- 15.1: anti-cheat kernel (EAC/BattlEye) e DX12/VKD3D não confiáveis; fsync/
  seccomp do Proton não funcionam; CUDA/NVENC/NVDEC via libc6-shim requer shim
  com timerfd (15 tem timerfd; shims antigos tinham stub que abortava).

## 10. Reproduzir

```sh
./scripts/build-bsd-iso.sh                 # ISO + check estático
./scripts/build-bsd.sh                     # + gate QEMU duas fases
DINX_BSD_FREEBSD_VERSION=14.5 ./scripts/build-bsd-iso.sh   # base antiga
tailscale file cp dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso DDJARIN:
```

Variáveis: `DINX_BSD_FREEBSD_VERSION`, `DINX_BSD_SOURCE_SHA256`,
`DINX_BSD_SOURCE_URL`, `DINX_BSD_SOURCE_ISO`, `DINX_BSD_OUTPUT_DIR`,
`DINX_BSD_CACHE_DIR`, `DINX_BSD_QEMU_TIMEOUT`, `DINX_BSD_QEMU_ACCEL`,
`SOURCE_DATE_EPOCH`.

## 11. Entregas (taildrop → DDJARIN)

fix1–fix6 (14.5): auditoria, firstboot, sessões, gaming — gates verdes.
fix7 (14.5 live): gate falhou (hostname/marker live) — superseded.
fix8 (15.1 live+installer): **gate duas fases PASS**; sha256
`49dd35a2726c2d6056799c47e28f2debc6606e7689bfcbcbc551615164a13d7f`; entregue
em DDJARIN. É a imagem para teste de boot.

## 12. Próximos passos reais

1. VM FreeBSD de build: zig 0.16, wlroots020, gtk4, meson; compilar
   Aqueous/Pearl/Noctalia e greetd (cargo); `pkg create` real + `pkg repo`.
2. Remaster pkgbase offline (live com apps criativos) no lado FreeBSD.
3. Wizard gráfico (Pearl/Qt) substituindo o TUI.
4. Patches FreeBSD do wine-proton (bug 288475) e do libc6-shim quando o
   pacote oficial ficar atrás do upstream.

## 13. Marco 2 — binários nativos (em andamento)

- VM FreeBSD 15.1 de build (qcow2 do gate, 4 vCPU/4G, SSH via hostfwd 2222 +
  QMP unix socket para screendump). Disco expandido offline (+16G) e UFS
  crescido online: `gpart resize -i 1 vtbd0` (slice MBR), remover swap
  (`gpart delete -i 2 vtbd0s1`), `gpart resize -i 1 vtbd0s1`, `growfs -y /`.
- Upstream real: `Seafoam-Labs/Aqueous` (build em `compositor/`) e
  `Seafoam-Labs/pearl` (0.3.9, Zig >= 0.17.0). Zig 0.17.0 oficial
  freebsd-x86_64 baixado na VM; deps: wlroots020, wayland-protocols,
  libxkbcommon, pixman, libinput, seatd, gtk4, gtk4-layer-shell, meson,
  ninja, pkgconf, git-lite, rust, gobject-introspection, mesa-dri.
- `scripts/bsd-vm/build-native.sh`: build Zig nativo (Aqueous/Pearl) +
  greetd via cargo; `pkg create` real + `pkg repo` → catálogo local.
- mangohud não existe no quarterly (só latest) → fora do firstboot,
  documentado como opcional.
- Prova gráfica planejada: screendump QMP da sessão greetd→Aqueous→Pearl
  após os `.pkg` reais entrarem no repo da ISO.
- Lições de VM: o validator recria o disco com `--disk-size` (default 12G) —
  usar `--disk-size 32G` para VM de build; disco cheio corrompe o DB do pkg
  e o UFS (kills durante escrita) → reinstall limpo em vez de fsck em rw;
  `PermitRootLogin yes` + chave ed25519 via serial para operar por SSH;
  repo `latest` estoura o limite de catálogo do pkg 2.8.4 → ficar no
  quarterly e patchear floors de versão (gtk4 4.20.4) no Pearl.
- Patches FreeBSD em `build-native.sh`: `c.h` do Aqueous usa
  `dev/evdev/input-event-codes.h` em vez do header Linux; Pearl perde o
  floor `pam >= 1.7.2` (libpam da base, sem .pc) e gtk4 >= 4.20.4.
- O firstboot detached segura o lock do pkg no primeiro boot → o setup de
  build deve esperar `desktop-setup-done` antes de instalar deps.
- Porting real (marco 2): o Aqueous exige um **wlroots 0.20.2 privado**
  (45+ patches upstream em `compositor/patches/wlroots/`, script
  `build-wlroots-render-hook.sh`); o pipeline roda esse script com prefixo
  de staging e empacota o resultado como `dinx-wlroots`. Faltavam `glslang`
  (fatal no meson) e headers glibc (`sys/sysmacros.h`, `linux/input*.h`) →
  shims em `/usr/local/include` apontando para os equivalentes FreeBSD
  (`sys/types.h`, `dev/evdev/*`).
- `prctl(PR_SET_PDEATHSIG)` → `procctl(P_PID, 0, PROC_PDEATHSIG_CTL, &sig)`;
  `PR_SET_CHILD_SUBREAPER` → `procctl(..., PROC_REAP_ACQUIRE, NULL)`
  (aproximação documentada). Aplicado em Pearl (libc.h wrapper + call sites
  Zig) e greetd (`session/prctl.rs` via `libc::procctl`).
- greetd 0.10.3 builda nativo (cargo) e já está empacotado
  (`dinx-greetd-0.10.3.pkg` + catálogo `pkg repo`).
- Pearl usa `statx`/`mallopt` (glibc) em vários módulos e lê `/proc/*`:
  em vez de patchear cada call site, `scripts/bsd-vm/dinxcompat.c` provê
  `statx` emulado sobre `fstatat` (layout do struct statx do kernel) e
  `mallopt` no-op; `build.zig` do Pearl linka `dinxcompat` em todo módulo
  via `createModule`. `/proc` vem de linprocfs montado best-effort pelo
  wrapper de sessão.
- O wlroots patcheado instala pkg-config em `libdata/pkgconfig` (não
  `lib/pkgconfig`) no FreeBSD — `PKG_CONFIG_PATH` do build aponta para lá;
  o teste de regressão scRGB do script upstream falha em VM headless
  (biblioteca instala normalmente; caveat documentado).
- **Aqueous 1.0.5 buildou nativo no FreeBSD 15.1** e está empacotado
  (`dinx-aqueous-1.0.5.pkg`). Duas correções finais foram necessárias:
  a lib wlroots patcheada precisava vencer a ordem de `-L` do linker
  (copiada para `/usr/local/lib`), e o `activity_bootstrap.c` usa
  `SO_PEERCRED`/`SO_PEERPIDFD`/pidfd (Linux-only) → guarda `#ifdef
  __FreeBSD__` desabilita os *activity claims* (degradação documentada).
- Pearl: `siginfo_t` no FreeBSD expõe `pid` direto (sem union Linux);
  `PTHREAD_ONCE_INIT` (macro com braces) → `std.mem.zeroes` em
  `repository.zig` e `fetch.zig`.

## 14. Tempos de build e custo de refresh de upstream

Medidos na VM de build (FreeBSD 15.1, 4 vCPU / 4 GB, KVM), por estágio
(`times.log`, epoch seconds):

| Estágio | Cold (caches zerados) | Warm (caches válidos) |
|---|---|---|
| wlroots 0.20.2 patcheado (45+ patches, meson) | 23 s | 0 s (staging reutilizado) |
| Aqueous (Zig 0.17, translate-c + link) | 55 s | 1–35 s |
| libdinxcompat (cc) | 2 s | 2 s |
| Pearl (Zig 0.17, GTK4 bindings) | 493 s | 90–171 s |
| greetd (cargo) | 29 s | 0–2 s |
| pkg create + pkg repo | ~1 s | ~1 s |
| **Total** | **~603 s (~10 min)** | **no-op ~53 s; com mudanças 2–4 min** |

Custo de uma versão nova do upstream = rebuild cold (~10 min) **+ o trabalho
humano de rebase dos patches**, que é a parte variável:
- O wlroots é um fork privado pinado em 0.20.2 com 45+ patches; subir a
  versão do wlroots exige rebase manual desse conjunto (horas, não minutos).
- Aqueous/Pearl podem introduzir novos Linux-isms a cada release; cada um
  vira uma rodada de patch (compile ~2–5 min + análise). O histórico desta
  sessão: 16 patches para levar Pearl de "não compila" a binário nativo.
- `patch-freebsd.py` falha alto (`PATCH PATTERN MISSING`) quando o upstream
  move o código patcheado — o refresh nunca passa silenciosamente.
- Recomendação: pinar versões upstream (como já feito: wlroots 0.20.2,
  Pearl 0.3.9, Aqueous 1.0.5) e tratar refresh como tarefa planejada com
  orçamento de rebase, não como `pkg upgrade` automático.

## 15. Temas trazidos da branch `themes`

A branch `themes` (Linux/Artix) carrega a identidade visual DINX. Os assets
portáveis foram extraídos para `distro/bsd/config/theme-overlay/` com o
layout alvo e entram no overlay da ISO:
- `usr/local/share/themes/DINX/` — tema GTK3/GTK4 (css claro/escuro +
  `index.theme`, IconTheme=Papirus).
- `usr/local/share/dinx/theme/DINX.json` — paleta Material do Pearl
  (dark/light, cores de terminal).
- `usr/local/share/color-schemes/DINXDark.colors` + `etc/skel/.config/qt6ct/`
  — seed qt6ct para apps Qt6.
- `usr/local/libexec/dinx-sync-session-theme` — lê as preferências do Pearl
  (`preferences.json`/`last-good.json`) e sincroniza GTK/settings.ini;
  `dinx-qt6ct-palette-seed` — semeia a paleta qt6ct sem sobrescrever
  customizações do usuário (preserva symlinks).
- O wrapper de sessão executa ambos no início de cada sessão; `jq` entrou
  nas deps do firstboot.
Ficaram de fora (Linux-only, documentado): tema GRUB (o FreeBSD usa
loader(8)) e Plymouth (splash do loader é outro mecanismo).
Nota de porting adicional: o FreeBSD 15 divide libc/libsys e o `__progname`
vem do crt1.o, que o startup do Zig não fornece → `dinxcompat` define
`__progname` (nome cosmético) e o Aqueous passa a linkar `dinxcompat`.

## 16. Porting do greetd (cargo) para FreeBSD

greetd 0.10.3 builda nativo com cargo, mas o runtime exigiu quatro correções
FreeBSD (todas versionadas em `patch-freebsd.py` / overlay):
1. **PAM**: falta o serviço `greetd` → `distro/bsd/config/pam.d/greetd`
   (pam_unix para auth/account/session/password).
2. **Socket**: greetd binda `/run/greetd.sock`; FreeBSD tem `/var/run` →
   symlink `/run -> /var/run` no precmd do rc.
3. **Re-exec**: greetd re-executa via `/proc/self/exe` → linprocfs montado
   em `/proc` no precmd do rc (e no wrapper de sessão).
4. **VTs**: upstream abre `/dev/ttyN`; FreeBSD usa `/dev/ttyvN` → patch em
   `server.rs` (prefixo, tty0 e format de vt).
Config: `[terminal] vt = 1` obrigatório; `[initial_session]` faz autologin
do usuário `dinx` no live; `[default_session]` usa agreety no instalado.

## 17. Linkagem: `--as-needed` e o shim crt

O Zig linka com `--as-needed`; `libdinxcompat` não tem símbolos referenciados
diretamente pelo executável (`__progname` é referenciado pela libc), então o
linker a descartava e o binário morria com `Undefined symbol "__progname"`.
Correção: `linkSystemLibrary("dinxcompat", .{ .needed = true })` no Aqueous e
no Pearl (patch #20). Lição geral: shims de símbolos indiretos precisam de
`DT_NEEDED` explícito.

## 18. Corrupção de UFS: shutdown perdido, não o cache

Sintoma: todo boot de disco instalado parava em `fsck_ufs: Directory N name
not found / Unknown error 11`, mesmo após install "limpo".
Causa raiz: o comando `poweroff` enviado pelo gate se perdia no ruído do
motd; o gate então matava o QEMU a seco (SIGTERM) com o journal SU+J sujo.
`cache=unsafe` ignora FLUSH, mas com **unmount limpo** o UFS grava o
superblock clean e o boot seguinte não replays journal — seguro.
`cache=writeback` respeita flushes porém torna a extração do base.txz
lenta demais (>21 min vs 142 s com unsafe) — inviável para o gate.
Correção: manter `cache=unsafe` + shutdown robusto no gate (login root,
`shutdown -p now` repetido 2x com espera, wait 90 s). Lição: a durabilidade
vem do unmount limpo do guest, não do modo de cache do QEMU.

## 19. Empacotamento nativo: formato do pkg e shlibs

`pkg create -m` não varre o rootdir; com `-p` o plist usa paths **absolutos
de instalação** e o rootdir é o stage (`usr/local/...`). `shlibs_provided`
nunca é calculado com `-p` (e um campo escrito à mão no +MANIFEST é
descartado) → pós-injeção: extrair o .pkg, editar +MANIFEST e
+COMPACT_MANIFEST com python, reempacotar com `tar -P -cf ... -s '|^usr|/usr|'`
(membros absolutos, manifests sem `/`). Sem isso, `pkg add` falha com
"Missing shlib libdinxcompat.so" ou "//usr/local/... not specified".
`dinx-wlroots` conflita com `wlroots020` (mesmos arquivos) → o firstboot
instala só o dinx-wlroots.

## 20. Runtime: statx, environ e o socket Wayland do Aqueous

`std.os.linux.statx` é syscall Linux cru (o shim libc não intercepta) →
patch no std do Zig roteando para o statx do libdinxcompat
(`@extern(*const fn ... callconv(.c) c_int, .{ .name = "statx" })`).
Helper exes Zig (aqueousctl) não exportam `environ`, que a libc do FreeBSD
exige do executável → storage no shim + `LD_PRELOAD` do shim nesses helpers
(preload no compositor o mata).
**Causa raiz resolvida (§20 corrigido):** o que parecia "socket Wayland que
nunca escuta" era, na verdade, o compositor morrendo de **SIGSYS** logo após
`Starting Xwayland on :0`. Backtrace gdb:
`IpcServer.privateDirectory() -> linux.getuid() -> os.linux.x86_64.syscall0`
(exit 140 = 128+SIGSYS). `std.os.linux.getuid()` é syscall Linux cru; no
FreeBSD o número cai fora da tabela e o kernel devolve SIGSYS. Como a morte
era instantânea, o socket ainda não estava em listen → `connect()` dava
ECONNREFUSED e o `sockstat` não mostrava listener (sintoma, não a causa).
Correção (patch #25): `linux.getuid()` → `std.c.getuid()` (libc portável).
Xwayland já inicia de fábrica no build `-Dxwayland=true`.

## 21. Estado verificado (ISO 15.1 com repo nativo)

Gate unattended na ISO rebuildada: install + firstboot + login em ~127 s,
shutdown limpo. No disco instalado, o firstboot instalou do repo local
embarcado os cinco pacotes: dinx-compat, dinx-wlroots, dinx-aqueous,
dinx-pearl, dinx-greetd (mais seatd/pipewire/wayland/mesa-dri/gtk4 etc.);
`/usr/local/bin/pearl`, `/usr/local/bin/aqueous` e
`/usr/local/etc/greetd/config.toml` presentes; `dinx_greetd`/`seatd`
habilitados pelo script. SHA-256 da ISO: 32a58e9432599d50055c19a7475ab4b19a
aa847bb625fe94e8fc92615fa342e8.
Pendência: sessão gráfica interativa (blocker do §20 — socket Wayland do
Aqueous sem listener no FreeBSD). A prova headless mostra o compositor
renderizando (llvmpipe, HEADLESS-1 1280x720), mas nenhum cliente anexa.

Consolidação de tudo que funciona / não funciona (com nível de evidência por
item): `docs/DINX-BSD-STATUS.md`.

## 22. Weston nativo + Xwayland (decisão de produto)

O compositor da sessão passou a ser Weston 14.0.2 buildado nativamente
(`scripts/bsd-vm/build-weston.sh`), com Xwayland habilitado; Aqueous fica como
alternativa empacotada. Porting aplicado: ETIME→ETIMEDOUT;
program_invocation_short_name→getprogname(); pty.h→libutil.h (+-lutil);
CLOCK_MONOTONIC_RAW→CLOCK_MONOTONIC; shims linux/ioctl.h e linux/types.h;
environ como **weak extern** (definição no objeto sobrescreve o crt1 e
segfaulta em `custom_env_init_from_environ`); -lepoll-shim global; opções
meson do 14.0.2 (sem colord/elogind/werror/shell-lua; backend-drm=false +
backend-default=headless; tools=[]; simple-clients=[]; renderer-gl=false).
Resultado: Weston compila/instala, **socket Wayland escuta** (CONNECT_OK) e
weston-keyboard/desktop-shell ficam vivos — o caminho socket/event-loop do
Weston funciona no FreeBSD, ao contrário do Aqueous (§20).
Blockers abertos: (a) segfault (signal 11) no launch do filho Xwayland
("Couldn't unset CLOEXEC on child FDs"; race, não reproduz sob gdb);
(b) `xwayland-path` do weston.ini ignorado (segue /usr/bin/Xwayland);
(c) Pearl instalado stale (patches #22/#23 no fonte, binário anterior);
(d) weston-screenshooter aborta `width > 0` (mode do output headless).
Empacotamento: dinx-weston com shlibs_provided (libweston-14) e sem
shlibs_required (libpulsecommon é lib privada do pulseaudio); firstboot
instala dinx-weston + xwayland + pulseaudio. Provas: proof5–8 (redirecionadas,
screenshooter com perl alarm; serial trunca linhas >~256 chars).

## 23. Aqueous corrigido: a causa real era SIGSYS, não o socket

A conclusão do §20 ("socket não escuta") estava **errada**. Com gdb em cima do
binário nativo, o compositor morria com **SIGSYS** (exit 140) logo após
`Starting Xwayland on :0`. Dois backtraces:
`IpcServer.privateDirectory() -> linux.getuid()` e
`wm/output/Service.openSocket() -> linux.unlink()`.

Causa raiz: o Aqueous chama ~20 syscalls **diretamente** via `std.os.linux.*`
(socket/bind/listen/accept4/getsockopt/unlink/chmod/open/statx/...), que
emitem o **número de syscall Linux cru**. No FreeBSD esses números caem fora
da tabela e o kernel devolve SIGSYS. Como a morte era instantânea, o socket
ainda não estava em listen → `connect()` dava ECONNREFUSED (sintoma, não causa).

Correção: `scripts/bsd-vm/dinxlinux.c` — camada C que traduz o ABI Linux para
FreeBSD (números de errno e de flags, layout de `sockaddr.un`,
`SO_PEERCRED`→`getpeereid()`, `statx`→`fstatat`, `SOCK_CLOEXEC`/`NONBLOCK` via
fcntl, `MSG_NOSIGNAL`→`SO_NOSIGPIPE`), devolvendo na convenção `usize` do
`std.os.linux` para que `linux.errno(rc)` continue valendo. `bsd_compat.zig` é
o front-end Zig fino (externs + adaptação de tipos); o patch #26 reescreve os
call sites `linux.<syscall>(` → `bsdcompat.<syscall>(` mantendo `linux.errno`,
tipos e constantes do std. Compilado em `libdinxcompat.so`.

**Resultado verificado em VM FreeBSD 15.1 (headless, llvmpipe):**
`WAYLAND_DISPLAY=wayland-1` criado, `AQUEOUS_SOCKET=.../ipc.sock` escutando,
`XWAYLAND_OK version number: 11.0`, `XTERM_WINDOWS=1` (cliente X11 real
através do Xwayland), e `GRIM_RC=0` → PNG de 6499 bytes do compositor via
wlr-screencopy. **Compositor, Xwayland e captura funcionam.**

Pendência (resolvida no §24): o Pearl abortava com `error=InvalidCss` — o CSS
embutido usa `backdrop-filter`, propriedade que só existe no GTK ≥ 4.22; os
ports do FreeBSD estão em GTK 4.20.4. Patch #27 remove as declarações
`backdrop-filter` antes do build (efeito cosmético; o shell sobe). O compositor
não seta `XDG_CURRENT_DESKTOP`, então o init da sessão o exporta como `Aqueous`.

## 24. Desktop funcional: evidência verificada

Prova em VM FreeBSD 15.1 (headless, llvmpipe), com o compositor lançado pelo
seu contrato real (`aqueous -c <init>`, que injeta `WAYLAND_DISPLAY`,
`AQUEOUS_SOCKET` e `DISPLAY` no filho init e mantém o loop vivo):

```
WAYLAND_DISPLAY=wayland-1
AQUEOUS_SOCKET=/home/dinx/.run/aqueous/d8e26a3.../ipc.sock
DISPLAY=:0
XWAYLAND_OK version number:    11.0
XTERM_WINDOWS= 1
PEARL_ALIVE=yes
info(pearl): event=ready mode=session
info(pearl): event=desktop app-index-ready entries=5
GRIM_RC=0   -rw------- 1 dinx wheel 6499 /tmp/dinx-desktop.png
```

A captura `docs/proof/aqueous-desktop-xwayland.png` (1280×720) mostra a janela
do xterm aberta **via Xwayland** com o texto `DINX_XWAYLAND_WINDOW_OK`, borda e
cantos arredondados do pipeline Vulkan do compositor, e cursor. Ou seja:
compositor, Xwayland, shell Pearl e captura por wlr-screencopy funcionam.

Fixes que destravaram o Pearl: patch #27 remove `backdrop-filter` do CSS
(propriedade GTK ≥ 4.22; ports têm 4.20.4 — o parser do GTK abortava com
`error=InvalidCss`) e patch #28 baixa o floor `gtk4 >= 4.22.5` → `>= 4.20.4` e
remove a exigência de `pam >= 1.7.2` (base não tem .pc). O init exporta
`XDG_CURRENT_DESKTOP=Aqueous` porque o compositor não o define.

## 25. Boot autônomo: do login de texto ao desktop no boot

O §24 provou o desktop **manualmente** (script de prova que lança o Aqueous
com um init de teste). O boot real ainda caía no login de texto: o shell
morria e nada subia sozinho. Nove itens a seguir, todos com evidência de
`truss`/`ktrace`/`readelf`/log do kernel:

1. **`/proc` ausente** — o `greetd` re-executa o helper de sessão via
   `/proc/self/exe`; sem procfs, `execve("/proc/self/exe")` devolve ENOENT e o
   spawn abortava (`unable to exec: ENOENT` em `greetd/src/session/interface.rs`).
   Mesmo `/bin/echo` como comando de sessão panicava. Fix: montar
   procfs/linprocfs no precmd antes de subir.
2. **`agreety` sem terminal controlador** — o greeter aborta com SIGABRT
   `failed printing to stderr: Device not configured (ENXIO)` ao escrever num
   `/dev/tty` que não existe sem ctty. O autologin do fork (`initial_session`)
   só funciona num console/ssh real, nunca sob `daemon(8)` vindo do `rc`.
3. **Decisão de produto** — em vez de depender do greeter, o boot do desktop
   vira um serviço rc direto (`rc.d/dinx_session`, estilo helloSystem/NomadBSD):
   `daemon -- script -q /dev/null su -m dinx -c dinx-session-select
   </dev/ttyv0 >/dev/ttyv0`. O `script(1)` dá um PTY (ctty real) à sessão; o
   `greetd` fica só como greeter interativo de fallback.
4. **`su -m` preserva `HOME` do pai** — o Pearl/wireplumber abortavam com
   `AccessDenied` criando diretórios de estado sob `/root`. Fix:
   `session-common` resolve o home pelo `/etc/passwd` quando `$HOME` não é
   gravável.
5. **Idle-exit do Aqueous (falsa causa)** — o compositor arma um timer que só
   um cliente IPC renova, e o §24 documentou a sessão caindo minutos após
   `event=ready`. Chegou-se a adicionar um keepalive `aqueousctl windows`, mas a
   evidência E2E o refutou: com o `aqueousctl` quebrado (item 9) o keepalive
   morria em ~6 s e a sessão ainda assim sobrevivia 20+ min. O cliente IPC
   persistente **é o próprio Pearl**; a queda anterior era o SIGSYS do item 8.
   Keepalive removido — e não pode voltar: `exec pearl` substitui o shell do
   init, que então nunca limparia o loop na saída da sessão.
6. **`/tmp` do live é cd9660 read-only** — a extração do overlay falhava
   (`mkdir /tmp/...: Read-only file system`). Fix: `rc.local.live` monta
   tmpfs em `/tmp` antes de gravar.
7. **Wizard bloqueava o boot** — `dinx_first_run` rodava o `bsddialog` em
   primeiro plano dentro do `rc`. Fix: destacado via `daemon(8)`, com watchdog
   `DINX_FIRST_RUN_DEFAULTS` que aplica os padrões e sobe o desktop quando
   nenhum operador atende (VM headless). O live (mídia de instalação, sem os
   pacotes desktop) mantém o login de console.

8. **Shell Pearl SIGSYS** — o shell atingia `event=ready` e `app-index-ready` e
   morria no mesmo instante com `signal 12`. O `ktrace -i` cravou o syscall:
   `CALL compat.recv` → `RET -1 errno 78` → `PSIG SIGSYS`. A origem é
   `config/aqueous_display_ipc.zig`, que valida o peer do compositor com
   `std.os.linux.getuid()`: no Linux `getuid` é o syscall **102**, e no FreeBSD o
   **102** é o `recv` obsoleto — logo a chamada cai numa syscall inexistente.
   O `patch #26` varria esses call sites só no **Aqueous**; o `#29` passa a varrer
   todo o `pearl/src` (`statx` fica de fora: o `#21` já o roteia no std, e o Pearl
   passa máscara literal anônima que o `@bitCast` do wrapper não dimensiona).
   Depois disso restou `error=RandomUnavailable`: `std.os.linux.getrandom` também
   é syscall cru, e cinco call sites o alcançam por caminhos distintos (inclusive
   via alias `const linux = std.os.linux`), então varrer por texto é frágil. O
   `patch #30` reescreve a função no próprio `std/os/linux.zig` para chamar a
   libc — mesma técnica do `#21` para `statx`, e o FreeBSD tem `getrandom(2)` com
   semântica e valores `GRND_*` idênticos. Por fim, `dinx_socket` traduz os
   domínios AF (`AF_INET6` 10→28) e devolve `EAFNOSUPPORT` para `AF_NETLINK`
   (hotplug udev, Linux-only); o watcher então degrada para polling, visível no
   log como `sched-profile-systemd result=uevents-unavailable` → `result=polling`.
9. **`aqueousctl` sem `libdinxcompat.so`** — o binário falha ao carregar com
   `Undefined symbol "environ"`. O shim define `environ`/`__progname` justamente
   para ele, mas o `patch #20` força `.needed = true` apenas no
   `river.root_module` (o `aqueous`), e o `--as-needed` descarta a lib no exe
   auxiliar: `readelf -d` confirma `libdinxcompat.so` presente no `aqueous` e
   ausente no `aqueousctl`. Pendente — não afeta o boot do desktop (o item 5
   mostra que nada depende dele).

Evidência, instalação limpa a partir da ISO nova sem nenhuma intervenção
(`build-bsd-iso-unattended.py`, disco 32G, boot frio):

```
install-dinx-bsd: first-boot desktop setup finished
rc.d/dinx_session -> aqueous -c /tmp/xdg-runtime-1001/dinx-init   (vivo, estável)
                     Xwayland :0 -rootless                        (vivo)
                     wayvnc --render-cursor 0.0.0.0 5900          (vivo)
info(pearl): event=ready mode=session
info(desktop): event=app-index-ready entries=4 truncated=false
info(ui): event=output-mapped id=1 connector=HEADLESS-1 renderer=GskCairoRenderer
info(pearl): event=settings-backend-ready
info(pearl): event=control-ready
wayvnc  15026  8 tcp4  *:5900
RFB 003.008 / desktop name 'WayVNC' / framebuffer 1280x720
```

Contagens zeradas no log da sessão: `RandomUnavailable`, `css-error`,
`startup-failed=InvalidCss`, `ipc-disconnected`. Nenhum SIGSYS novo: a varredura
`#29`/`#30` eliminou a classe de syscall Linux crua do shell.

**O que ainda não funciona — o shell Pearl cai após o startup.** O compositor, o
Xwayland e o wayvnc ficam de pé e compõem janelas de clientes normalmente
(captura `grim` de 1280×720 com `xterm`: 889 152 px brancos + 7 888 px do accent
`#88C0D0`; e `gtk4-demo` renderizando com 1270 cores distintas — o caminho
GTK4 + pixman/cairo funciona para janelas comuns). Mas o `pearl` em si aborta:

```
(pearl:15025): Gtk-WARNING **: GtkImage ... reported baselines of
              minimum -2147483648 and natural -2147483648      (repetido)
(pearl:15025): Gdk-CRITICAL **: gdk/wayland/gdkshm.c:204:
              Unable to create Cairo image surface: invalid value
Segmentation fault at address 0x18
  0x808359d00 in ??? (/usr/local/lib/libgtk-4.so.1)
  ...
  /root/build/pearl/src/core/application.zig:522:47: in run (pearl)
kernel: pid 15025 (pearl), uid 1001: exited on signal 6
```

Duas armadilhas de verificação que este journal cometeu no caminho e que valem
registro: (a) `pgrep -l pearl` lista **zumbis** — o processo aparecia como vivo
depois de morto, então "pearl sobreviveu N minutos" era falso; o estado real só
aparece em `ps -o pid,etime,stat` (`Z <defunct>`) ou no `exited on signal` do
kernel; (b) o framebuffer escuro foi lido como "wallpaper dark do tema", quando
na verdade era o chrome do Pearl nunca desenhado porque o shell já havia caído.
O próximo passo é o `gdkshm` `cairo_image_surface_create` devolvendo
`CAIRO_STATUS_INVALID_*` no backend wayland headless, precedido pelos
`GtkImage` com baseline `INT32_MIN` — indício de ícone não carregado (tema de
ícones ausente) alimentando uma superfície de tamanho inválido.

## 26. Port do kwm (window manager do river) para FreeBSD

O stack river exige duas peças: o compositor `river`, que existe no catálogo
FreeBSD como `river-0.4.8` (origin `x11-wm/river`, verificado com `pkg which
/usr/local/bin/river`), e o window manager `kwm`, que implementa
`river-window-management-v1` e não tem port — o river recusa ser útil sem um.
O kwm é Zig e compila para FreeBSD, mas choca com três diferenças de ABI que
são de **tipo**, não de syscall. Fato decisivo medido na VM: o libc do FreeBSD
15.1 resolve `timerfd_create`, `timerfd_settime`, `pipe`, `pipe2`,
`memfd_create` e `sigaction` a partir de um `cc` puro (`cc_rc=0`, fd 3 e 8);
`signalfd` é o único que não existe (`sys/signalfd.h` ausente).

Como o kwm `.link_libc = true` (build.zig:246), `std.posix.system` resolve
para `std.c`, então os `extern "c"` do std **já** existem; os gaps reais são:

1. **`system.TFD` é `void` no FreeBSD.** O std só declara o bitfield de flags
   do timerfd para Linux, então os literais `.{ .NONBLOCK = true,
   .CLOEXEC = true }` de `src/kwm/key_repeat.zig:25` não compilam. Declaramos
   `DinXTFD` com as posições do FreeBSD: `TFD_TIMER_ABSTIME` 0x01 (bit 0),
   `TFD_NONBLOCK` = `O_NONBLOCK` 0x0004 (bit 2), `TFD_CLOEXEC` = `O_CLOEXEC`
   0x00100000 (bit 20), lidas de `<sys/timerfd.h>` + `<sys/fcntl.h>` na própria
   VM.
2. **`signalfd` não existe.** Emulado com self-pipe: `pipe2` da libc + um
   handler `sigaction(2)` que escreve um `posix.siginfo_t` por sinal, formato
   que o loop do kwm (`kwm.zig:100`, `read(posix.siginfo_t, fd)` + `.signo`)
   já consome sem alteração. Consequência comportamental que é fácil de
   perder: o self-pipe só dispara se o sinal for **entregue**, mas o kwm chama
   `sigprocmask(BLOCK)` antes de criar o fd — no Linux esse bloqueio é
   exatamente o que roteia os sinais ao signalfd. O shim portanto instala os
   handlers e depois **limpa a máscara** (`SETMASK` com conjunto vazio), o
   mesmo reset que o próprio kwm já faz no double-fork de `context.zig:975`.
3. **`std.c.itimerspec` renomeia os campos**: `interval`/`value` no FreeBSD,
   `it_interval`/`it_value` no Linux. Só o literal que constrói em
   `key_repeat.zig:48` precisa do rename; o de reset é `mem.zeroes()`.

Um quarto erro não era nosso: `E.LIBBAD` (`src/posix.zig:362`, ramo aninhado
do `execve`) é tag Linux-only e não membro do enum do FreeBSD — gap pré-
existente do kwm. Varredura dos 34 tags `E.*` usados pelo fonte contra os 98
membros de `c/freebsd.zig` devolveu **só** `LIBBAD` ausente (`@"2BIG"` existe;
`CHLD`/`KILL`/`QUIT` são tags de `SIG`, não de `E`).

Método desta vez, depois de duas rodadas queimadas em adivinhação de API:
cada símbolo do shim foi provado por **compilação independente** na VM, um
mini-programa por superfície, antes de qualquer patch ser escrito (sondas A–J
em `sigprobe.sh`/`sigmulti.sh`). Isso exporou dois erros meus de rascunho:
`std.posix.pipe` **não existe** no Zig 0.17 (idem `write`, `close` e `fcntl` —
só `std.c.pipe`/`extern`), e `posix.empty_sigset` não existe (usar
`sigemptyset()`). Também revelou que `O` do FreeBSD aceita
`@bitOffsetOf(posix.O, "NONBLOCK")` (é packed struct) mas **não** expõe
`O.NONBLOCK` como valor plano — então o argumento de flags que o kwm já computa
no call site do signalfd é reutilizável, e com ele o `pipe2` recebe os `O_*`
corretos por valor.

`memfd_create` não precisa de patch: `std.posix.memfd_create` já trata
`.freebsd` para ≥ 13, e o `linux.MFD.CLOEXEC` que o kwm passa em
`render/buffer.zig:43` é 1 — igual ao `MFD_CLOEXEC` do FreeBSD. (Confira-se a
afirmação anterior deste journal, que tratava o valor como 2: 2 é
`MFD_ALLOW_SEALING`.)

O patch vive em `scripts/bsd-vm/patch-kwm-freebsd.py` (7 correções
idempotentes, uma por token de marcação próprio — um marcador global faria os
patches seguintes serem pulados como "já aplicados", erro que cometi e corrigi
antes do build). A versão de port usa o mesmo conteúdo como unified diff em
`distro/bsd/ports/files/kwm-freebsd.patch`, aplicado com `-p0` porque os paths
são relativos ao `WRKSRC`.

Evidência, VM FreeBSD 15.1 (zig 0.17.1, river 0.4.8, backend headless):

```
patch_rc=0        # 7/7 blocos aplicados
fetch_rc=0
build_rc=0        # zig build -Doptimize=ReleaseSafe -Dbar=true -Dkwim=true
kwm: ELF 64-bit LSB executable ... for FreeBSD 15.1
deps: all resolved          # ldd sem "not found"
dinxcompat refs = 0         # o port não depende do shim Linux-ABI
after 6s: 19584   Ss   00:06   KWM_ALIVE=yes
NoFont=0
info(kwm): start running
info(kwm): stop running      # após kill -TERM
info(context): deinit context
SIGNAL_HANDLED=yes (exited, awaiting reap)
```

A prova de sinal é a que importa: `start running` sobrevive 6 s no poll loop e
só sai pelo caminho limpo (`stop running` + `deinit`) depois do `SIGTERM`, ou
seja a emulação de signalfd entrega o sinal através do self-pipe em runtime,
não apenas compila. Duas leituras erradas no caminho, ambas dignas de
registro: (a) `pgrep -x kwm` responde **zumbis** — o estado real só sai de
`ps -o stat` (item 5 do §25; a primeira rodada reportou `SIGNAL_HANDLED=no`
porque o processo já estava morto antes do kill, não porque o handler falhou);
(b) a queda nas duas primeiras rodadas não era o port, era a VM sem fontes:
`fcft.c:572 monospace:size=10 failed to match font` → `error.NoFont` mata o
`create output`. Com `terminus-font` + `fontconfig` instalados (`fc-match:
Terminus`) o `NoFont` vai a zero. O pacote do guest não tem `fc-fontconfig`/
`dejavufonts` (nomes que chutei); o certo é `x11-fonts/terminus-font`.

Integração na pipeline: `dinx-kwm` entra no `build-native.sh` (clone no
`KWM_REV` pinado, patch, build, `pkg create`), no manifesto
(`x11-wm/dinx-kwm` + `x11-wm/river`), no gate (`check_dinx_bsd.sh` exige o
Makefile, o patch e o script), no `Makefile.kwm` do port, e a sessão
`dinx-river-session` passa a existir como escolha de sessão
(`dinx-session-set river`, `.desktop` próprio, instalado pelo overlay da ISO e
cobrado pelo `check-bsd-iso.sh`). O `dinx_session` do rc aceita qualquer um dos
dois stack (aqueous+pearl **ou** river+kwm) para decidir se sobe, e o stop
limpa `river -c`/`kwm`. O que **não** está provado: o kwm gerenciando janelas
reais com o bar desenhado (a VM de build é headless e sem cliente GTK).

Nota de pin — corrigida depois do build: o port fixa o commit `8dafe7e`, **não**
o tag `v0.3.0`. O `v0.3.0.tar.gz` que o rascunho fixava não compila com o Zig
0.17 pinado: o `build.zig` do tag ainda lê `Build.build_root`, campo removido no
0.17 (prova no host: `zig build --fetch` → `error: no field named 'build_root'`
em `build.zig:64`), e o tag não traz cliente `kwim` algum. Os 7 anchors batem nas
duas árvores; a única diferença no caminho portado é `key_repeat.zig:25` (o tag
pede só `.NONBLOCK`, o commit pede `.NONBLOCK` + `.CLOEXEC`), e como `DinXTFD`
declara os dois campos com default `false` o patch compila nas duas versões sem
ramo por versão. O `WRKSRC` acompanha o nome do archive do GitHub
(`kwm-<sha>`). O `kwim` é repositório separado (`kewuaa/kwim`): o tag v0.2.0 tem
o mesmo mal do `build_root`, o master `a802d2d` ("Update for Zig 0.17",
`minimum_zig_version = 0.17.0`) compila na VM FreeBSD sem patch — `build_rc=0`,
`ldd` limpo — e seu único linuxismo é `memfd_create`, já nativo no FreeBSD 13+.
Ou seja: nem kwm nem kwim dependem de morghulis; o caminho inverso é que trava.

## 27. river + kwm + kwim + morghulis: o que falta e o que já está pronto

Objetivo do lane (dono, 2026-11-17): **fazer morghulis funcionar sobre river,
com kwm e kwim**. Estado medido na VM FreeBSD 15.1 (vala 0.56.19, meson 1.12,
gtk4 4.20.4, libadwaita 1.8.5.1, gtk4-layer-shell 1.3.0, river 0.4.8,
wireplumber 0.5.17, pipewire 1.6.9, upower 1.91.2, sassc 3.6.2):

**Pronto (compilado e instalado nesta rodada, 15 typelibs)**
- `river` 0.4.8: catálogo oficial (`x11-wm/river`), zero port necessário.
- `kwm`: §26, commit `8dafe7e`, patch de 7 blocos, `build_rc=0` + prova de sinal.
- `kwim`: repositório separado `kewuaa/kwim`, master `a802d2d` ("Update for Zig
  0.17") compila na VM **sem nenhum patch** (`build_rc=0`, `ldd` limpo). O tag
  v0.2.0 tem o mesmo defeito `Build.build_root` do kwm v0.3.0 — não usar.
- Astal 0.1 (`Aylur/astal`, main): `quarrel`, `astal/io`, `wl/wl`,
  `astal/gtk4`, `river`, `notifd`, `mpris`, `brightness`, `workspace`,
  `idle-notify`, `apps`, `battery`, `bluetooth`, `powerprofiles`, `tray` —
  todos `install=ok`, incluindo **`AstalRiver-0.1.typelib`**, que é exatamente o
  namespace que `morghulis/src/NavBar/RiverTags.vala` consome.
  `AstalWp-0.1` (wireplumber) também. Três correções, todas só-FreeBSD e neutras
  para upstream, em `scripts/bsd-vm/build-astal-morghulis.sh`:
  1. `valadoc` não existe (`lang/vala` é `--disable-valadoc`) e o `gir.py` de
     **todo** módulo o invoca → shim `distro/bsd/ports/files/astal-valadoc-shim`
     via a variável `VALADOC` que o próprio gir.py lê (`os.getenv`); `valac -C
     --library` produz o mesmo GIR, só sem comentários de doc (que alimentavam
     gi-docgen, não o typelib).
  2. `appmenu-glib-translator` declara `ulong name_id` (tipo inexistente no
     FreeBSD) → `gulong`. Cuidado: BSD sed não tem `\b`; `s/\bulong\b/` falha
     com "RE error: trailing backslash".
  3. O translator instala headers **flat**, mas seu `.vapi` declara
     `cheader_filename = "exporter/exporter.h,importer/importer.h"` → sem o
     layout em subdiretório o `lib/tray` morre com
     `'exporter/exporter.h' file not found`.
- `appmenu-glib-translator`: upstream real é
  `gitlab.com/vala-panel-project/vala-panel-appmenu`, subdir
  `subprojects/appmenu-glib-translator` (o `github.com/Aylur/...` **não
  existe**, 404). Deps só `gio-unix-2.0` + `gdk-pixbuf-2.0` opcional, e grep em
  `importer/`+`exporter/` não acha inotify/epoll/`/proc`/signalfd → portável.
- `sass` (morghulis compila `.scss` no build): ausente, mas **`sassc` 3.6.2
  existe** no catálogo → patch de uma linha no `find_program('sass')`.

**Bloqueios duros (precisam de decisão do dono, não de patch)**
1. **`libnm` / `astal-network`** — o único bloqueio *de link*. O `libnm` do
   FreeBSD é `net-mgmt/networkmanager-shim`, e ele é um stub sem símbolos:
   `nm -D libnm.so | grep -c nm_client` = **2**, e os dois são
   `nm_client_error_get_type` / `nm_client_instance_flags_get_type`; um
   `nm_client_new()` real falha com `undefined symbol`. Não há `NM-1.0.typelib`
   nem `libnm.vapi`, então o `astal/network` nem chega ao link:
   `error: Package 'libnm' not found in specified Vala API directories`. E o
   NetworkManager upstream é Linux-only por declaração própria ("Linux kernel
   >= 5.6", "only drivers shipped with the upstream Linux kernel"). Consequência:
   **morghulis não configura** enquanto `dependency('libnm')` e
   `dependency('astal-network-0.1')` forem incondicionais em `src/meson.build`.
   Opções: (a) backend FreeBSD de rede (ifconfig/wpa_cli/dhcpcd) como módulo
   próprio + fork do morghulis sem Network; (b) shim libnm real (símbolos +
   GIR) sobre o stack nativo; (c) aceitar morghulis sem o painel de Wi-Fi.
2. **`glycin-2` / `glycin-gtk4-2`** — dependência dura do morghulis, ausente no
   FreeBSD. Glycin é Rust; sua própria `meson.build:161` já desliga os loaders
   fora do Linux (`host_machine.system() == 'linux'`), então é portável por
   desenho, mas exige `rust` no builder.
3. **`astal/tray` em runtime**: OK compilado; `astal/bluetooth` compila mas é
   morto em runtime (não há provedor `org.bluez` no FreeBSD — só o stack
   netgraph da base, sem D-Bus); `astal/powerprofiles` idem (sem
   `power-profiles-daemon`); `astal/battery` **funciona** (upower presente).
4. **morghulis chama systemd diretamente**: `PowerMenu.vala:80/88/96/104/151` e
   `QuickMenu/PowerBox.vala:85-119` fazem `Process.spawn_command_line_async`
   com `systemctl poweroff|reboot|suspend|hibernate` e `loginctl
   terminate-user|lock-session`. No FreeBSD o equivalente é
   `shutdown`/`reboot`/`acpiconf -s`/`loginctl` inexistente → precisa patch ou
   shim `systemctl`.
5. **`river-shifttags`**: o `RiverTags` do morghulis executa
   `river-shifttags --occupied --shifts -1` (7 usos de `shifttags`). Esse
   binário **não vem** no river (`pkg-plist` do `x11-wm/river` tem só
   `bin/river` + os 6 protocolos XML) e não está no kwm; upstream é
   `gnuunixchad/river-shifttags` (C). Precisa port próprio.
6. `astal/auth` (PAM) não compila: `security/_pam_types.h` ausente — o guest
   não tem a dist `-dev` da base. `astal/cava` precisa `libcava` + `/dev/dsp`.
   Nenhum dos dois é usado pelo morghulis.

Nenhum módulo Astal usa inotify/epoll/signalfd/`/proc`/`/sys`: são clientes
GLib/D-Bus, então o `devel/glib20` do FreeBSD já resolve a portabilidade
(`file_monitor_backend=libinotify-kqueue` + `libepoll-shim`). O bloqueio é de
**daemons e bindings de build**, não de código.

## 28. morghulis no FreeBSD — e o conflito de protocolo que decide o stack

O objetivo do lane era "morghulis funcionar no river, com kwm e kwim". O build
funciona; o que **não** é possível é ter o painel de tags do morghulis e o kwm
ao mesmo tempo, por decisão do upstream do river, não por limitação do FreeBSD.

**O que compilou e rodou** (VM FreeBSD 15.1, `dbus-run-session river -c init`,
backend headless, gschema instalado):

```
pids:      pipewire=38204  kwm=38208  morghulis=38210
t=25s:     38210  S  00:22  morghulis      38208  I  00:24  kwm
t=40s:     38210  S  00:37  morghulis      38208  I  00:39  kwm
kwm log:   info(kwm): start running
river log: running init executable ... / running server
morghulis: ELF 1.9 MB "for FreeBSD 15.1", ldd 150 deps, 0 não resolvidas
```

Os três vivos juntos e estáveis por 40 s (stat `S`/`I`, não `Z`). O `--help`
só para em "Failed to open display", esperado sem scanout. Os `CRITICAL` que
sobram são daemons ausentes, não falhas do port: `bluetooth.vala:122` (não há
provedor `org.bluez`), `power-profiles.vala:58` (não há
`power-profiles-daemon`), `battery`/`.face.icon` (VM sem bateria nem avatar).

**O conflito de protocolo.** AstalRiver liga em `zriver_status_manager_v1`
(`lib/river/src/river.vala:234`, com `critical()` em :237 quando ausente) —
ou seja, `river-status-unstable-v1` + `river-control-unstable-v1`. O kwm
implementa `river-window-management-v1`. Medido por tag no diretório
`protocol/` do river:

| river | river-status-unstable-v1 | river-window-management-v1 |
|---|---|---|
| v0.3.0 … v0.3.12 | presente | ausente |
| v0.4.0 … v0.5.2 | **ausente** | presente |
| `main` | ausente | presente |

O river removeu o status em `a309d18e` (2024-07-21, "river: remove
river-status-unstable-v1") e o `window-management-v1` só entrou em 2026-09.
Nenhuma release carrega os dois. E o `river_output_v1` do protocolo novo
**não** expõe estado de tags (requests/events: destroy, removed, wl_output,
position, dimensions, set_presentation_mode, capture_sessions — nenhuma tag),
então não há como reimplementar o `RiverTags` sobre ele. Consequência: com
river ≥ 0.4 (necessário para o kwm) o morghulis só roda **sem** o módulo
river, o que derruba a barra de tags. Isso vale igualmente no Linux — não é
custo do port.

A escolha do `build-astal-morphulis.sh` é kwm + river 0.4.8 + morghulis sem
AstalRiver, porque o kwm é o window manager (sem ele não há como mover/fechar
janelas) e o morghulis trata `astal-river-0.1` como `required: false`
(`src/meson.build:26`), o que já exclui `RiverTags.vala` e o
`--define=river`. Implementado escondendo o `.pc` num diretório pkgconfig
filtrado (`$W/morghulis-pkgconfig`, symlinks de tudo menos `astal-river-*`)
durante configure+build, em vez de mover o arquivo — o resto do sistema
continua com o astal-river instalado. Verificado: `configure_rc=0`,
`ninja_rc=0`, `--define=river` ausente, astal-river continua visível fora do
filtro. `MORGHULIS_USE_ASTAL_RIVER=1` reverte quando o astal acompanhar o
`window-management-v1`.

**Outros fatos que custaram rodada e valem registro:**
- O pin é trunk `a3eb6d7`, **não** o tag `v0.14.0`. O tag (2025-11) chama
  `river.get_focused_output()`/`get_output()`, que o AstalRiver atual (2026-08)
  substituiu pela propriedade `focused_output` + `find_output_by_name()`; e o
  tag também não declara `astal_wl_dep`/`wayland-client`, o que faz o valac
  falhar com "The symbol `Wl' could not be found" (o valac **não** segue
  `Requires` do pkg-config transitivamente). O trunk já traz os dois.
- SCSS exige **dart-sass**: `main.scss` usa módulos (`@use "adw"; adw.$var`),
  que o `sassc`/libsass 3.6 do catálogo não interpreta
  (`Invalid CSS after "...border-radius: adw"`), e o `rubygem-dartsass` aborta
  com "does not support the amd64-freebsd platform". dart-sass é JS puro:
  `npm install sass` local + wrapper `sass` → `node sass.js` (provado: 1.108.2
  gera o CSS de 5675 bytes).
- O morghulis **exige** o GSettings instalado
  (`com.arkye.morghulis`); sem ele aborta com "Settings schema ... is not
  installed". O port tem que instalar o `.gschema.xml` e rodar
  `glib-compile-schemas`.
- Sem D-Bus de sessão o shell morre: `tray.vala:142`/`proxy.vala:67` com
  "Cannot autolaunch D-Bus without X11 $DISPLAY". Daí o `dbus-run-session` no
  `dinx-river-session`.
- `glycin` (dep dura do morghulis, ausente no FreeBSD) **compila**: rust 1.98.1
  do catálogo, `configure_rc=0`, `build_rc=0`, `install_rc=0`, gerando
  `glycin-2.pc` e `glycin-gtk4-2.pc`. O README dele já desliga os loaders fora
  do Linux (`host_machine.system() == 'linux'`), então a portabilidade é por
  desenho. A primeira falha foi meu `timeout 240` no ninja ("interrupted by
  user"), não o código.
- `river-shifttags` (que o `RiverTags` chama 7×) não vem no river nem no kwm:
  é `gnuunixchad/river-shifttags`, C puro, portado aqui
  (`Makefile.river-shifttags`). O Makefile upstream não serve no FreeBSD (GNU
  pattern rules que o bmake rejeita, `-lrt` inexistente, `-lpixman-1` com zero
  usos no fonte).

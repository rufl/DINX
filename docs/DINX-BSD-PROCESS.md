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

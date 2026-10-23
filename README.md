<p align="center">
  <img src="distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx.svg" alt="Logotipo DINX" width="180">
</p>

<h1 align="center">DINX</h1>

<p align="center">
  <strong>Uma versão alpha prática do Artix Linux com dinit, desktop Wayland rápido e um caminho claro para gaming.</strong><br>
  Pouco footprint. Limites explícitos. Nenhuma mudança silenciosa no sistema.
</p>

<p align="center">
  <a href="README.md">Português (Brasil)</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8"><img alt="Release alpha mais recente" src="https://img.shields.io/github/v/release/rufl/DINX?include_prereleases&amp;sort=semver&amp;label=alpha&amp;color=38bdf8"></a>
  <a href="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml"><img alt="Status da validação P0" src="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml/badge.svg?branch=main"></a>
  <img alt="Estágio: beta de jogos P5" src="https://img.shields.io/badge/estágio-P5%20beta%20de%20jogos-f59e0b">
  <a href="LICENSE"><img alt="Licença Apache 2.0" src="https://img.shields.io/github/license/rufl/DINX?color=22c55e"></a>
</p>

> **Software alpha público.** Faça backup antes de testar. O instalador é experimental; hardware físico e as afirmações de gaming ainda têm limites claros.

## Comece aqui

| Se você quer… | Vá para |
|---|---|
| Baixar a imagem atual | [DINX v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8) |
| Instalar e inicializar com segurança | [Guia de instalação](docs/pt-BR/install.md) |
| Ver o que foi realmente qualificado | [Evidência P0](docs/pt-BR/p0-build.md) |
| Entender os limites do alpha | [Roadmap](docs/pt-BR/roadmap.md) e [compatibilidade](docs/pt-BR/compatibility.md) |
| Ver as mudanças da release | [Changelog](CHANGELOG.pt-BR.md) |
| Ler em inglês | [README em inglês](README.en.md) |

## Alpha 8 em um minuto

A [v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8) é o snapshot público atual. A execução de release [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), no commit `eea66ac`, passou os contratos estáticos, builds de pacotes Artix, criação e boot da ISO, validação do payload gráfico, smokes do Calamares em BIOS/UEFI/Btrfs, instalação persistente e TTY de recuperação em discos descartáveis BIOS/UEFI, verificação de metadados, assinatura persistente de pacotes, atestação e publicação.

| Item | Evidência |
|---|---|
| ISO | 2.803.349.504 bytes, com partes e checksum SHA-512 publicados |
| Repositório DINX | Snapshot assinado `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9` |
| Imagem | Artix Linux x86_64 com dinit |
| Estágio | P5 — Beta de jogos; P4 DinitUI qualificada para o gate alpha |

## O que é a DINX

A DINX é uma distribuição Artix focada em uma sessão desktop enxuta, legível e controlável:

- **Artix Linux + dinit** como base;
- **Wayland, labwc e Noctalia Shell** para a sessão gráfica;
- **PipeWire, D-Bus, portais, polkit e aceleração GPU** no payload da ISO;
- **DinitUI e DINXPanel** para serviços, perfis Normal/Lite/Gaming, atalhos de sistema, drivers e kernels Artix;
- **sessão DINX Gaming** separada, com Gamescope/Steam e payload gráfico de 32 bits;
- **Calamares, GParted, File Roller, Pori e Phyto** para instalação, particionamento, arquivos compactados, armazenamento e gerenciamento de arquivos; **wdisplays** e **shikane** cuidam da configuração de displays Wayland, e o kernel `ntfs3` cobre leitura e escrita NTFS;

O monitor de sistema **Dome** é opcional e entregue pelo grupo de pacotes Seafoam assinado, não pela ISO base. Suas telas de recursos/processos continuam úteis no dinit; seu provedor opcional de serviços systemd fica indisponível por design.

O mesmo grupo Seafoam opcional fornece o **Seafoam Settings**, um launcher nativo compacto em Zig/GTK4 para pontos de entrada de display, labwc, DinitUI, DINXPanel, Qt e Dome, além do **ZLS 0.16.0** para suporte de language server Zig no Nocted. Nenhum dos dois pacotes faz parte da ISO base; instale-os pelo repositório opcional assinado quando necessário.

Noctty, Nocted e os demais contratos de integração ficam versionados junto com a distribuição quando isso reduz risco e mantém a ISO reproduzível.
Aqueous e Pearl estão planejados como uma opção alternativa de compositor/shell em Zig, não como uma sessão incluída na Alpha 8. A sessão upstream atualmente depende de `uwsm` e unidades systemd de usuário; a DINX não exporá uma entrada de sessão até que um pacote nativo de dinit seja qualificado. Labwc + Noctalia continua sendo a sessão suportada, sem fallback silencioso para outro compositor.

Execute `dinx-doctor` para obter um snapshot somente leitura da sessão atual, do limite do dinit, dos caminhos de armazenamento/display e dos pacotes DINX instalados. Defina `DINX_DOCTOR_QUERY_DINIT=1` somente se também quiser consultar o socket do dinit de usuário; o comando nunca inicia, para, monta ou atualiza nada.


## Instalação rápida

1. Baixe a release [v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8). A ISO excede 2 GiB, então use todas as partes `*.iso.part-*`, o manifesto e o checksum.
2. Concatene e verifique antes de gravar:

   ```bash
   cat dinx-0.1.0-alpha.8-x86_64.iso.part-* > dinx-0.1.0-alpha.8-x86_64.iso
   sha512sum -c dinx-0.1.0-alpha.8-x86_64.iso.sha512
   ```

3. Grave a ISO verificada no USB inteiro, inicialize em UEFI e selecione `Labwc (DINX)` no greeter. O login live de teste é `dinx` / `dinx`.

Leia o [guia de instalação](docs/pt-BR/install.md) antes de particionar. Ele cobre Windows side-by-side, recuperação por TTY, verificação de dispositivo e os limites do instalador.

## O que já foi provado

| Qualificado no release | Ainda não alegado |
|---|---|
| Boot x86_64 em QEMU e payload gráfico esperado | Matriz de hardware físico |
| Transação de particionamento Calamares BIOS/UEFI/Btrfs | Sessão DRM real e seleção gaming pelo greeter |
| Instalação descartável BIOS/UEFI, primeiro boot dinit e TTY de recuperação | Steam autenticado, jogo comercial, controle e áudio PipeWire |
| Checksums, metadados, atestação e repositório de pacotes DINX assinado | Suspensão/retomada, recuperação de GPU e upgrades/rollback da ISO instalada |

## Documentação

- [Arquitetura](docs/pt-BR/architecture.md)
- [Guia de instalação](docs/pt-BR/install.md)
- [Compatibilidade com Noctalia](docs/pt-BR/compatibility.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
- [Roadmap](docs/pt-BR/roadmap.md)
- [Processo de release](docs/pt-BR/release.md)
- [Qualificação de hardware](docs/pt-BR/alpha7-qualification.md) — o utilitário mantém o nome `dinx-alpha7-hardware-report` por compatibilidade
- [Fundação da ISO](distro/iso/README.pt-BR.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Changelog](CHANGELOG.pt-BR.md)
- [Licença Apache 2.0](LICENSE)

## Código e contratos

A DINX é um monorepo público para manter juntos os contratos do desktop, pacotes, perfil da ISO, testes de qualificação e ferramentas de release. Os aplicativos devem integrar-se profundamente à plataforma, mas continuar utilizáveis em outros sistemas Linux quando seus requisitos estiverem disponíveis.

- [Código no GitHub](https://github.com/rufl/DINX)
- [Issues](https://github.com/rufl/DINX/issues)
- [Releases](https://github.com/rufl/DINX/releases)
- [Workflow de validação](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml)

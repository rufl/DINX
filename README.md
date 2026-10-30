<h1 align="center">
  <img src="distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-linux-logo.svg" alt="Logotipo DINX Linux" width="420">
</h1>

<p align="center">
  <strong>Artix Linux + dinit, com um desktop Wayland enxuto e explícito.</strong><br>
  Um alpha público para testar a base, os limites e o caminho de instalação — sem esconder o que ainda falta.
</p>

<p align="center">
  <a href="README.md">Português (Brasil)</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10"><img alt="Release alpha mais recente" src="https://img.shields.io/github/v/release/rufl/DINX?include_prereleases&amp;sort=semver&amp;label=alpha&amp;color=38bdf8"></a>
  <a href="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml"><img alt="Status da validação P0" src="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml/badge.svg?branch=main"></a>
  <img alt="Próximo marco: Beta 0.1 do sistema (planejado)" src="https://img.shields.io/badge/pr%C3%B3ximo%20marco-Beta%200.1%20do%20sistema-f59e0b">
  <a href="LICENSE"><img alt="Licença Apache 2.0" src="https://img.shields.io/github/license/rufl/DINX?color=22c55e"></a>
</p>

> **Software alpha público.** Faça backup antes de testar. A ISO live e o instalador são experimentais; um boot bem-sucedido não é uma qualificação de hardware.

## Comece aqui

| Você quer… | Vá para |
|---|---|
| Baixar a imagem publicada | [DINX v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10) |
| Verificar e instalar a ISO | [Guia de instalação](docs/pt-BR/install.md) |
| Ver o que o CI realmente provou | [Status do build P0](docs/pt-BR/p0-build.md) |
| Entender compatibilidade e limites | [Compatibilidade](docs/pt-BR/compatibility.md) · [Roadmap](docs/pt-BR/roadmap.md) |
| Ler o processo de release | [Release alpha](docs/pt-BR/release.md) |
| Consultar a licença e o REUSE | [Licenciamento](docs/pt-BR/licensing.md) |
| Ler em inglês | [README em inglês](README.en.md) |

## Em resumo

DINX é uma distribuição Artix para uma sessão gráfica pequena, legível e controlável:

- **Artix Linux + dinit** como base, sem trocar o init por systemd;
- **Aqueous + Pearl** como a única sessão do usuário, iniciada diretamente sobre dinit; o **Pearl Greeter** é a interface de login do greetd e é hospedado pelo Aqueous sem systemd ou UWSM;
- **DinitUI** e **DINXPanel** para perfis de serviços, hardware, drivers e kernels;
- **Calamares** para a instalação experimental, **GParted** para particionamento separado e **Pori** para discos e montagens persistentes via dinit;
- **Phyto** como gerenciador de arquivos padrão e **File Roller** para abrir, criar e extrair arquivos compactados;
- **wdisplays + Shikane** para configurar displays Wayland e reaplicar o layout entre sessões;
- o módulo de kernel **ntfs3** para leitura e escrita NTFS na ISO live e no sistema instalado;
- **Mesa/RADV e gráficos em VM:** novas saídas do Aqueous começam com dois workspaces. Render nodes acessíveis de QEMU `virtio_gpu`/virgl ou VirtualBox VMSVGA (`vmwgfx`) usam Mesa GLES2 com a build do Aqueous sem efeitos Vulkan; nodes ausentes/inacessíveis e adaptadores virtuais somente 2D usam Pixman/Cairo. A aceleração 3D também precisa estar habilitada no host; veja o [guia gráfico](docs/pt-BR/install.md).
- **DINX Gaming** mantém o launcher manual oculto. A ISO base não inclui Gamescope, Steam, GameMode, MangoHud, regras de dispositivos Steam nem bibliotecas gaming de 32 bits; o usuário pode optar por instalar o conjunto gaming após a instalação. A base mantém RADV/Vulkan de 64 bits; veja o [guia de instalação](docs/pt-BR/install.md).

`dinx-doctor` produz um relatório somente leitura da sessão, do dinit, dos caminhos de armazenamento/display e dos pacotes DINX. Defina `DINX_DOCTOR_QUERY_DINIT=1` somente quando também quiser consultar o socket do dinit do usuário. Ele não inicia serviços, monta dispositivos, executa transações de pacotes nem acessa a rede.

O software BC-250 não é instalado na ISO genérica. Os pacotes estão disponíveis no repositório DINX assinado; instale-os somente após confirmar o PCI `1002:13fe`.

## Seafoam e a sessão única na ISO base

**Dome**, **Seafoam Settings** e **ZLS 0.16.0** fazem parte da ISO base e do repositório DINX assinado. Dome oferece monitoramento de recursos/processos sem instalar ou exigir systemd; Seafoam Settings agrupa os pontos de entrada de display e sessão; ZLS fornece LSP para Zig no Dintor com a biblioteca padrão Zig correspondente e um shim de metadados compacto, sem exigir um compilador Zig completo na ISO. O Pearl 0.3.0, inclusive a fonte upstream usada pelo Dome, e a fonte Pearl 0.2.8 incorporada ao Phyto usam seu toolchain Zig 0.16.0 fixado; Pori, Aqueous e os demais pacotes Zig nativos da DINX fora dessa árvore upstream usam o Zig 0.17.0 verificado.

**Aqueous 1.0.5** e **Pearl 0.3.0** vêm na ISO base. `Aqueous + Pearl (DINX)` é a única sessão de usuário selecionável e a sessão inicial da live: a DINX inicia o Aqueous diretamente, executa os helpers supervisionados de Shikane/PolicyKit/idle e faz `exec` do Pearl sem `systemd`, `systemctl`, `uwsm` ou unidades de usuário. O login instalado/manual usa o **Pearl Greeter**, iniciado diretamente pelo greetd através da conta dedicada `pearl-greeter`; o Greeter força a mesma entrada Aqueous/Pearl e não expõe X11 nem UWSM. Se a sessão Aqueous/Pearl da live terminar, o greetd retorna ao Pearl Greeter em vez de trocar de sessão silenciosamente.

## Estado atual

| Item | Estado |
|---|---|
| Release publicado | `v0.1.0-alpha.10`, ISO direta de 1.862.772.736 bytes |
| Base | Artix Linux x86_64 com dinit |
| Próximo marco | Beta 0.1 do sistema: planejada, ainda não publicada e sem data |
| Qualificação gaming | P5 separada da beta do sistema; ainda não concluída |
| Validação da release publicada | [Workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746), commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e` |
| P0 da main após Alpha 10 | [Workflow 40894570770](https://github.com/rufl/DINX/actions/runs/40894570770), commit `bf773500965c843e014e3bc3ef8fea685e14b91b`, concluído com sucesso |

## Próximo marco: Beta 0.1 do sistema

A Beta 0.1 está planejada, ainda sem data de lançamento. O objetivo é qualificar a sessão Aqueous/Pearl sobre dinit e os caminhos de instalação, atualização e recuperação em uma matriz declarada de hardware físico. A publicação dependerá de testes de rede, áudio, GPU/display e suspensão, além de instalação e recuperação em discos de teste, atualização assinada e documentação dos limites.

O [limite por arquivo de release do GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) é **menor que 2 GiB** (`2.147.483.648` bytes); a DINX não tem uma meta menor de 1,8 bilhão de bytes. A Alpha 10, com 1.862.772.736 bytes, está dentro do limite. A ISO futura precisa continuar abaixo dele para ser publicada como arquivo direto. O P5 gaming segue separado: a Beta 0.1 não alegará suporte sem testes reais de DRM, Steam, controle e áudio. A sessão continua Aqueous/Pearl com dinit, sem systemd ou UWSM. [Critérios completos no roadmap](docs/pt-BR/roadmap.md).


## Instalação rápida

1. Baixe a ISO e o arquivo `.iso.sha512` da [release Alpha 10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10).
2. No mesmo diretório, verifique o arquivo:

   ```bash
   sha512sum -c dinx-0.1.0-alpha.10-x86_64.iso.sha512
   ```

3. Grave a ISO verificada no dispositivo USB inteiro — não em uma partição — e inicialize em UEFI.
4. A imagem Alpha 10 publicada abre diretamente em `Aqueous + Pearl (DINX)`; ela não solicita usuário ou senha. O login instalado e o autologin do Calamares continuam desativados.

Leia o [guia de instalação](docs/pt-BR/install.md) antes de tocar em qualquer disco. Windows Fast Startup e hibernação devem estar desativados antes de montar um volume NTFS compartilhado.

## Evidência e limites

| A qualificação atual cobre | Ainda não é alegado |
|---|---|
| Boot x86_64 e payload gráfico em QEMU | Matriz de hardware físico |
| Contratos de particionamento Calamares BIOS/UEFI/Btrfs | Secure Boot |
| Instalação descartável BIOS/UEFI, primeiro boot dinit e TTY de recuperação | Steam autenticado, jogo comercial, controle e áudio PipeWire |
| ISO compacta, checksums, metadados, atestação e repositório assinado | Suspensão/retomada, recuperação de GPU e upgrade/rollback da ISO instalada |

## Documentação

- [Arquitetura](docs/pt-BR/architecture.md)
- [Guia de instalação](docs/pt-BR/install.md)
- [Compatibilidade DINX](docs/pt-BR/compatibility.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
- [Roadmap](docs/pt-BR/roadmap.md)
- [Processo de release](docs/pt-BR/release.md)
- [Qualificação de hardware](docs/pt-BR/alpha7-qualification.md)
- [Fundação da ISO](distro/iso/README.pt-BR.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Licenciamento e REUSE](docs/pt-BR/licensing.md)
- [Changelog](CHANGELOG.pt-BR.md)

## Código, contratos e licença

Este repositório mantém juntos o perfil da ISO, os pacotes, as integrações do desktop, os checks de qualificação e o tooling de release. As entradas específicas da DINX são licenciadas sob Apache-2.0. O pacote DINX `deetty` fornece os aplicativos Deetty/Dintor a partir de um archive upstream separado sob MIT, cuja URL e identidade NOCTTY permanecem inalteradas; a cobertura está declarada em `REUSE.toml` e os textos estão em `LICENSES/`.

- [Código no GitHub](https://github.com/rufl/DINX)
- [Issues](https://github.com/rufl/DINX/issues)
- [Releases](https://github.com/rufl/DINX/releases)
- [Workflow de validação](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml)

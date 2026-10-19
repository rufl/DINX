# DINX

[Português (Brasil)](README.md) · [English](README.en.md)

Distro Linux alpha pública, Spin Customizada do Artix - pouco footprint, máximo desempenho.

O alvo inicial da plataforma é **x86_64**, baseada no **Artix Linux com dinit**, com um desktop Wayland usando **MangoWC** e **Noctalia Shell**.

> Software alpha. Não instale em sistemas que contenham dados que você não consiga restaurar.

## Família de produtos

- **DINX** — imagem do sistema operacional, pacotes, contratos de integração e ferramentas de release.
- **Noctty** — emulador de terminal com interface própria em Zig e um núcleo comprovado de emulação de terminal.
- **Nocted** — editor de código leve com suporte a sintaxe, LSP e integração com Git.
- **DINXPanel** — centro de controle inspirado no YaST para atalhos dos painéis do sistema, detecção/instalação fixa de drivers, upgrades Shelly/Topgrade, descoberta opcional de firmware e instalação segura de kernels Artix.
- **BC250 Control Center** — interface upstream para telemetria, ajustes e recuperação da BC-250, empacotada para a sessão Artix/dinit da DINX.
- **Dinx Theme** — tokens de design compartilhados e contratos de integração de aplicativos, versionados.

Os aplicativos devem integrar-se profundamente à DINX, mas continuar utilizáveis em outros sistemas Linux sempre que os requisitos da plataforma estiverem disponíveis.

## Repositórios dos aplicativos

- [Noctty](https://github.com/rufl/noctty) — terminal privado alpha.
- [Nocted](https://github.com/rufl/nocted) — editor de código privado alpha.
- O DinitUI é desenvolvido atualmente em `distro/packages/dinitui` para manter seu contrato de Dinit/ISO versionado com a DINX; pode migrar para um repositório dedicado depois que o limite do pacote estabilizar.

Os aplicativos têm repositórios próprios para ciclos de desenvolvimento independentes, mas continuam ligados aos contratos compartilhados e ao release da DINX.


## Arquitetura inicial

- Artix Linux + dinit
- Wayland + MangoWC + Noctalia Shell
- PipeWire, D-Bus, portais, polkit e aceleração de GPU
- Zig como linguagem primária dos aplicativos, usando bibliotecas e bindings maduros quando reduzirem o risco
- Contratos versionados para temas, caminhos XDG, metadados `.desktop`, invocação por `$TERMINAL` e IPC opcional do Noctalia
- Sessão de jogos separada, baseada em Gamescope e Steam; ela não deve depender de uma sessão completa do Noctalia em segundo plano

## Política de entrega

O monorepo é público no GitHub durante a alpha. ISOs e pacotes alpha continuam sendo artefatos de pré-release até que cada release seja deliberadamente publicado. Cada artefato deve conter sua versão exata, o commit de origem, checksum e limitações conhecidas.

O projeto usa um monorepo para manter contratos compartilhados e ferramentas de release versionados junto com os aplicativos:

```text
docs/
shared/
apps/noctty/
apps/nocted/
distro/
  packages/dinitui/
  packages/dinxpanel/
tests/
scripts/
```

## Marcos

1. **P0 — Fundação:** base Artix+dinit reproduzível, ISO inicializável, login gráfico, rede, áudio, aceleração de GPU e TTY de recuperação.
2. **P1 — Alpha pública:** documentação de instalação, checksums, assinatura de pacotes, problemas conhecidos e terminal de fallback.
3. **P2 — Noctty:** ciclo de vida confiável de PTY, semântica de terminal, renderização, Unicode, scrollback, seleção e compatibilidade com TUIs interativas.
4. **P3 — Nocted:** edição confiável, destaque de sintaxe, busca, navegação de projetos, LSP e status/diffs do Git.
5. **P4 — DinitUI + DINXPanel:** gerenciamento seguro de serviços dinit, perfis customizáveis Normal/Lite/Gaming, atalhos dos painéis do sistema, fluxo fixo de GPU e instalação segura de kernels Artix.
6. **P5 — Beta de jogos:** sessão Gamescope/Steam, validação de controles e gráficos, suspensão/retomada e testes de atualização.

A alpha não exige que todos os aplicativos próprios estejam completos. Um sistema inicializável conhecido como funcional tem prioridade sobre branding ou recursos avançados de interface.

## Fase atual

**P5 — Beta de jogos (em andamento).** A P4 DinitUI está qualificada end-to-end para release: testes Zig/build ReleaseSafe, payload do pacote Arch, contratos estáticos, a qualificação com daemon Dinit de usuário temporário real/smoke GTK e o gate P0 da ISO passaram. A execução [39244756515](https://github.com/rufl/DINX/actions/runs/39244756515), no commit `49c8a74`, compilou e inicializou a ISO, verificou seu payload gráfico, passou os smokes de instalação persistente/primeiro boot/TTY de recuperação em discos BIOS e UEFI descartáveis e o smoke transacional de particionamento BIOS/UEFI/Btrfs do Calamares, atestou a ISO/checksum e publicou o artefato. A P5 mantém abertos os limites de Steam/jogo/controle/áudio autenticados, sessão DRM real, hardware físico, suspensão/retomada e atualização.

## Documentação

- [Arquitetura](docs/pt-BR/architecture.md)
- [Compatibilidade com Noctalia](docs/pt-BR/compatibility.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Guia de instalação fácil](docs/pt-BR/install.md)
- [Política de segurança](SECURITY.pt-BR.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
- [Roadmap](docs/pt-BR/roadmap.md)
- [Processo de release alpha](docs/pt-BR/release.md)
- [Qualificação da Alpha 7](docs/pt-BR/alpha7-qualification.md)
- [Build da ISO](distro/iso/README.pt-BR.md)
- [Licença](LICENSE)

Versões originais em inglês:

- [Architecture](docs/architecture.md)
- [Noctalia compatibility](docs/compatibility.md)
- [Security model](docs/security-model.md)
- [P0 build status](docs/p0-build.md)
- [ISO foundation](distro/iso/README.md)
- [Alpha 7 qualification](docs/alpha7-qualification.md)

## Status atual

A release pública [v0.1.0-alpha.6](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.6), publicada no commit `f7bf044`, é o snapshot público atual de validação. O gate P0 mais recente é a execução [39244756515](https://github.com/rufl/DINX/actions/runs/39244756515), no commit `49c8a74`; ela passou os builds de pacotes Artix, a criação da ISO, o boot no QEMU, a validação do payload gráfico, o smoke transacional de particionamento BIOS/UEFI/Btrfs do Calamares, os smokes da instalação persistente/primeiro boot/TTY de recuperação em discos BIOS e UEFI descartáveis, a atestação, a verificação dos metadados de build e o upload do artefato. O artefato temporário é `dinx-foundation-iso-49c8a74735a5c55eb7078f15c6c0825ceaf326f3`, com 2.704.049.911 bytes e digest `sha256:bc226ab7067918c9f8612f1f4f6b4ef96cb70618585877e07906932de39abe67`. A P4 DinitUI está encerrada para o gate alpha; a imagem continua sendo uma sessão live de validação, não uma instalação de hardware suportada.

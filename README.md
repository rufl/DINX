# DINX

[Português (Brasil)](README.md) · [English](README.en.md)

Distro Linux alpha pública, Spin Customizada do Artix - pouco footprint, máximo desempenho.

O alvo inicial da plataforma é **x86_64**, baseada no **Artix Linux com dinit**, com um desktop Wayland usando **MangoWC** e **Noctalia Shell**.

> Software alpha. Não instale em sistemas que contenham dados que você não consiga restaurar.

## Família de produtos

- **DINX** — imagem do sistema operacional, pacotes, contratos de integração e ferramentas de release.
- **Noctty** — emulador de terminal com interface própria em Zig e um núcleo comprovado de emulação de terminal.
- **Nocted** — editor de código leve com suporte a sintaxe, LSP e integração com Git.
- **DinitUI** — frontend nativo em GTK4/libadwaita focado em serviços, unidades e ações do daemon dinit.
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
tests/
scripts/
```

## Marcos

1. **P0 — Fundação:** base Artix+dinit reproduzível, ISO inicializável, login gráfico, rede, áudio, aceleração de GPU e TTY de recuperação.
2. **P1 — Alpha pública:** documentação de instalação, checksums, assinatura de pacotes, problemas conhecidos e terminal de fallback.
3. **P2 — Noctty:** ciclo de vida confiável de PTY, semântica de terminal, renderização, Unicode, scrollback, seleção e compatibilidade com TUIs interativas.
4. **P3 — Nocted:** edição confiável, destaque de sintaxe, busca, navegação de projetos, LSP e status/diffs do Git.
5. **P4 — DinitUI:** gerenciamento seguro de serviços dinit e visualizações úteis do estado do sistema.
6. **P5 — Beta de jogos:** sessão Gamescope/Steam, validação de controles e gráficos, suspensão/retomada e testes de atualização.

A alpha não exige que todos os aplicativos próprios estejam completos. Um sistema inicializável conhecido como funcional tem prioridade sobre branding ou recursos avançados de interface.

## Fase atual

**P5 — Beta de jogos (em andamento).** A P4 DinitUI agora está qualificada end-to-end para release: testes Zig/build ReleaseSafe, payload do pacote Arch, contratos estáticos, a qualificação com daemon Dinit de usuário temporário real/smoke GTK e o gate P0 da ISO passaram. A execução [38989297207](https://github.com/rufl/DINX/actions/runs/38989297207), no commit `86edd35`, compilou e inicializou a ISO, verificou seu payload gráfico, concluiu o smoke de instalação persistente/TTY de recuperação em disco descartável, atestou a ISO/checksum e publicou o artefato. A P5 tem contrato de sessão Gamescope/Steam standalone, entradas de gráficos de 32 bits no perfil, fixtures do launcher e qualificação real headless de launch/exit do Gamescope. Steam/jogo/controle/áudio autenticados, seleção da sessão gaming no greeter, sessão DRM real, hardware físico e suspensão/retomada continuam gates não alegados. A P1 foi encerrada com o release público `v0.1.0-alpha.5`; P2 e P3 estão encerradas pela evidência registrada do workflow.

## Documentação

- [Arquitetura](docs/pt-BR/architecture.md)
- [Compatibilidade com Noctalia](docs/pt-BR/compatibility.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Guia de instalação fácil](docs/pt-BR/install.md)
- [Política de segurança](SECURITY.pt-BR.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
- [Roadmap](docs/pt-BR/roadmap.md)
- [Processo de release alpha](docs/pt-BR/release.md)
- [Build da ISO](distro/iso/README.pt-BR.md)
- [Licença](LICENSE)

Versões originais em inglês:

- [Architecture](docs/architecture.md)
- [Noctalia compatibility](docs/compatibility.md)
- [Security model](docs/security-model.md)
- [P0 build status](docs/p0-build.md)
- [ISO foundation](distro/iso/README.md)

## Status atual

A release pública [v0.1.0-alpha.5](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.5), publicada no commit `1953457`, continua sendo o snapshot público de validação. O gate P0 mais recente é a execução [38989297207](https://github.com/rufl/DINX/actions/runs/38989297207), no commit `86edd35`; ela passou os builds de pacotes Artix, a criação da ISO, o boot no QEMU, a validação do payload gráfico, o smoke da instalação persistente/TTY de recuperação, a atestação e o upload do artefato. O artefato temporário é `dinx-foundation-iso-86edd3562a0b734a3e4fcf44e34638573145af3a`, com 2.710.227.069 bytes e digest `sha256:343e10f0aae3e55d1cfd643513cf13793db5ef4fd31f4ca852fab6de63f7ae35`. A P4 DinitUI está encerrada para o gate alpha; a imagem continua sendo uma sessão live de validação com instalador experimental, enquanto instalação em hardware, saúde completa dos serviços, UEFI, atualizações, rollback e assinatura do repositório pacman continuam gates posteriores.

# DINX

[Português (Brasil)](README.md) · [English](README.en.md)

DINX é uma plataforma Linux alpha pública para jogos e desenvolvimento.

O alvo inicial da plataforma é **x86_64**, baseada no **Artix Linux com dinit**, com um desktop Wayland usando **MangoWC** e **Noctalia Shell**.

> Software alpha. Não instale em sistemas que contenham dados que você não consiga restaurar.

## Família de produtos

- **DINX** — imagem do sistema operacional, pacotes, contratos de integração e ferramentas de release.
- **Noctty** — emulador de terminal com interface própria em Zig e um núcleo comprovado de emulação de terminal.
- **Nocted** — editor de código leve com suporte a sintaxe, LSP e integração com Git.
- **Dinx Control** — gerenciamento gráfico de serviços e do sistema usando dinit.
- **Dinx Theme** — tokens de design compartilhados e contratos de integração de aplicativos, versionados.

Os aplicativos devem integrar-se profundamente à DINX, mas continuar utilizáveis em outros sistemas Linux sempre que os requisitos da plataforma estiverem disponíveis.

## Repositórios dos aplicativos

- [Noctty](https://github.com/rufl/noctty) — terminal privado alpha.
- [Nocted](https://github.com/rufl/nocted) — editor de código privado alpha.

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
apps/dinx-control/
distro/
tests/
scripts/
```

## Marcos

1. **P0 — Fundação:** base Artix+dinit reproduzível, ISO inicializável, login gráfico, rede, áudio, aceleração de GPU e TTY de recuperação.
2. **P1 — Alpha pública:** documentação de instalação, checksums, assinatura de pacotes, problemas conhecidos e terminal de fallback.
3. **P2 — Noctty:** ciclo de vida confiável de PTY, semântica de terminal, renderização, Unicode, scrollback, seleção e compatibilidade com TUIs interativas.
4. **P3 — Nocted:** edição confiável, destaque de sintaxe, busca, navegação de projetos, LSP e status/diffs do Git.
5. **P4 — Dinx Control:** gerenciamento seguro de serviços dinit e visualizações úteis do estado do sistema.
6. **P5 — Beta de jogos:** sessão Gamescope/Steam, validação de controles e gráficos, suspensão/retomada e testes de atualização.

A alpha não exige que todos os aplicativos próprios estejam completos. Um sistema inicializável conhecido como funcional tem prioridade sobre branding ou recursos avançados de interface.

## Documentação

- [Arquitetura](docs/pt-BR/architecture.md)
- [Compatibilidade com Noctalia](docs/pt-BR/compatibility.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Guia de instalação fácil](docs/pt-BR/install.md)
- [Política de segurança](SECURITY.pt-BR.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
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

O P0 agora inclui builds fixados do wlroots/MangoWM/Scenefx, o workflow Artix da ISO, validação de payload/checksum, smoke de boot no QEMU e login gráfico automatizado em uma VM. O workflow de release agora publica pré-releases com checksums da ISO, evidências visuais Linux e um pacote launcher Windows para QEMU e qualificação no DDJARIN via ZTASH. A imagem continua sendo uma sessão live de validação; instalação persistente, saúde completa dos serviços e verificação da TTY de recuperação continuam gates de release.

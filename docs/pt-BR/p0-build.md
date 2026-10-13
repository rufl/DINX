# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `scripts/smoke-iso.sh` — probe de boot em QEMU;
- `.github/workflows/p0-iso.yml` — build remoto em container Artix;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.

## Build remoto

O workflow `P0 ISO foundation` é executado manualmente ou quando arquivos do perfil/build mudam. Ele:

1. instala QEMU e ferramentas de inspeção de ISO no runner Ubuntu;
2. executa Artix em um container privilegiado;
3. instala `artools`, `iso-profiles` e as dependências de build fixadas do MangoWM/Scenefx;
4. compila MangoWM e Scenefx e os serve em um repositório pacman local temporário;
5. executa o probe de pré-requisitos;
6. constrói a ISO com `buildiso`;
7. valida o payload SquashFS do root;
8. gera checksum SHA-512;
9. mantém QEMU executando por uma janela de boot configurável e captura sua superfície VGA;
10. publica a ISO, o checksum e a captura PPM como artefato privado temporário do workflow.

A verificação de payload prova que MangoWM, Scenefx, Noctalia, ReGreet, greetd, a sessão Mango e os arquivos de serviço dinit chegaram à ISO. O smoke test do QEMU ainda prova somente a aceitação do processo/caminho de boot; não prova login gráfico, rede ou áudio dentro do guest.

A execução também captura a superfície VGA do QEMU como artefato PPM pelo monitor. Essa captura é evidência visual para inspeção; ela não prova automaticamente a interação com o greeter, a saúde da sessão do usuário, a rede ou o áudio.

Para uma captura gráfica local, defina `DINX_QEMU_SCREENSHOT` e, opcionalmente, `DINX_QEMU_SCREENSHOT_DELAY` antes de executar `scripts/smoke-iso.sh`; o workflow usa atraso de 45 segundos e publica o PPM junto com o artefato da ISO.


## Execução bem-sucedida observada

A execução [38448333502](https://github.com/rufl/dinx-alpha/actions/runs/38448333502), no commit `8f5b99d`, concluiu todas as etapas do workflow em 8m05s:

- artefato ISO: `artix-dinx-dinit-20261013-x86_64.iso`;
- tamanho: 1.409.947.648 bytes;
- SHA-512: `9407f2da3d2bc37bd973368a7206df3b27f67a23068ee26b88529132ee03285a40db5fb108375874e7e26ece35b4602f86c153f225c27a997ad1a5872a09bc9f`;
- janela de smoke no QEMU: 60 segundos, aprovada;
- artefato: `dinx-foundation-iso-8f5b99dfcfc1548618d448a269d87a5f08809071`, mantido privado por 7 dias.

O log serial gerado ficou vazio. Isso registra somente a aceitação do processo/caminho de boot pelo QEMU; não é evidência de login gráfico nem da saúde dos serviços dentro do guest.

## Host de desenvolvimento observado

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso` e `zig` estão disponíveis. `buildiso`, `mkarchiso` e `qemu-system-x86_64` não estão instalados. Bibliotecas de usuário do QEMU e `/dev/kvm` estão presentes, mas isso não é suficiente para executar o smoke test local.

Portanto, o build P0 deve ser executado no workflow remoto até que as dependências locais sejam disponibilizadas.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso no container Artix.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. A verificação gráfica encontra o compositor, shell, greeter, sessão e arquivos dinit.
5. O checksum SHA-512 é gerado junto da ISO.
6. `scripts/smoke-iso.sh` mantém o QEMU ativo durante a janela de boot.
7. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
8. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
9. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.

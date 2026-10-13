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

1. instala QEMU no runner Ubuntu;
2. executa Artix em um container privilegiado;
3. instala `artools` e `iso-profiles`;
4. executa o probe de pré-requisitos;
5. constrói a ISO com `buildiso`;
6. gera checksum SHA-512;
7. mantém QEMU executando por uma janela de boot configurável;
8. publica a ISO e o checksum como artefato privado temporário do workflow.

O smoke test prova que a imagem e o caminho de boot permanecem aceitos pelo QEMU durante a janela definida. Ele ainda não prova login gráfico, rede ou áudio dentro do guest; essas verificações entram depois que a imagem foundation tiver um método de teste de guest observável.

## Host de desenvolvimento observado

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso` e `zig` estão disponíveis. `buildiso`, `mkarchiso` e `qemu-system-x86_64` não estão instalados. Bibliotecas de usuário do QEMU e `/dev/kvm` estão presentes, mas isso não é suficiente para executar o smoke test local.

Portanto, o build P0 deve ser executado no workflow remoto até que as dependências locais sejam disponibilizadas.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso no container Artix.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. O checksum SHA-512 é gerado junto da ISO.
5. `scripts/smoke-iso.sh` mantém o QEMU ativo durante a janela de boot.
6. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
7. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
8. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.

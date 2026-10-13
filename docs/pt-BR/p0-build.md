# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.

## Host de desenvolvimento observado

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso` e `zig` estão disponíveis. `buildiso`, `mkarchiso` e `qemu-system-x86_64` não estão instalados. Bibliotecas de usuário do QEMU e `/dev/kvm` estão presentes, mas isso não é suficiente para executar o smoke test da ISO.

Portanto, nenhum resultado de build ou boot da ISO é declarado ainda. A próxima ação de ambiente é instalar ou disponibilizar `artools`/`iso-profiles` atuais do Artix e um emulador de sistema QEMU; depois, executar o probe de pré-requisitos e o wrapper de build.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
5. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
6. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.

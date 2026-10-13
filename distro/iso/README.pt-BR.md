# Fundação da ISO DINX

[Português (Brasil)](README.pt-BR.md) · [English](README.md)

Este diretório contém o primeiro perfil Artix `artools` da DINX e os pontos de entrada locais do build.

## Toolchain

O perfil usa o fluxo `buildiso` do Artix, não o `mkarchiso` genérico. O builder deve fornecer:

- `pacman`;
- `artools` atual do Artix com `buildiso` e sua dependência `yq`;
- `xorriso`, `grub-mkimage`, `mksquashfs` e `mkinitcpio`;
- suporte a dispositivos loop;
- privilégios root para operações de chroot e mount.

Execute o probe de pré-requisitos a partir da raiz do repositório:

```bash
scripts/check-iso-host.sh
```

Construa o perfil de fundação:

```bash
scripts/build-iso.sh
```

Opções adicionais do `buildiso` são repassadas sem alteração. Por exemplo, para consultar as configurações sem executar o build:

```bash
scripts/build-iso.sh -q
```

O diretório de saída padrão é `dist/iso`; ele pode ser alterado com `DINX_ISO_OUTPUT`. O cache de chroots padrão é `/var/lib/artools/buildiso`; altere-o com `DINX_ISO_CHROOTS` quando o builder usar outro volume persistente.

## Limite do perfil

`iso-profiles/dinx/profile.yaml` é o perfil de fundação. Ele seleciona os pacotes complementares de serviços dinit e os componentes mínimos de Wayland, áudio e rede necessários para a primeira validação de boot. Noctalia, MangoWC, Noctty e Nocted não são substituídos silenciosamente por aplicativos sem relação; eles só entram no perfil depois que suas fontes e licenças forem verificadas.

O perfil usa o manifesto comum de pacotes do Artix fornecido pelo pacote `iso-profiles` instalado e adiciona localmente as entradas específicas da DINX. A exportação de `WORKSPACE_DIR` em `scripts/build-iso.sh` torna determinística a seleção do perfil.

## Validação do build

Um build de imagem bem-sucedido não é o critério de release. A ISO resultante ainda exige:

1. geração de checksum;
2. verificação de boot em VM ou hardware de teste;
3. verificação da TTY de recuperação;
4. verificações de rede, áudio, D-Bus, portal e gráficos;
5. relatório de instalação/atualização antes de ser rotulada como alpha.

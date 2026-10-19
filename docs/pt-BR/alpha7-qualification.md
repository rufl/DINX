# Qualificação da DINX Alpha 7

A Alpha 7 é o próximo snapshot de validação da DINX OS depois da
`v0.1.0-alpha.6`. Este documento separa o que o repositório consegue provar do
que exige teste manual depois da geração da ISO.

## Gate de build

O commit da tag deve passar pelo workflow P0 e produzir ISO, checksum,
metadados de build, atestações, evidências QEMU e assets de release novos. Os
contratos cobrem:

- payload SquashFS e orçamento de startup da ISO;
- boot QEMU e captura gráfica;
- instalação descartável BIOS e UEFI;
- TTY de recuperação e primeiro boot;
- transação Btrfs com subvolumes `@` e `@home` preexistentes;
- layouts Windows side-by-side com NTFS e manual;
- checks de pacotes, tema, DinitUI, DINXPanel, gaming, BC250 e aplicativos
  first-party.

## Matriz manual de três máquinas

Use a mesma ISO e registre máquina, modo de firmware, GPU, kernel e caminho do
relatório para cada alvo.

### Desktop

- inicializar a sessão live e selecionar a sessão DINX normal no ReGreet;
- verificar Wayland, MangoWC, Noctalia, áudio, rede e aceleração GPU;
- bloquear com `Super+L`;
- verificar bloqueio após 600 segundos de idle;
- suspender, retomar, desbloquear e confirmar que a sessão continua utilizável;
- testar brilho físico;
- selecionar `DINX Gaming`, iniciar Steam, abrir e fechar um jogo instalado;
- testar controle e áudio PipeWire do jogo;
- executar `dinx-alpha7-hardware-report` antes e depois do gaming.

### Laptop

Repetir a matriz do desktop e acrescentar:

- estado de bateria e carregamento;
- fechamento/abertura da tampa;
- brilho para baixo/cima em toda a faixa suportada;
- suspend/resume em bateria e na tomada;
- Wi-Fi, controle Bluetooth e roteamento de áudio depois do resume.

### BC-250

Repetir a matriz do desktop e acrescentar:

- detecção `1002:13fe` com `lspci -nn`;
- status do governor Cyan Skillfish e fallback seguro em hardware não-BC250;
- diagnósticos RADV/Vulkan;
- abertura da GUI e da CLI do BC250 Control Center;
- telemetria, recuperação e comportamento da GPU após suspend/resume;
- uma sessão gaming com observações de frame pacing, temperatura e energia.

## Relatório de hardware

A ISO inclui um utilitário somente de leitura:

```bash
dinx-alpha7-hardware-report
```

Os relatórios vão por padrão para `$XDG_STATE_HOME/dinx/alpha7/` ou
`~/.local/state/dinx/alpha7/`. Use `DINX_ALPHA7_REPORT_DIR` para escolher outro
diretório local. O utilitário não instala pacotes, altera perfis, modifica
configurações da GPU nem acessa a rede.

## Limite da evidência

CI e QEMU não provam posse real do DRM, Steam autenticado, launch de jogo
comercial, controle, áudio PipeWire do jogo, suspend/resume, brilho físico,
recuperação da GPU, firmware ou saúde de hardware em longo prazo. Essas
afirmações continuam abertas até a matriz manual das três máquinas passar.

O gaming P5 continua sendo um gate separado de beta. A Alpha 7 pode ser lançada
como alpha do sistema sem alegar que o critério de saída do beta gaming passou.

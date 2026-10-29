# Qualificação de hardware da DINX (contrato do relatório Alpha 7)

Os nomes do utilitário e das variáveis da Alpha 7 permanecem por compatibilidade.
Esta matriz é o limite de hardware manual da release atual `v0.1.0-alpha.10`;
ela separa o que o repositório prova do que exige teste manual após a geração da ISO.

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
- qualificação real do daemon de usuário e GTK do DinitUI;
- smoke limitado de inicialização do Calamares com a configuração enviada, além dos smokes transacionais;

## Checklist do operador para o sistema instalado

Execute esta checklist contra a mesma ISO e registre a tag da release, o nome
do metadata de build, o papel da máquina, o modo de firmware e a GPU antes de
marcar um resultado como `pass`.

1. Verifique o SHA-512 da ISO e o metadata do build; depois inicialize a sessão
   DINX normal.
2. Após uma instalação pelo Calamares, confirme que o primeiro boot chega ao Pearl Greeter e depois à sessão Aqueous/Pearl; `dinitctl status greetd NetworkManager` deve mostrar os serviços esperados.
3. Abra a **Configuração de display DINX**, organize as saídas, feche-a e
   confirme que o perfil `DINX wdisplays` existe em
   `~/.config/shikane/config.toml`; saia e entre novamente para confirmar a
   reaplicação.
4. Em um volume NTFS descartável, monte pelo Pori ou UDisks2, crie e remova um
   arquivo de teste, desmonte e monte novamente. Não use um volume Windows
   hibernado ou com Fast Startup habilitado.
5. Use o Phyto para navegar no volume montado, o File Roller para criar e
   extrair um archive e o GParted somente contra um disco descartável.
6. Confirme que `Ctrl+Alt+F2` ou `Ctrl+Alt+F3` abre a TTY de recuperação e
   depois retorne à sessão gráfica.
7. Exercite bloqueio, bloqueio por idle, suspensão/retorno, brilho físico,
   áudio, rede e Bluetooth no hardware-alvo.
8. Antes dos testes gaming, instale os pacotes opcionais pelo [guia pós-instalação](install.md). O launcher continua oculto no greeter; só registre aprovação se os testes de launch DRM manual, Steam/jogo autenticados, controle e áudio PipeWire realmente passarem.

Evidências de CI/QEMU não substituem os passos 3–8 em hardware físico. Registre
`fail` ou `blocked`; não infira sucesso apenas pela presença dos pacotes.

## Matriz manual de três máquinas

Use a mesma ISO e registre máquina, modo de firmware, GPU, kernel e caminho do
relatório para cada alvo.

### Desktop

- inicializar a sessão live e verificar que ela abre diretamente em Aqueous + Pearl; se o fallback do Pearl Greeter aparecer, confirmar que ele expõe somente a entrada forçada `Aqueous + Pearl (DINX)` e registrar o caminho;
- verificar Wayland, Aqueous, Pearl, áudio, rede e aceleração GPU;
- se o suporte a NVIDIA for alegado, instalar `nvidia-open-dkms` com headers correspondentes, reiniciar e verificar render node, Vulkan e saída do Gamescope;
- bloquear com `Super+L`;
- verificar bloqueio após 600 segundos de idle;
- suspender, retomar, desbloquear e confirmar que a sessão continua utilizável;
- testar brilho físico;
- instale os pacotes gaming opcionais pelo [guia pós-instalação](install.md) antes da qualificação manual; DINX Gaming continua oculto e não pode ser selecionado no greeter;
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

Execute esta seção somente quando `lspci -n -d 1002:13fe` mostrar o PCI exato. Caso contrário, ignore-a e não instale pacotes BC-250. A ISO genérica não os inclui; configure o repositório DINX assinado e siga as etapas de instalação protegidas em `install.md` antes de qualificar:

- status do governor e limites de frequência configurados no hardware detectado;
- diagnósticos RADV/Vulkan;
- inicialização da GUI e da CLI do BC250 Control Center;
- telemetria, controles de recuperação e comportamento da GPU após suspend/resume;
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

Para um relatório qualificado para release, forneça o contexto imutável do build e
registre cada resultado manual somente depois de executar o teste correspondente:

```bash
export DINX_ALPHA7_MACHINE_ROLE=desktop   # desktop, laptop ou bc250
export DINX_ALPHA7_FIRMWARE_MODE=uefi    # bios ou uefi
export DINX_ALPHA7_RELEASE_TAG=v0.1.0-alpha.10
export DINX_ALPHA7_BUILD_COMMIT=0123456789012345678901234567890123456789
export DINX_ALPHA7_PACKAGE_REPOSITORY_SNAPSHOT=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
for result in \
  REAL_DRM_SESSION STEAM_AUTHENTICATION COMMERCIAL_GAME_LAUNCH \
  CONTROLLER_INPUT PIPEWIRE_GAME_AUDIO SUSPEND_RESUME \
  PHYSICAL_BRIGHTNESS GPU_RECOVERY UPDATE_PATH; do
  export "DINX_ALPHA7_RESULT_${result}=pass"
done
dinx-alpha7-hardware-report
report_path=$(find "${DINX_ALPHA7_REPORT_DIR:-$HOME/.local/state/dinx/alpha7}" \
  -type f -name 'alpha7-hardware-*.txt' -print | sort | awk 'END { print }')
build_metadata_path="$HOME/Downloads/dinx-build-metadata.txt"
scripts/check_dinx_hardware_evidence.sh "$report_path" "$build_metadata_path"
```

O validador exige função, modo de firmware, tag, commit do build, snapshot do
repositório e todos os resultados presentes como `pass`. Quando os metadados de
build do release baixados são fornecidos, ele também verifica o commit e o
snapshot do relatório contra esse arquivo. Use `fail` ou `blocked` para testes
malsucedidos; não marque manualmente uma observação como aprovada.
`filesystem_rollback=unsupported` permanece em todos os relatórios.

## Limite da evidência

CI e QEMU não provam posse real do DRM, Steam autenticado, launch de jogo
comercial, controle, áudio PipeWire do jogo, suspend/resume, brilho físico,
recuperação da GPU, firmware ou saúde de hardware em longo prazo. Essas
afirmações continuam abertas até a matriz manual das três máquinas passar.

A Beta 0.1 de sistema é um marco de release planejado; seus gates de hardware físico estão no [roadmap](roadmap.md). A qualificação gaming P5 continua separada. A Alpha 10 é um alpha de sistema, e este relatório não afirma suporte a hardware até que as evidências manuais de cada dispositivo sejam registradas.

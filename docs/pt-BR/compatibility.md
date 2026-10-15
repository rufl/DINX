# Contrato de compatibilidade com o Noctalia

[Português (Brasil)](compatibility.md) · [English](../compatibility.md)

Os aplicativos DINX complementam o Noctalia e não devem depender de detalhes internos não documentados. A compatibilidade é dividida em níveis para que os aplicativos continuem úteis sem o shell.

## Nível 1 — integração direta

Obrigatório para as primeiras versões utilizáveis dos aplicativos:

- Noctty é descoberto como terminal e funciona por meio de `$TERMINAL`.
- Noctty aceita os argumentos esperados de inicialização do terminal, incluindo diretório de trabalho quando suportado.
- Nocted possui uma entrada `.desktop` válida e aparece no launcher do Noctalia.
- Nocted suporta abertura normal por arquivos `.desktop` e argumentos de arquivo/linha quando implementados.
- Ambos seguem navegação de teclado padrão e locais XDG.
- Firefox é descoberto como o manipulador padrão de HTML, XHTML e HTTP/HTTPS.

## Nível 2 — integração visual

Os aplicativos consomem um formato ou adaptador documentado do Dinx Theme:

- modo claro/escuro;
- cores de destaque, fundo, primeiro plano e seleção;
- paleta ANSI do terminal;
- escolhas de fonte e ícones quando a plataforma as expuser.

O formato de tema é um contrato externo. Os aplicativos não devem interpretar arquivos de configuração privados do Noctalia como se fossem APIs estáveis. O recarregamento do tema deve ser explícito: por um caminho documentado monitorado ou por uma ação visível de recarregar.
O Firefox acompanha `/etc/firefox/policies/policies.json`. A política remove superfícies patrocinadas da Nova Aba/Suggest, Pocket/Stories, Firefox Studies e telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado. Firefox Accounts continua opcional e controlado pelo usuário; as atualizações normais do navegador permanecem habilitadas.


O contrato de desktop Noctalia/Mango da DINX é explícito:

- a regra de tags do Mango abre novas janelas como flutuantes; `Super+Space` alterna a janela focada de volta entre tiled/flutuante;
- a barra Noctalia chamada `main` reserva o topo e o dock de aplicativos reserva a parte inferior;
- NetworkManager, BlueZ, UPower e PipeWire alimentam os widgets de rede, Bluetooth, bateria e volume do Noctalia;
- o Noctalia é dono das superfícies de captura de tela e clipboard; `wl-copy`/`wl-paste` continuam como complemento de CLI, enquanto `grim`/`slurp` não são duplicados.

Os aplicativos independentes `nm-connection-editor`, Blueman, pwvucontrol, VLC e Strawberry continuam disponíveis no dock/launcher do Noctalia para fluxos completos de conexão, Bluetooth, áudio por stream, vídeo e biblioteca musical.
Gufw, Qps e a UI do OpenSnitch continuam disponíveis no dock/launcher; os serviços dinit UFW e OpenSnitch são instalados, mas não são habilitados no boot, portanto as regras de firewall exigem configuração deliberada. Não habilite os dois gerenciadores de regras sem revisar o ruleset netfilter resultante.
As ferramentas de gerenciamento `topgrade`, `paru` e Shelly continuam como complementos de launcher/CLI: topgrade usa o binário de release fixado e a configuração `pacman` do Artix da DINX, paru é compilado a partir de fonte fixada contra o ALPM do Artix e Shelly delega para a configuração `pacman` do Artix. Os pacotes não têm dependências ou unidades `systemd`, não adicionam repositórios Arch, não são iniciados pelo Noctalia nem pela sessão de boot e receitas AUR exigem revisão explícita do usuário.
O suporte a AMD Cyan Skillfish/BC-250 é um contrato de payload: firmware AMDGPU do Artix, Mesa RADV, diagnóstico Vulkan e o governor SMU fixado são instalados. O serviço dinit inicia automaticamente apenas o caminho do governor para PCI `1002:13fe`, usa a faixa segura de 1000-1850 MHz e encerra em outro hardware, sem unidade systemd.
O BC250 Control Center v1.21.1 é o contrato de launcher/monitor da BC-250: seu pacote MIT fixado fornece entrada desktop, CLI, política polkit e daemon headless. O daemon é iniciado uma vez pela sessão do usuário no Mango, não por systemd ou serviço root dinit; a DINX remove a unidade systemd e o drop-in do Cyan upstream. O dinit continua sendo um limite de persistência de serviço ao vivo/somente leitura no aplicativo upstream, portanto a falha ao inspecionar um serviço persistente não pode impedir a inicialização nem a telemetria ao vivo.

## Nível 3 — integração avançada

Recursos opcionais podem usar interfaces documentadas do Noctalia:

- ações do launcher que abrem o Nocted em um arquivo e linha;
- ações do launcher que abrem o Noctty em um diretório de trabalho escolhido;
- notificações e ações de aplicativos;
- plugins opcionais que expõem projetos do editor, arquivos recentes ou perfis de terminal.

A falha de uma integração opcional não pode impedir o aplicativo de iniciar ou editar arquivos.

## Matriz de testes de compatibilidade

A suíte deve testar contratos observáveis, não detalhes de implementação:

| Área | Critério de aceitação |
| --- | --- |
| Descoberta do terminal | `$TERMINAL` inicia o Noctty com um shell e o diretório solicitado |
| Metadados do desktop | entradas `.desktop` são válidas e descobertas |
| Argumentos de inicialização | comportamento de arquivo, linha e diretório de trabalho é determinístico |
| Importação de tema | um fixture de tema documentado produz as cores semânticas esperadas |
| Mudança de tema | um caminho suportado altera o aplicativo sem perda de dados |
| Firefox padrão | Firefox é o manipulador padrão de HTML/XHTML/HTTP/HTTPS |
| Política pró-user do Firefox | `policies.json` é analisado e desativa superfícies patrocinadas, Pocket/Stories, telemetria, recomendações, superfícies de assistente de IA e IP Protection integrado sem desativar atualizações |
| Layout do desktop | Mango abre novas janelas como flutuantes; Noctalia reserva a barra superior e o dock inferior |
| Utilitários do shell | Noctalia fornece UI de captura/clipboard; `wl-clipboard` fornece copy/paste de CLI |
| Handlers de mídia | VLC assume entradas MIME comuns de vídeo; Strawberry assume entradas MIME comuns de áudio |
| Gerenciamento de pacotes | `topgrade`, `paru` e Shelly usam a configuração ALPM/pacman do Artix, não têm dependência/unidade `systemd`, não adicionam repositórios Arch e continuam disponíveis para atualizações executadas explicitamente pelo usuário |
| BC250 Control Center | GUI/CLI/daemon v1.21.1, entrada no dock Noctalia, autostart na sessão do usuário Mango, fonte fixada e nenhum payload systemd; a telemetria ao vivo continua disponível quando a inspeção de persistência dinit não é suportada |
| Firewall/monitoramento de processos | Gufw, Qps e OpenSnitch são descobertos; os serviços UFW/OpenSnitch ficam desabilitados até configuração explícita |
| Fallback | aplicativos continuam utilizáveis sem o Noctalia |
| Falha de IPC | IPC indisponível ou malformado não impede a inicialização |
| Acesso por teclado | ações principais funcionam sem entrada de ponteiro |

Cada interface do Noctalia suportada deve identificar a versão testada e a versão do adaptador. Mudanças de versão exigem executar novamente a matriz de compatibilidade.

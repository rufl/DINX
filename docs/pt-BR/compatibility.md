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
- O Pale Moon é descoberto como manipulador padrão de HTML e HTTP/HTTPS.

## Nível 2 — integração visual

Os aplicativos consomem um formato ou adaptador documentado do Dinx Theme:

- modo claro/escuro;
- cores de destaque, fundo, primeiro plano e seleção;
- paleta ANSI do terminal;
- escolhas de fonte e ícones quando a plataforma as expuser.

O formato de tema é um contrato externo. Os aplicativos não devem interpretar arquivos de configuração privados do Noctalia como se fossem APIs estáveis. O recarregamento do tema deve ser explícito: por um caminho documentado monitorado ou por uma ação visível de recarregar.

O Pale Moon usa a interface documentada de templates de aplicativos do Noctalia v5, em vez de interpretar a configuração privada do shell:

- `palemoon-userChrome.css` mapeia os tokens semânticos de superfície, primeiro plano, destaque, hover e contorno do Noctalia para o chrome do navegador;
- `palemoon-userContent.css` aplica os mesmos tokens às superfícies internas de página vazia/inicial/nova aba do Pale Moon;
- o Noctalia renderiza os dois arquivos no perfil DINX pré-criado no caminho padrão de perfil do Pale Moon;
- um fallback escuro acompanha o perfil, portanto o Pale Moon continua utilizável sem o Noctalia;
- uma mudança de paleta ou modo é aplicada no próximo reinício do Pale Moon. O Noctalia não força o reinício do navegador.

O contrato de desktop Noctalia/Mango da DINX é explícito:

- a regra de tags do Mango abre novas janelas como flutuantes; `Super+Space` alterna a janela focada de volta entre tiled/flutuante;
- a barra Noctalia chamada `main` reserva o topo e o dock de aplicativos reserva a parte inferior;
- NetworkManager, BlueZ, UPower e PipeWire alimentam os widgets de rede, Bluetooth, bateria e volume do Noctalia;
- o Noctalia é dono das superfícies de captura de tela e clipboard; `wl-copy`/`wl-paste` continuam como complemento de CLI, enquanto `grim`/`slurp` não são duplicados.

Os aplicativos independentes `nm-connection-editor`, Blueman e pwvucontrol continuam disponíveis para configuração completa de conexões, Bluetooth e áudio por stream.


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
| Tema do Pale Moon | O Noctalia v5 renderiza a paleta semântica ativa em `userChrome.css` e `userContent.css` |
| Recarregamento do Pale Moon | a skin gerada aparece após o próximo reinício do Pale Moon |
| Layout do desktop | Mango abre novas janelas como flutuantes; Noctalia reserva a barra superior e o dock inferior |
| Utilitários do shell | Noctalia fornece UI de captura/clipboard; `wl-clipboard` fornece copy/paste de CLI |
| Fallback | aplicativos continuam utilizáveis sem o Noctalia |
| Falha de IPC | IPC indisponível ou malformado não impede a inicialização |
| Acesso por teclado | ações principais funcionam sem entrada de ponteiro |

Cada interface do Noctalia suportada deve identificar a versão testada e a versão do adaptador. Mudanças de versão exigem executar novamente a matriz de compatibilidade.

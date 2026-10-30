# Modelo de segurança da DINX

[Português (Brasil)](security-model.md) · [English](../security-model.md)

A DINX é uma alpha pública. O modelo de segurança prioriza instalação segura, limites de confiança explícitos e capacidade de recuperação em vez de conveniência.

A imagem live abre automaticamente a conta descartável `dinx` no `Aqueous + Pearl (DINX)`. Como quem consegue inicializar a ISO já controla a máquina live, um prompt de login adiciona atrito, mas não uma fronteira de segurança significativa. O login instalado/manual usa o Pearl Greeter pelo greetd e pela conta dedicada `pearl-greeter`; o host configurado força Aqueous/Pearl sem X11, UWSM ou systemd. A senha pública `dinx` fica apenas como fallback diagnóstico se o Pearl Greeter aparecer após uma inicialização manual da live; o sistema instalado mantém sua política de login separada, criada pelo Calamares.

## Hipóteses de ameaça

- ISOs e pacotes alpha podem conter defeitos e não devem ser tratados como releases de produção.
- Um aplicativo gráfico pode ser comprometido ou receber arquivos de projeto hostis.
- Ações de gerenciamento de serviços atravessam uma sessão de usuário sem privilégios e alteram o estado do sistema.
- Artefatos de pacotes e ISOs podem ser corrompidos ou substituídos se checksums e assinaturas não forem verificados.

## Operações privilegiadas

DinitUI e DINXPanel DEVEM:

- expor um conjunto finito de ações, em vez de execução arbitrária de comandos;
- validar identificadores de serviço e argumentos tipados contra a interface do Dinit;
- invocar `dinitctl` por argv, nunca por shell;
- usar escopo direto de usuário/sistema e tentar `pkexec` somente após falha explícita de autorização;
- retornar status e erros estruturados;
- expor a ação solicitada, exit status e saída do comando; usar o log próprio do Dinit para diagnóstico do serviço.

A ponte de GPU e o instalador de kernels da DINXPanel DEVEM usar planos fixos por argv. As ações de kernel PODEM instalar pacotes e headers correspondentes, NÃO DEVEM remover nenhum pacote ou o kernel em execução e DEVEM informar a necessidade de reinicialização após mudanças de kernel ou driver.

A interface deve diferenciar um serviço parado, com falha, desconhecido ou inacessível. Nunca deve informar sucesso apenas porque um processo foi iniciado.
A sessão gaming também é um limite fixo: o launcher no root overlay inicia somente o argv empacotado de Gamescope/Steam, sem interpolação de shell ou serviço systemd. As bibliotecas Steam de 32 bits são pacotes opcionais pós-instalação, não fazem parte do payload base nem são um runtime de init; o gate de conteúdo da ISO rejeita o daemon/runtime systemd e o systemctl. Dispositivos de controle, conteúdo dos jogos, credenciais Steam e serviços de rede continuam entradas controladas pelo usuário fora da qualificação por fixture da alpha.

Perfis de performance são um limite de política explícito, não um classificador automático de serviços. As listas embutidas `normal`, `lite` e `gaming` atuam apenas sobre daemons opcionais; perfis customizados aceitam somente identificadores de perfil/serviço validados, persistem na configuração XDG do usuário e aplicam ações de sistema pelo mesmo caminho `dinitctl`/`pkexec`. Nenhum plugin de shell ou IPC privado é necessário.

## Confiança em pacotes e ISOs

Para cada release alpha distribuível:

- manifestos de pacotes devem identificar entradas upstream e específicas da DINX;
- pacotes alpha não assinados devem permanecer em pré-release e registrar `signing: unavailable`; não podem ser apresentados como artefatos de produção suportados;
- checksums de ISO e pacotes devem ser publicados com cada release;
- metadados do build devem identificar o commit de origem e o snapshot de entradas;
- avisos de atualização devem ser explícitos porque a base é rolling.

Reprodutibilidade é um critério de aceitação. Um build que não identifica suas entradas não é candidato a release.

## Isolamento dos aplicativos

Deetty e Dintor não devem exigir privilégios elevados. Arquivos de projeto, plugins do editor e comandos de terminal são entradas não confiáveis. Os aplicativos devem seguir os limites normais de permissões XDG e não podem executar código do projeto silenciosamente.

Integrações opcionais usam limites padrão de XDG, Wayland e D-Bus. A forma das mensagens deve ser validada, endpoints indisponíveis devem ser tratados e a inicialização deve ser independente de serviços opcionais.

## Tratamento dos releases alpha

O repositório GitHub é público durante a alpha. O código é público; pacotes e ISOs ainda não publicados podem ser distribuídos deliberadamente. Cada release alpha deve incluir:

- escopo de hardware suportado;
- instruções de instalação e recuperação;
- problemas conhecidos;
- etapas de verificação de checksum/assinatura;
- aviso claro sobre possível perda de dados;
- orientação de rollback ou reinstalação quando atualizações forem inseguras.

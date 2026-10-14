# Modelo de segurança da DINX

[Português (Brasil)](security-model.md) · [English](../security-model.md)

A DINX é uma alpha pública. O modelo de segurança prioriza instalação segura, limites de confiança explícitos e capacidade de recuperação em vez de conveniência.

A imagem live inclui intencionalmente a conta de teste descartável `dinx`, com senha `dinx`, para que o smoke gráfico possa fazer login. Essa credencial é pública, nunca deve ser reutilizada e não é adequada para um sistema instalado.

## Hipóteses de ameaça

- ISOs e pacotes alpha podem conter defeitos e não devem ser tratados como releases de produção.
- Um aplicativo gráfico pode ser comprometido ou receber arquivos de projeto hostis.
- Ações de gerenciamento de serviços atravessam uma sessão de usuário sem privilégios e alteram o estado do sistema.
- Artefatos de pacotes e ISOs podem ser corrompidos ou substituídos se checksums e assinaturas não forem verificados.

## Operações privilegiadas

O Dinx Control e futuros componentes gráficos de manutenção DEVEM:

- expor um conjunto finito de ações, em vez de execução arbitrária de comandos;
- validar identificadores de serviço contra a interface do gerenciador de serviços;
- usar um helper restrito ou uma política polkit documentada para elevar privilégios;
- retornar status e erros estruturados;
- evitar completamente interpolação em shell;
- registrar a ação solicitada e seu resultado no caminho normal de journal/log do sistema.

A interface deve diferenciar um serviço parado, com falha, desconhecido ou inacessível. Nunca deve informar sucesso apenas porque um processo foi iniciado.

## Confiança em pacotes e ISOs

Para cada release alpha distribuível:

- manifestos de pacotes devem identificar entradas upstream e específicas da DINX;
- pacotes alpha não assinados devem permanecer em pré-release e registrar `signing: unavailable`; não podem ser apresentados como artefatos de produção suportados;
- checksums de ISO e pacotes devem ser publicados com cada release;
- metadados do build devem identificar o commit de origem e o snapshot de entradas;
- avisos de atualização devem ser explícitos porque a base é rolling.

Reprodutibilidade é um critério de aceitação. Um build que não identifica suas entradas não é candidato a release.

## Isolamento dos aplicativos

Noctty e Nocted não devem exigir privilégios elevados. Arquivos de projeto, plugins do editor e comandos de terminal são entradas não confiáveis. Os aplicativos devem seguir os limites normais de permissões XDG e não podem executar código do projeto silenciosamente.

O IPC opcional do Noctalia é tratado como um limite de integração não confiável: a forma das mensagens deve ser validada, endpoints indisponíveis devem ser tratados e a inicialização deve ser independente do shell.

## Tratamento dos releases alpha

O repositório GitHub é público durante a alpha. O código é público; pacotes e ISOs ainda não publicados podem ser distribuídos deliberadamente. Cada release alpha deve incluir:

- escopo de hardware suportado;
- instruções de instalação e recuperação;
- problemas conhecidos;
- etapas de verificação de checksum/assinatura;
- aviso claro sobre possível perda de dados;
- orientação de rollback ou reinstalação quando atualizações forem inseguras.

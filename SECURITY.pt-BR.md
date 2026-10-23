# Política de segurança

A DINX é uma alpha pública. Não a utilize em sistemas ou com dados que não possam ser restaurados.

## Escopo suportado

As correções de segurança têm como alvo a branch `main` atual e o artefato alpha mais recente documentado no workflow. ISOs antigas não são releases com suporte de segurança.

## Como reportar uma vulnerabilidade

Não abra uma issue pública para uma vulnerabilidade ainda não divulgada. Use o formulário privado de vulnerabilidades do GitHub:

<https://github.com/rufl/DINX/security/advisories/new>

Inclua:

- commit, execução do workflow ou artefato afetado;
- arquitetura do host e do guest;
- passos exatos para reproduzir;
- impacto e privilégios necessários;
- logs ou prova de conceito mínima sem segredos.

Se o reporte privado estiver indisponível, contate o proprietário pelo perfil do GitHub e não publique os detalhes antes de coordenar uma correção ou mitigação.

## Limites específicos da alpha

- A imagem live abre automaticamente a conta descartável `dinx` no `Labwc (DINX)`; a senha pública `dinx` fica apenas como fallback diagnóstico se o greeter aparecer. O acesso físico ao boot já dá controle da máquina live, então o autologin não é uma fronteira de autenticação. Nunca reutilize a senha em outro lugar.
- Verifique o checksum da ISO antes de gravar mídia removível ou inicializá-la.
- Não coloque credenciais de produção, dados pessoais ou chaves privadas na sessão live.
- Um boot bem-sucedido não prova segurança de produção, segurança de persistência ou segurança de atualizações.

Consulte o [modelo de segurança](docs/pt-BR/security-model.md) e o [guia de instalação](docs/pt-BR/install.md).

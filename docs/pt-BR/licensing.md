# Licenciamento e REUSE

[English](../licensing.md)

A DINX é um repositório com conteúdo misto. O código, a configuração, a documentação, os metadados de empacotamento e as ferramentas de release mantidos pelo repositório estão sob a licença Apache License 2.0.

## Política do repositório

- `LICENSE` contém o texto completo da Apache-2.0 para o trabalho mantido pela DINX.
- `REUSE.toml` declara a licença SPDX e os direitos autorais dos arquivos versionados.
- `LICENSES/` contém os textos canônicos usados pelos metadados REUSE.
- `distro/packages/deetty/deetty-0.1.0.tar.gz` é gerado localmente durante o build a partir do commit upstream exato do Deetty fixado em `source.env`; é ignorado pelo Git, não é vendorizado no repositório e fica fora do inventário de arquivos versionados do REUSE. Seu conteúdo continua sob a licença MIT upstream, com o `LICENSE` e os avisos internos preservados no pacote compilado. O pacote e os aplicativos DINX são chamados `deetty` (Deetty) e Dintor.

A revisão fixada de Deetty é obtida de `rufl/DEETTY`, mas ainda mantém identificadores internos upstream de módulos/ABI, caminhos de configuração, alguns nomes de recursos e marcadores de qualificação. Os patches DINX renomeiam o comando instalado, IDs desktop, identidade D-Bus, caminhos de licença e executáveis de qualificação; caminhos upstream mantidos nos patches e nos checks de extração identificam entradas exatas da fonte fixada. Renomear os outros identificadores internos altera o contrato upstream de configuração/protocolo e exige uma migração separada, não uma substituição textual global.

Não relicencie nem reescreva código, archives ou avisos de terceiros para fazê-los coincidir com o padrão do repositório. Ao adicionar um artefato vendorizado sob outra licença, inclua uma anotação REUSE específica.

## Como verificar a árvore

Na raiz do repositório:

```bash
reuse lint
```

Uma árvore compatível não deve reportar informações de licença ausentes, expressões SPDX inválidas, erros de leitura ou arquivos de licença não utilizados. Ao adicionar um arquivo, use um cabeçalho SPDX quando for prático ou atualize o `REUSE.toml` para conteúdo gerado, binário ou vendorizado.

A declaração de licença descreve o código-fonte e os metadados deste repositório. Ela não altera as licenças do Artix Linux, dos componentes do desktop ou de outros pacotes baixados durante o build ou a instalação da DINX; esses componentes continuam sob os termos upstream.

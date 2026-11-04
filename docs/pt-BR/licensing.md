# Licenciamento e REUSE

[English](../licensing.md)

A DINX é um repositório com conteúdo misto. O código, a configuração, a documentação, os metadados de empacotamento e as ferramentas de release mantidos pelo repositório estão sob a licença Apache License 2.0.

## Política do repositório

- `LICENSE` contém o texto completo da Apache-2.0 para o trabalho mantido pela DINX.
- `REUSE.toml` declara a licença SPDX e os direitos autorais dos arquivos versionados.
- `LICENSES/` contém os textos canônicos usados pelos metadados REUSE.
- `distro/packages/deetty/deetty-0.1.0.tar.gz` é gerado localmente durante o build a partir do commit upstream exato do Deetty fixado em `source.env`; é ignorado pelo Git, não é vendorizado no repositório e fica fora do inventário de arquivos versionados do REUSE. Seu conteúdo continua sob a licença MIT upstream, com o `LICENSE` e os avisos internos preservados no pacote compilado. O pacote e os aplicativos DINX são chamados `deetty` (Deetty) e Dintor.

A revisão upstream fixada ainda contém o alias de módulo `noctty`, nomes de recursos como `com.noctty.*` e `nocttyhere.desktop`, além de nomes de executáveis e marcadores de qualificação P2 (`noctty-*`, `NOCTTY_*`). Os patches e testes os mantêm somente ao referenciar essas entradas upstream exatas; eles não definem aliases de produto instalado nem caminhos do pacote instalado.

Não relicencie nem reescreva código, archives ou avisos de terceiros para fazê-los coincidir com o padrão do repositório. Ao adicionar um artefato vendorizado sob outra licença, inclua uma anotação REUSE específica.

## Como verificar a árvore

Na raiz do repositório:

```bash
reuse lint
```

Uma árvore compatível não deve reportar informações de licença ausentes, expressões SPDX inválidas, erros de leitura ou arquivos de licença não utilizados. Ao adicionar um arquivo, use um cabeçalho SPDX quando for prático ou atualize o `REUSE.toml` para conteúdo gerado, binário ou vendorizado.

A declaração de licença descreve o código-fonte e os metadados deste repositório. Ela não altera as licenças do Artix Linux, dos componentes do desktop ou de outros pacotes baixados durante o build ou a instalação da DINX; esses componentes continuam sob os termos upstream.

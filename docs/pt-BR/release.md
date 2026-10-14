# Release alpha da DINX

[English](../release.md)

Os releases da DINX são snapshots de validação em pré-release, não releases de
instalação persistente suportados. O workflow de release é acionado por uma tag `v*`
e reutiliza o build Artix do P0, a verificação de payload, a geração de SHA-512 e o
smoke test no QEMU antes de publicar os artefatos.

## Artefatos publicados

Cada release alpha contém:

- `dinx-<versão>-x86_64.iso` — imagem live de validação;
- o arquivo `.iso.sha512` correspondente;
- capturas PPM do menu de boot, gráficas e pós-entrada do QEMU Linux, além do log serial;
- `dinx-<versão>-dogfood.1-windows-x86_64.zip` — pacote pequeno de launcher Windows;
- metadados do pacote Windows, manifesto de deploy ZTASH e `SHA256SUMS`.

O pacote Windows não contém uma segunda cópia da ISO. Ele contém uma URL HTTPS fixada
e o SHA-512 da ISO. Na primeira execução, baixa o artefato exato do release para o
diretório privado, verifica o checksum e só então inicia o QEMU.

## Verificar o arquivo ZIP do Windows

Baixe `SHA256SUMS` do mesmo release do GitHub que contém o ZIP. Não copie um
checksum de um pacote ou release anterior:

```powershell
$zipPath = (Resolve-Path .\dinx-0.1.0-alpha.3-dogfood.1-windows-x86_64.zip).Path
$zipName = Split-Path -Leaf $zipPath
$expected = @(
    Get-Content .\SHA256SUMS |
        Where-Object { $_ -match [regex]::Escape($zipName) } |
        ForEach-Object { ($_ -split '\s+')[0] }
)
if ($expected.Count -ne 1) {
    throw "Checksum do ZIP não foi encontrado exatamente uma vez em SHA256SUMS"
}
$actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected[0].ToLowerInvariant()) {
    throw "SHA-256 do ZIP divergente. Esperado: $($expected[0]); atual: $actual"
}
Write-Host "SHA-256 do ZIP verificado: $actual"
```

## Smoke test visual no Windows

Requisitos:
- Windows PowerShell ou PowerShell 7;
- Windows x86_64;
- QEMU System x86_64, com `qemu-system-x86_64.exe` no `PATH` ou `DINX_QEMU` definido;
- sessão gráfica para a janela SDL;
- espaço suficiente para a ISO e pelo menos 2 GiB de memória do guest.

No pacote extraído:

```powershell
.\dinx.exe --visual-test
```

O comando padrão (`.\dinx.exe`) é equivalente. O launcher inicia a ISO com QEMU,
captura o quadro gráfico do menu de boot antes de enviar as teclas testadas,
envia a sequência de teclas do greeter, captura o quadro inicial do greeter e um
quadro da sessão após a entrada, valida os três como PPM binário e encerra o QEMU.
As evidências ficam em `evidence\` ao lado do pacote. O gate headless limitado usado
na qualificação do pacote é:

```powershell
.\dinx.exe --package-smoke
```

Este teste prova a inicialização do QEMU, a janela de boot da ISO e a criação das
capturas. Não prova aceleração GPU de hardware, áudio, rede ou instalação persistente.

## Deploy ZTASH para DDJARIN

Os metadados do pacote apontam para o receptor Windows registrado `ddjarin`. Na máquina
do proprietário, faça primeiro o preview da atribuição imutável:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.1
```

O script lê os metadados do release, verifica URL HTTPS, SHA-256, tamanho, target e
identidade da aplicação `dinx`, depois chama `zeer ztash assign` em modo preview. Nunca
imprime o token e nunca cria credenciais.

Depois de revisar o preview, aplique explicitamente:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.1 --apply
```

A operação exige o token privado do proprietário para DDJARIN em `ZEER_TOKEN_FILE`
(padrão: `~/.config/overzeer/ddjarin-agent.token`) e define a ação dogfood limitada e
tipada. O ZTASH baixa o pacote launcher fixado pelos metadados; a ISO não é enviada
pelo upload do pacote. O launcher baixa a ISO do artefato público do release e a
verifica localmente.

O receptor já deve ter o QEMU instalado. O deploy não instala serviço Windows nem
concede acesso a shell. Se o QEMU estiver ausente, a qualificação falha explicitamente
em vez de substituir silenciosamente o renderer.

## Limites do release

- A conta live é `dinx` / `dinx`; é pública, descartável e nunca deve ser reutilizada.
- A imagem não é um instalador de disco suportado e não possui persistência, rollback ou
  caminho Secure Boot assinado.
- O alpha publica checksums, mas não assinatura do pacote ou da ISO; isso fica
  registrado como `signing: unavailable` nos metadados dogfood.
- O teste Windows com QEMU é uma qualificação externa do receptor. Sucesso nele não
  transforma a imagem alpha em release de hardware suportado.

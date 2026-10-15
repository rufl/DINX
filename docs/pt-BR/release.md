# Release alpha da DINX

[English](../release.md)

Os releases da DINX são snapshots de validação em pré-release, não releases de
instalação persistente suportados. O workflow de release é acionado por uma tag `v*`
e reutiliza o build Artix do P0, a verificação de payload, a geração de SHA-512 e o
smoke test no QEMU antes de publicar os artefatos.

O build P0 verifica o archive versionado do código NOCTTY/NoctEd contra o commit exato
do repositório e o contrato SHA-256 em `distro/packages/noctty/source.env`, compila o
pacote nativo `noctty` com Zig 0.17.0 e verifica que os dois aplicativos e seus
recursos desktop/editor estão na ISO. O caminho de release não clona o NOCTTY nem exige
segredo de repositório; atualize o archive e o contrato juntos quando alterar a origem
fixada.

## Snapshot validado atual

O workflow P0 mais recente aprovado é a [execução 38739313464](https://github.com/rufl/DINX/actions/runs/38739313464), no commit `8a28eb3`. Ele passou o contrato do BC250 Control Center v1.21.1, os builds de pacotes Artix, a criação da ISO, boot no QEMU, validação do payload gráfico, smoke da instalação persistente/TTY de recuperação, atestação e upload do artefato. O artefato do workflow é `dinx-foundation-iso-8a28eb3b2d35781dd592e47701f0a7e614669ca7`; ele continua sendo um artefato de validação, não um release estável para hardware.

## Artefatos publicados

Cada release alpha contém:

- `dinx-<versão>-x86_64.iso` — imagem live de validação com NOCTTY e NoctEd;
- o arquivo `.iso.sha512` correspondente;
- capturas PPM do menu de boot, gráficas e pós-entrada do QEMU Linux, além do log serial;
- `dinx-<versão>-dogfood.1-windows-x86_64.zip` — pacote pequeno de launcher Windows;
- metadados do pacote Windows, manifesto de deploy ZTASH e `SHA256SUMS`.

O pacote Windows não contém uma segunda cópia da ISO. Ele contém uma URL HTTPS fixada
e o SHA-512 da ISO. Na primeira execução, baixa o artefato exato do release para o
diretório privado, verifica o checksum e só então inicia o QEMU.
## Verificar a procedência do release

O workflow cria atestações de artefato do GitHub para a ISO, seus checksums, o
launcher Windows e os metadados do release. Verifique cada arquivo baixado online
com o GitHub CLI:

```bash
gh attestation verify dinx-<versão>-x86_64.iso -R rufl/DINX
gh attestation verify dinx-<versão>-dogfood.1-windows-x86_64.zip -R rufl/DINX
```

Os arquivos `.sha512` e `SHA256SUMS` continuam úteis para verificações offline. A
atestação prova a procedência do build no GitHub Actions; não torna o instalador
experimental nem o suporte de hardware adequados para produção.


## Verificar o arquivo ZIP do Windows

Baixe `SHA256SUMS` do mesmo release do GitHub que contém o ZIP. Não copie um
checksum de um pacote ou release anterior:

```powershell
$downloadRoot = (Get-Location).Path
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.4'
$zipName = 'dinx-0.1.0-alpha.4-dogfood.1-windows-x86_64.zip'
$zipPath = Join-Path $downloadRoot $zipName
$sumPath = Join-Path $downloadRoot 'SHA256SUMS'

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/$zipName" -OutFile $zipPath
}
if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/SHA256SUMS" -OutFile $sumPath
}

$expected = @(
    Get-Content -LiteralPath $sumPath |
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
- A imagem ainda é um instalador de disco experimental, sem atualização, rollback ou
  caminho Secure Boot assinado. O CI qualifica o contrato offline do rootfs em um disco
  BIOS descartável e captura um quadro da TTY de recuperação; isso não qualifica hardware
  arbitrário.
- Os arquivos do release têm atestações de artefato do GitHub, mas a imagem ainda não
  fornece uma chave de assinatura de repositório pacman nem um banco de pacotes assinado
  para atualizações do sistema instalado.
- O teste Windows com QEMU é uma qualificação externa do receptor. Sucesso nele não
  transforma a imagem alpha em release de hardware suportado.

# Release alpha da DINX

[English](../release.md)

Os releases da DINX são snapshots de validação em pré-release, não releases de
instalação persistente suportados. O workflow de release é acionado por uma tag `v*`
e reutiliza o build Artix do P0, a verificação de payload, a geração de SHA-512 e o
smoke test no QEMU antes de publicar os artefatos.

A metadata do build fica vinculada ao artefato exato da ISO nos caminhos P0 e de
release com tag: o CI recalcula o tamanho em bytes e o SHA-512 da ISO e rejeita
metadados que não correspondam ao arquivo baixado.

O build P0 verifica o archive versionado do código NOCTTY/NoctEd contra o commit exato
do repositório e o contrato SHA-256 em `distro/packages/noctty/source.env`, compila o
pacote nativo `noctty` com Zig 0.17.0 e verifica que os dois aplicativos e seus
recursos desktop/editor estão na ISO. O caminho de release não clona o NOCTTY nem exige
segredo de repositório; atualize o archive e o contrato juntos quando alterar a origem
fixada.

Na P3, o mesmo build do pacote também executa `scripts/nocted_p3_qualification.sh`. Ele qualifica o core do editor Nocted, diagnósticos/navegação reais com `clangd`, os esquemas GTK/X11 nativos claro e escuro e marcadores limitados de status/diff do Git antes de o pacote ser elegível para o payload da ISO e o gate P0 de QEMU/instalação.

## Snapshot validado atual

A compilação compacta atual da Alpha 9 é a [execução CI 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) para a [v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`. Ela passou os contratos estáticos/first-party, os builds de pacotes Artix, a criação da ISO compacta, boot e payload gráfico no QEMU, smokes de particionamento e instalação/recuperação persistente do Calamares, verificação dos metadados de build, assinatura persistente de pacotes, atestação de procedência e publicação do release. A ISO direta publicada tem 2.008.801.280 bytes e SHA-512 `b3724c82348c229ee897880e03e8adc80d9b5b25588b0aca9dfcfedf0c4744e4e1ae01dcb536f6555502e8fe595f71f06bed599372dffe0e1b0f34b29f3b5b2d`; o snapshot do repositório estável assinado é `01fc8270e5f0fa0339647c9bbde5934ec247a7c29cf235940d4ea9dcedab5827`.

Uma validação pós-release separada na `main`, a [execução 39934458077](https://github.com/rufl/DINX/actions/runs/39934458077) no commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb`, concluiu em 52m02s após passar pelos checks de build, boot, payload gráfico, instalação persistente/TTY de recuperação em BIOS e UEFI, atestação e upload. Ela confirma os contratos depois do snapshot publicado, mas não publicou outro asset; a Alpha 9 continua sendo o release atual.
O release agora usa o caminho determinístico de ISO compacta de
`scripts/build-iso.sh`: SquashFS comprimido com xz, filtro BCJ x86, blocos de
1 MiB e dicionário de 1 MiB, com limite estrito abaixo de 2 GiB por asset do
GitHub. A Alpha 9 publica uma ISO direta; releases antigos ainda podem usar
partes da ISO.
O manifesto comum versionado mantém o caminho documentado de firmware AMDGPU, deixa firmware genérico e `powertop` fora da imagem final e mantém os headers do kernel apenas para a geração do initramfs da ISO; sua árvore de fontes é excluída do SquashFS final.

## Artefatos publicados

Cada release alpha contém:

- `dinx-<versão>-x86_64.iso` quando ela couber no limite por arquivo do GitHub; releases antigos que excedam o limite usam arquivos ordenados `.iso.part-*` mais `.iso.parts.json`;
- o arquivo `.iso.sha512` correspondente;
- capturas PPM do menu de boot, gráficas e pós-entrada do QEMU Linux, além do log serial;
- `dinx-<versão>-dogfood.1-windows-x86_64.zip` — pacote pequeno de launcher Windows;
- metadados do pacote Windows, manifesto de deploy ZTASH e `SHA256SUMS`;
- `dinx-<versão>-build-metadata.txt` — imagem do builder, commit da fonte, snapshot de pacotes, checksums das fontes e digest da ISO;
- assets do repositório pacman DINX assinado: `dinx.db`, `dinx.db.tar.gz`, suas
  assinaturas, `dinx-package-signing-key.gpg`, `dinx-repository-metadata.txt` e
  os arquivos customizados `*.pkg.tar.zst` com assinaturas destacadas;

## Repositório de pacotes assinado

Releases com tag exigem o segredo do GitHub Actions `DINX_PACKAGE_SIGNING_KEY`,
contendo a chave privada de produção em formato armored sem senha. O workflow falha
antes da publicação dos pacotes quando o segredo não existe; o workflow P0 sem tag
continua usando uma chave CI efêmera e o canal `ci`.

Provisione os segredos a partir de uma máquina confiável do responsável pelo
release; nunca faça commit da chave privada nem a coloque em um artefato:

```bash
fingerprint='<fingerprint de 40 hex da produção>'
gpg --armor --export-secret-keys "$fingerprint" > /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_KEY --repo rufl/DINX < /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_FINGERPRINT --repo rufl/DINX --body "$fingerprint"
shred -u /tmp/dinx-package-signing-key.asc
```

A chave deve poder ser usada sem interação pelo `makepkg --sign`; mantenha o
backup da master key offline e faça rotações deliberadas, pois o fingerprint é
registrado em cada snapshot do repositório e metadado do release.

O repositório de release é um repositório pacman estático hospedado nos assets do
release do GitHub. Ele contém somente os pacotes customizados da DINX; os
repositórios Artix continuam separados. Instale a chave pública e configure a URL:

```bash
release_url='https://github.com/rufl/DINX/releases/download/v<versão>'
curl --fail --location "$release_url/dinx-package-signing-key.gpg" \
  --output /tmp/dinx-package-signing-key.gpg
pacman-key --add /tmp/dinx-package-signing-key.gpg
pacman-key --lsign-key <fingerprint-da-assinatura>
```

```ini
[dinx]
SigLevel = Required
Server = https://github.com/rufl/DINX/releases/download/v<versão>
```

Execute `pacman -Syu` após atualizar os bancos. O workflow P0 executa uma
transação real assinada de instalação, atualização e downgrade com os mesmos
requisitos de assinatura. Isso qualifica transações de pacotes, não uma atualização
completa da ISO instalada, rollback do filesystem ou recuperação física.

Para uma ISO direta, verifique o checksum correspondente:

```bash
sha512sum -c dinx-<versão>-x86_64.iso.sha512
```

Quando um release publicar partes, concatene-as em ordem lexicográfica e
depois verifique a imagem completa:

```bash
cat dinx-<versão>-x86_64.iso.part-* > dinx-<versão>-x86_64.iso
sha512sum -c dinx-<versão>-x86_64.iso.sha512
```

O pacote Windows não contém uma segunda cópia da ISO. Ele contém uma URL HTTPS
fixada e o SHA-512 da ISO, além da lista ordenada de partes quando necessário. Na
primeira execução, baixa os assets exatos do release para o diretório privado,
verifica cada parte quando presente, monta a ISO quando necessário, verifica o
checksum completo e só então inicia o QEMU.
## Verificar a procedência do release

O workflow cria atestações de artefato do GitHub para a ISO ou suas partes, seus checksums,
o launcher Windows e os metadados do release. Verifique cada arquivo baixado online
com o GitHub CLI:

```bash
gh attestation verify dinx-<versão>-x86_64.iso -R rufl/DINX
gh attestation verify dinx-<versão>-x86_64.iso.part-00 -R rufl/DINX
gh attestation verify dinx-<versão>-dogfood.1-windows-x86_64.zip -R rufl/DINX
gh attestation verify dinx-<versão>-build-metadata.txt -R rufl/DINX
```

Use o comando da ISO direta somente quando esse artefato existir; caso contrário, repita
o comando da parte para cada arquivo `.iso.part-*`. Os arquivos `.sha512` e `SHA256SUMS`
continuam úteis para verificações offline. A atestação prova a procedência do build no GitHub
Actions; não torna o instalador experimental nem o suporte de hardware adequados para produção.


## Verificar o arquivo ZIP do Windows

Baixe `SHA256SUMS` do mesmo release do GitHub que contém o ZIP. Não copie um
checksum de um pacote ou release anterior:

```powershell
$downloadRoot = (Get-Location).Path
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.9'
$zipName = 'dinx-0.1.0-alpha.9-dogfood.1-windows-x86_64.zip'
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
scripts/deploy-ztash.sh v0.1.0-alpha.9
```

O script lê os metadados do release, verifica URL HTTPS, SHA-256, tamanho, target e
identidade da aplicação `dinx`, depois chama `zeer ztash assign` em modo preview. Nunca
imprime o token e nunca cria credenciais.

Depois de revisar o preview, aplique explicitamente:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.9 --apply
```

A operação exige o token privado do proprietário para DDJARIN em `ZEER_TOKEN_FILE`
(padrão: `~/.config/overzeer/ddjarin-agent.token`) e define a ação dogfood limitada e
tipada. O ZTASH baixa o pacote launcher fixado pelos metadados; a ISO não é enviada
pelo upload do pacote. O launcher baixa a ISO do artefato público do release e a
verifica localmente.

O receptor já deve ter o QEMU instalado. O deploy não instala serviço Windows nem
concede acesso a shell. Se o QEMU estiver ausente, a qualificação falha explicitamente
em vez de substituir silenciosamente o renderer.

## Gate da próxima alpha

Antes de criar a próxima tag alpha, o commit da tag deve passar pelo workflow P0 local atual, incluindo os contratos de lock/idle/brilho, os checks de orçamento e o contrato de particionamento do Calamares. A ISO resultante deve passar a validação de conteúdo SquashFS, o caminho de boot/captura QEMU de 90 segundos, o smoke de instalação Calamares/TTY de recuperação em disco descartável, o smoke transacional BIOS/UEFI/Btrfs com subvolumes preexistentes, o smoke Windows side-by-side com encolhimento NTFS e layout manual preservando ESP/dados de boot Microsoft, geração de checksum, atestação do artefato e montagem dos assets de release.
O gate automatizado também executa a qualificação real do daemon/GTK do DinitUI e um smoke limitado de inicialização do Calamares com Xvfb. Eles complementam os smokes transacionais de particionamento e rootfs offline; `scripts/smoke-install.sh` continua sendo um teste de contrato de rootfs/instalação e não afirma uma instalação completa pela interface do Calamares.

O builder P0 assina o repositório pacman customizado e registra seu snapshot de
conteúdo, checksum do banco, checksum da chave pública e fingerprint da assinatura
nos metadados do build. Builds sem tag usam a chave CI efêmera. Builds de release
com tag exigem o segredo da chave de produção e publicam os assets do canal `stable`.

O responsável pelo release deve registrar manualmente uma qualificação real de sessão Wayland: `Super+L`, lock após 600 segundos de idle, lock antes da suspensão, desbloqueio após resume e brilho físico para cima/baixo. Uma VM pode qualificar a ordem da sessão; hardware físico é necessário para afirmar suporte a brilho e suspensão.

Atualize o run ID, commit, tamanho/digest do artefato e os links dos releases nos documentos de status em inglês e português somente depois que o novo workflow passar. As afirmações de P5 gaming continuam separadas até passarem os testes de DRM, Steam/jogo, controle/áudio, retorno ao greeter e suspend/GPU físico.
O caminho de release com tag agora possui atualização assinada e downgrade de pacote
documentados. Ele não afirma atualização da ISO instalada, rollback do filesystem ou
recuperação física. WIZP e o CUPS opcional continuam fora das afirmações de payload
da ISO até que o artefato externo ou a transação real do pacote seja qualificada de
ponta a ponta.

Use a [matriz de qualificação de hardware](alpha7-qualification.md); seu
utilitário mantém o nome Alpha 7 por compatibilidade. A ISO gerada inclui
`dinx-alpha7-hardware-report`, um utilitário somente de leitura para anexar
evidências de hardware e sessão sem alterar o estado do sistema.

## Limites do release

- A conta live é `dinx` / `dinx`; é pública, descartável e nunca deve ser reutilizada.
- A imagem ainda é um instalador de disco experimental, sem atualização da ISO instalada,
  rollback do filesystem ou caminho Secure Boot assinado. O CI qualifica o contrato
  offline do rootfs em discos BIOS e UEFI descartáveis e captura um quadro da TTY de
  recuperação; isso não qualifica hardware arbitrário.
- Os arquivos do release têm atestação de artefato do GitHub e, depois da configuração
  do segredo da chave de produção, um banco pacman DINX assinado e chave pública. Isso
  qualifica transações de pacotes, não o ciclo de vida completo do sistema instalado.
- O teste Windows com QEMU é uma qualificação externa do receptor. Sucesso nele não
  transforma a imagem alpha em release de hardware suportado.

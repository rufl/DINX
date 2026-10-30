# Release alpha da DINX

[English](../release.md)

Os releases da DINX são snapshots de validação em pré-release, não releases de
instalação persistente suportados. O workflow de release é acionado por uma tag `v*`
e reutiliza o build Artix do P0, a verificação de payload, a geração de SHA-512 e o
smoke test no QEMU antes de publicar os artefatos.

A metadata do build fica vinculada ao artefato exato da ISO nos caminhos P0 e de
release com tag: o CI recalcula o tamanho em bytes e o SHA-512 da ISO e rejeita
metadados que não correspondam ao arquivo baixado.

O build P0 verifica o archive versionado do código upstream NOCTTY contra o commit exato
do repositório e o contrato SHA-256 em `distro/packages/deetty/source.env`, compila o
pacote nativo `deetty` com Zig 0.17.0 e verifica que os aplicativos Deetty/Dintor e seus
recursos desktop/editor estão na ISO. O caminho de release preserva a origem upstream
NOCTTY sem alteração e não a clona durante o build; atualize o archive e o contrato
juntos quando alterar a origem fixada.

Na P3, o mesmo build do pacote também executa `scripts/dintor_p3_qualification.sh`. Ele qualifica o core do editor Dintor, diagnósticos/navegação reais com `clangd`, os esquemas GTK/X11 nativos claro e escuro e marcadores limitados de status/diff do Git antes de o pacote ser elegível para o payload da ISO e o gate P0 de QEMU/instalação.

## Snapshot validado atual

A snapshot publicado da Alpha 10 é a [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10), validada pela [execução marcada 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) no commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`. O build passou os contratos de pacotes/perfil, builds de pacotes Artix, checks de conteúdo/tamanho da ISO, boot e payload gráfico no QEMU, smokes de layout do Calamares, primeiro boot persistente BIOS/UEFI e TTY de recuperação, checks do repositório assinado, vínculo dos metadados, atestação e publicação. A ISO direta tem 1.862.772.736 bytes e SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; snapshot do repositório de pacotes `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

A execução P0 da main após a Alpha 10, [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770), no commit `bf773500965c843e014e3bc3ef8fea685e14b91b`, passou pelo build completo, QEMU, payload gráfico, Calamares e gates de instalação persistente/recuperação BIOS/UEFI, além de metadados, atestação e upload do artefato. É uma validação pós-release da main; a ISO Alpha 10 publicada continua sendo o artefato da execução marcada [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746), no commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`.

A próxima etapa de sistema é a qualificação planejada e sem data da Beta 0.1. Ela é separada do gaming P5; veja no [roadmap](roadmap.md) os gates de hardware, instalador, atualização e recuperação.

Alpha 9 e as candidatas anteriores são evidência histórica, não o release atual. O workflow de release recompila o commit marcado e só publica depois que passam as verificações correspondentes de metadados da ISO, repositório assinado, checksum e procedência.

O artefato Alpha 9 usou o caminho determinístico anterior de ISO compacta de
`scripts/build-iso.sh`: SquashFS com xz, filtro BCJ x86, blocos de 1 MiB e
dicionário de 1 MiB. A Alpha 10 usa blocos de 256 KiB e dicionário de 256 KiB,
mantendo a ISO direta abaixo do limite de 2 GiB por asset do GitHub.
O manifesto comum versionado mantém o caminho documentado de firmware AMDGPU, deixa firmware genérico e `powertop` fora da imagem final e mantém os headers do kernel apenas para a geração do initramfs da ISO; sua árvore de fontes é excluída do SquashFS final.

## Artefatos publicados

Cada release alpha contém:

- `dinx-<versão>-x86_64.iso` quando ela couber no limite por arquivo do GitHub; releases antigos que excedam o limite usam arquivos ordenados `.iso.part-*` mais `.iso.parts.json`;
- o arquivo `.iso.sha512` correspondente;
- capturas PPM do menu de boot, gráficas e da sessão posterior do QEMU Linux, além do log serial;
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
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.10'
$zipName = 'dinx-0.1.0-alpha.10-dogfood.1-windows-x86_64.zip'
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
captura o quadro da sessão aberta automaticamente e outro quadro posterior,
valida os três como PPM binário e encerra o QEMU. As evidências ficam em
`evidence\` ao lado do pacote. O gate headless limitado usado na qualificação do
pacote é:

```powershell
.\dinx.exe --package-smoke
```

Este teste prova a inicialização do QEMU, a janela de boot da ISO e a criação das
capturas. Não prova aceleração GPU de hardware, áudio, rede ou instalação persistente.

## Deploy ZTASH para DDJARIN

Os metadados do pacote apontam para o receptor Windows registrado `ddjarin`. Na máquina
do proprietário, faça primeiro o preview da atribuição imutável:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.10
```

O script lê os metadados do release, verifica URL HTTPS, SHA-256, tamanho, target e
identidade da aplicação `dinx`, depois chama `zeer ztash assign` em modo preview. Nunca
imprime o token e nunca cria credenciais.

Depois de revisar o preview, aplique explicitamente:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.10 --apply
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

Atualize IDs de execução, commits, tamanhos/digests de artefato e links de release nos documentos de status em inglês e português somente depois que o workflow correspondente passar. O release planejado Beta 0.1 do sistema não afirma suporte gaming; P5 continua separado até passarem os testes de DRM real, Steam/jogo, controle/áudio, retorno ao greeter e suspend/GPU em hardware físico.
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

- A imagem live faz autologin na conta descartável `dinx` e mantém a senha pública `dinx` apenas como fallback diagnóstico se o Pearl Greeter aparecer após uma inicialização manual da live. Ela nunca é uma fronteira de autenticação e não deve ser reutilizada.
- A imagem ainda é um instalador de disco experimental, sem atualização da ISO instalada,
  rollback do filesystem ou caminho Secure Boot assinado. O CI qualifica o contrato
  offline do rootfs em discos BIOS e UEFI descartáveis e captura um quadro da TTY de
  recuperação; isso não qualifica hardware arbitrário.
- Os arquivos do release têm atestação de artefato do GitHub e, depois da configuração
  do segredo da chave de produção, um banco pacman DINX assinado e chave pública. Isso
  qualifica transações de pacotes, não o ciclo de vida completo do sistema instalado.
- O teste Windows com QEMU é uma qualificação externa do receptor. Sucesso nele não
  transforma a imagem alpha em release de hardware suportado.

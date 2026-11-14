# Release alpha da DINX

[English](../release.md)

Os releases da DINX são snapshots de validação em pré-release, não releases de
instalação persistente suportados. O workflow de release é acionado por uma tag `v*`
e reutiliza o build Artix do P0, a verificação de payload, a geração de SHA-512 e os smokes de boot QEMU configurados antes de publicar. O release Alpha 12 testou VGA padrão, não VMware-SVGA; o qualificador compartilhado atual testa VGA padrão e Virtio-VGA. O caminho `vmware-svga` do QEMU 11.1.2/KVM trava no udev inicial com `vmwgfx` carregado e não qualifica o VirtualBox.

O workflow mantém o pré-release móvel `alpha-latest` com `dinx-latest-x86_64.iso` e seu checksum SHA-512. Releases por tag o atualizam; use `workflow_dispatch` com `release_tag` somente para inicializar ou resincronizar o alias. O limite de 2 GiB por asset do GitHub permite o alias apenas quando a alpha mais recente tem uma ISO única; use a página da release versionada quando a imagem estiver dividida. O publicador tenta novamente erros 404 transitórios enquanto metadados, arquivos e uploads do alias ficam disponíveis, aguarda a listagem de releases e impede que uma alpha antiga reverta o alias.

A metadata do build fica vinculada ao artefato exato da ISO nos caminhos P0 e de
release com tag: o CI recalcula o tamanho em bytes e o SHA-512 da ISO e rejeita
metadados que não correspondam ao arquivo baixado.

O build P0 verifica o archive versionado do código upstream Deetty contra o commit exato
do repositório e o contrato SHA-256 em `distro/packages/deetty/source.env`, compila o
pacote nativo `deetty` com Zig 0.17.0 e verifica que os aplicativos Deetty/Dintor e seus
recursos desktop/editor estão na ISO. O caminho de release não clona o repositório
Deetty durante o build; atualize o archive e o contrato juntos quando alterar a origem
fixada.

Na P3, o mesmo build do pacote executa `scripts/dintor_p3_qualification.sh`. Ele
qualifica o core do editor Dintor, os esquemas GTK/X11 nativos claro e escuro,
marcadores limitados de status/diff do Git e o cliente LSP genérico por stdio
contra um servidor `clangd` real. Esse é um check de protocolo somente do
builder; a ISO inclui o ZLS para Zig e não distribui o pacote `clang`.

## Snapshot validado atual

A snapshot publicada da Alpha 16 é a [v0.1.0-alpha.16](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.16), validada pela [execução marcada 43622209772](https://github.com/rufl/DINX/actions/runs/43622209772) no commit `81d2606e8711c6e7a3d5efaedff118df0f4fc7a7`. O build passou os contratos de pacotes/perfil, builds de pacotes Artix, checks de conteúdo/tamanho da ISO, boot/captura gráfica no QEMU com VGA padrão, smokes de layout do Calamares, primeiro boot persistente BIOS/UEFI e TTY de recuperação, checks do repositório assinado, vínculo dos metadados, atestação e publicação. A ISO direta tem 2.133.706.752 bytes e SHA-512 `0df5da98684cb41d8ec6408bfb6b0e81bf4711bddf3718d2b3b3fbfdae67d5e65477195c3fb85fbaf9ae93df64ece1492b2b1f8fd2a5ef1fde2032fd09fd4600`; snapshot do repositório de pacotes assinado `829cba983a866d39a422a4a56046b29456598b5ec1574b9205f8cce0555bf133`. A Alpha 16 é a primeira ISO com EuroOffice (fork lean do ONLYOFFICE publicado pela branch `office`) e fica abaixo do limite de 2 GiB por asset graças à compressão xz/BCJ e aos trims de payload no build. O qualificador compartilhado atual testa VGA padrão e Virtio-VGA; o caminho `vmware-svga` do QEMU 11.1.2/KVM trava no udev inicial com `vmwgfx` carregado e não é um passe de VirtualBox. O boot direto no VirtualBox continua não qualificado.

A execução P0 da main [43618288202](https://github.com/rufl/DINX/actions/runs/43618288202), no commit `c4412214ed3f99a5eceba6fda80786d51e62eff5`, passou pelo build completo, QEMU, payload gráfico, Calamares e gates de instalação persistente/recuperação BIOS/UEFI, além de metadados, atestação e upload do artefato, com a ISO contendo EuroOffice abaixo do limite de 2 GiB; a Alpha 16 foi publicada pela execução marcada [43622209772](https://github.com/rufl/DINX/actions/runs/43622209772), no commit `81d2606e8711c6e7a3d5efaedff118df0f4fc7a7`.

A próxima etapa de sistema é a qualificação planejada e sem data da Beta 0.1. Ela é separada do gaming P5; veja no [roadmap](roadmap.md) os gates de hardware, instalador, atualização e recuperação.

Alpha 9 e as candidatas anteriores são evidência histórica, não o release atual. O workflow de release recompila o commit marcado e só publica depois que passam as verificações correspondentes de metadados da ISO, repositório assinado, checksum e procedência.

O SquashFS final usa o caminho determinístico de ISO compacta de
`scripts/build-iso.sh`: compressão xz com filtro BCJ x86, blocos e dicionário
de 1 MiB (máximo do squashfs-tools do builder) e 4 threads de compressão, mantendo a ISO direta abaixo do limite de 2 GiB por
asset do GitHub.
O manifesto comum versionado mantém o caminho documentado de firmware AMDGPU, deixa firmware genérico e `powertop` fora da imagem final e mantém os headers do kernel apenas para a geração do initramfs da ISO; sua árvore de fontes é excluída do SquashFS final.

## Artefatos publicados

Cada release alpha contém:

- `dinx-<versão>-x86_64.iso` quando ela couber no limite por arquivo do GitHub; releases antigos que excedam o limite usam arquivos ordenados `.iso.part-*` mais `.iso.parts.json`;
- o arquivo `.iso.sha512` correspondente;
- um alias de download direto, `dinx-latest-x86_64.iso`, e seu checksum `.sha512` no pré-release `alpha-latest`; o workflow o atualiza a partir do alpha publicado mais recente com ISO única abaixo do limite de 2 GiB por asset do GitHub, o que mantém uma segunda cópia da imagem;
- capturas PPM do menu de boot, gráficas e da sessão posterior do QEMU Linux, além do log serial;
- `dinx-<versão>-dogfood.1-windows-x86_64.zip` — pacote pequeno de launcher Windows;
- metadados do pacote Windows, manifesto de deploy ZTASH e `SHA256SUMS`;
- `dinx-<versão>-build-metadata.txt` — imagem do builder, commit da fonte, snapshot de pacotes, checksums das fontes e digest da ISO;
- assets do repositório pacman DINX assinado: `dinx.db`, `dinx.db.tar.gz`, suas
  assinaturas, `dinx-package-signing-key.gpg`, `dinx-repository-metadata.txt` e
  os arquivos customizados `*.pkg.tar.zst` com assinaturas destacadas;

O perfil atual inclui o EuroOffice (fork lean do ONLYOFFICE, AGPL-3.0) como
suíte de escritório e PDF, consumido dos releases `eurooffice/v*` da branch
office com pacote pacman e squashfs live verificados por SHA256; o EuroOffice
é o handler padrão de `application/pdf` e dos formatos OOXML. PaintFE, Transit,
Zenkai, Patchy e Blockbench são empacotados como árvores `/opt/<pacote>/`
pré-extraídas (convenção de repack no `distro/iso/README.pt-BR.md`), com
launchers que executam `AppRun` sem FUSE nem extração em tmpfs. Imagens acima
do limite de 2 GiB por asset do GitHub usam a entrega dividida; o alias ISO de
arquivo único só avança quando o release publica uma imagem que cabe nesse
limite.

## Repositório móvel de pacotes assinado

O código da DINX agora configura um repositório pacman móvel e assinado,
hospedado como assets de GitHub Release sob `dinx-packages-latest`, em
`https://github.com/rufl/DINX/releases/download/dinx-packages-latest`.
O atualizador semanal verifica 20 pins de origem de pacotes toda segunda-feira,
às 04:17 UTC, e abre um pull request para revisão; nunca altera pins diretamente
na `main`. O EuroOffice acompanha os releases lean `eurooffice/v*` publicados
pela branch office (consumidor `eurooffice-refresh.yml` na main); o commit privado do
Deetty e os pins acoplados do ZLS/Zig 0.16 continuam mantidos manualmente. Após
a integração de alterações de pacotes, um workflow separado compila e assina o
repositório sem montar uma ISO; alterações somente de pacotes não acionam mais a
montagem P0 da ISO. Esses workflows estão configurados, mas ainda não foram
confirmados verdes nem publicados no release móvel.

`dinx-keyring` configura o repositório `[dinx]` com assinaturas de pacotes
obrigatórias e `/etc/pacman.d/dinx-mirrorlist`. Esse arquivo de mirrors
editável permite que operadores adicionem mirrors futuramente sem alterar a
configuração do repositório. O fingerprint de confiança da chave de assinatura
de produção é `D8F294B7367BD0DAF626E4DCD411E36494CB9CEB`; o SHA-256 esperado do
arquivo da chave pública publicado é
`dcebc6d08e1e46738e768bcd91ece5beb3ef4f8752079f0babba864fb41a6445`.

### Configurar o segredo de assinatura de produção

Antes de habilitar a publicação, um operador confiável de release deve
configurar o segredo do GitHub Actions `DINX_PACKAGE_SIGNING_KEY` com a chave
privada de produção armored sem senha e `DINX_PACKAGE_SIGNING_FINGERPRINT` com
seu fingerprint exato. A chave deve poder ser usada sem interação pelo
`makepkg --sign`. Configure os segredos em uma máquina confiável do operador;
nunca faça commit nem upload da chave privada.

Se `rufl/DEETTY` continuar privado, configure o segredo do Actions
`DEETTY_SOURCE_READ_TOKEN` com acesso Contents somente de leitura a esse
repositório. Os contratos e o publicador precisam dele para buscar a fonte
fixada; o `GITHUB_TOKEN` da DINX só pode ser usado se a política do repositório
conceder esse acesso.

```bash
fingerprint='D8F294B7367BD0DAF626E4DCD411E36494CB9CEB'
gpg --armor --export-secret-keys "$fingerprint" > /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_KEY --repo rufl/DINX < /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_FINGERPRINT --repo rufl/DINX --body "$fingerprint"
shred -u /tmp/dinx-package-signing-key.asc
```

Mantenha separadamente o backup offline da master key e faça rotações
deliberadas. A qualificação P0 usa uma chave CI efêmera, não a chave de
atualização de produção.

### Preparar a confiança dos pacotes

Quando o repositório móvel estiver publicado, mas `dinx-keyring` ainda não
estiver disponível, configure a confiança manualmente no sistema que precisa
dos pacotes. Baixe a chave pública e verifique seu SHA-256 e fingerprint
OpenPGP completo antes de importá-la ou confiar localmente nela:

```bash
set -euo pipefail
repo_url='https://github.com/rufl/DINX/releases/download/dinx-packages-latest'
key=/tmp/dinx-package-signing-key.gpg
curl --fail --location "$repo_url/dinx-package-signing-key.gpg" --output "$key"
printf '%s  %s\n' \
  'dcebc6d08e1e46738e768bcd91ece5beb3ef4f8752079f0babba864fb41a6445' "$key" |
  sha256sum --check
gpg --show-keys --with-colons "$key" |
  awk -F: '$1 == "fpr" { print $10; exit }' |
  grep --fixed-strings --line-regexp 'D8F294B7367BD0DAF626E4DCD411E36494CB9CEB'
sudo pacman-key --add "$key"
sudo pacman-key --lsign-key D8F294B7367BD0DAF626E4DCD411E36494CB9CEB
```

Adicione o repositório a `/etc/pacman.conf`, depois dos repositórios Artix:

```ini
[dinx]
SigLevel = Required
Include = /etc/pacman.d/dinx-mirrorlist
```

Crie `/etc/pacman.d/dinx-mirrorlist` com a URL móvel do release:

```ini
Server = https://github.com/rufl/DINX/releases/download/dinx-packages-latest
```

Atualize os bancos e instale o keyring quando estiver disponível:

```bash
sudo pacman -Syu --needed dinx-keyring
```

Depois da configuração, o Shelly usa pacman e o repositório `[dinx]` para
atualizar pacotes: execute `shelly sync`, confira com `shelly list-updates all`
e aplique com `shelly upgrade all` (ou `sudo pacman -Syu`). As assinaturas
obrigatórias fazem o pacman rejeitar pacotes não assinados ou não confiáveis.

O workflow de releases marcados atualmente documentado também pode anexar assets
de repositório assinado a um release da ISO. Esses assets não significam que o
repositório móvel separado ou seu workflow de atualização já tenham sido
publicados.

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

O builder P0 assina seu repositório pacman temporário e registra o snapshot, o
checksum do banco, o checksum da chave pública e o fingerprint da assinatura
nos metadados do build. Essa qualificação é distinta do repositório móvel
planejado. Configure os segredos de assinatura de produção antes de habilitar
esse caminho de publicação; ele publica alterações de pacotes
independentemente da ISO após a integração de mudanças revisadas nos pins das
origens.

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

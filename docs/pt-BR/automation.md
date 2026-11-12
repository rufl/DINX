# Automação de pacotes, segurança e ISO

A `main` usa quatro automações independentes, todas com concorrência controlada:

- **Prefetch upstream:** `.github/workflows/upstream-cache-prefetch.yml` roda às `04:17` e `16:17` UTC. O workflow resolve os pacotes do builder e das imagens DINX, remove os pacotes produzidos pelo próprio repositório, executa `pacman -Syy`/`pacman -Sw --needed` dentro do Artix fixado e salva somente a cache delta verificada.
- **Renovação de fontes:** `.github/workflows/upstream-package-refresh.yml` consulta os releases upstream diariamente às `03:17` UTC. Alterações são checksumadas, testadas e abertas como PR; o workflow não grava pins diretamente na `main`.
- **Auditoria de dependências:** `.github/workflows/security-scan.yml` roda em PR, push da `main`, manualmente e diariamente às `01:17` UTC. Gera SBOM SPDX e executa Grype, Trivy e OSV-Scanner. Achados High/Critical bloqueiam o job; o Trivy ignora achados sem correção publicada por política. Os relatórios SARIF ficam no Code Scanning e os artefatos permanecem 30 dias.
- **ISO noturna:** `.github/workflows/p0-iso.yml` roda às `02:17` UTC, uma vez por dia. O build restaura a cache upstream, compila a ISO e só atesta/envia o artefato do workflow após os gates P0, SBOM/scan do rootfs final, boot QEMU e instalação descartável. O artefato fica disponível por 14 dias.

## Cache

`dist/.cache/dinx/pacman/pkg` é uma categoria própria. A cache de artefatos DINX, fontes/Cargo/Zig e toolchains tem chaves separadas. A cache upstream usa prefixo por arquitetura e conjunto de pacotes; cada execução salva uma chave nova, permitindo que a restauração escolha o snapshot mais recente sem sobrescrever cache imutável do Actions.

O modo local sem `pacman` mantém o build possível e emite aviso. O prefetch CI usa `--strict` e falha quando a base Artix não pode atualizar bancos ou baixar um pacote.

## Limites de segurança

Checksums, assinaturas pacman e atestações demonstram integridade e procedência; não demonstram ausência de CVE. Grype/Trivy/OSV cobrem o que seus catálogos reconhecem. A auditoria do rootfs final é adicional à auditoria dos manifests de fonte. Um resultado sem vulnerabilidades deve ser interpretado dentro dessas coberturas e da política de severidade do workflow.

# Changelog

Este arquivo registra as mudanças importantes da DINX em linguagem direta. Ele não afirma que o roadmap terminou; a evidência de qualificação e os metadados do release são a fonte de verdade.

## Não lançado

- Adicionada compressão SquashFS determinística com xz, filtro BCJ x86 e orçamento P0 estrito abaixo do limite de 2 GiB por asset do GitHub para futuros releases com ISO única. A Alpha 8 continua dividida porque foi construída antes desta mudança.
- Reduzido o payload da imagem completa com um manifesto comum compacto versionado no repositório: o caminho AMDGPU documentado continua incluído, enquanto firmware genérico, headers do kernel e `powertop` ficam para instalação posterior de pacotes.

## v0.1.0-alpha.8 — 2026-10-21

- Publicado o alpha público atual da DINX para Artix Linux x86_64 com dinit: [release no GitHub](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- A execução de release com tag [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), no commit `eea66ac`, passou os contratos de pacotes e ISO, boot em QEMU, validação do payload gráfico, smokes transacionais BIOS/UEFI/Btrfs do Calamares, smokes de instalação persistente/TTY de recuperação em discos descartáveis, verificação dos metadados de build, assinatura persistente de pacotes, atestação e publicação do release.
- Publicadas as partes da ISO, checksum SHA-512, metadados de build, pacote Windows para QEMU, repositório DINX assinado e assets de verificação.
- Tamanho publicado da ISO: `2.803.349.504` bytes. SHA-512 completo: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Snapshot publicado do repositório DINX assinado: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Atualizadas as páginas de entrada em inglês e português e a documentação de release para apontarem para a Alpha 8.

### Limites conhecidos

Este continua sendo um alpha público. Hardware físico, uma sessão gaming DRM real, Steam autenticado e launch de jogo comercial, entrada de controle, áudio PipeWire do jogo, suspensão/retomada, recuperação da GPU, Secure Boot e atualização/rollback da ISO instalada continuam fora da afirmação do release.

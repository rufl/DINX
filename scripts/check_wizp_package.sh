#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkgdir="$root/distro/packages/wizp"
pkgbuild="$pkgdir/PKGBUILD"
desktop="$pkgdir/resources/wizp.desktop"
icon="$pkgdir/resources/dev.wizp.WIZP.svg"
readme="$pkgdir/README.md"

fail() {
  printf 'wizp_package_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$desktop" "$icon" "$readme"; do
  [[ -r "$path" ]] || fail "missing package input: $path"
done

grep -Fqx 'pkgname=wizp' "$pkgbuild" || fail 'PKGBUILD package name is not wizp'
grep -Fq 'WIZP_PACKAGE_DIR' "$pkgbuild" || fail 'PKGBUILD does not require the exact self-contained package directory'
grep -Fq 'libcef.so' "$pkgbuild" || fail 'PKGBUILD does not require bundled CEF'
grep -Fq '/opt/wizp' "$pkgbuild" || fail 'PKGBUILD does not isolate the bundled runtime under /opt/wizp'
grep -Fqx 'Exec=wizp %F' "$desktop" || fail 'desktop entry does not forward file arguments'
grep -Fqx 'Icon=dev.wizp.WIZP' "$desktop" || fail 'desktop entry icon identity is incorrect'
grep -Fq 'MimeType=text/plain;' "$desktop" || fail 'desktop entry lacks explicit text MIME handling'
grep -Fq 'does not claim binary, image, archive, or arbitrary MIME handling' "$readme" || fail 'README overclaims file handling'
grep -Fq '<svg ' "$icon" || fail 'WIZP icon is not SVG'

printf 'wizp_package_contract metadata=true bundled_cef=true file_args=true text_mime_scope=true staged_source_required=true\n'

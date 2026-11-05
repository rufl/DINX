#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
archive_root="$tmp/archive/zig-0.17.0"
mkdir -p "$archive_root"
cat > "$archive_root/zig" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == version ]] || exit 2
printf '%s\n' 0.17.0
EOF
chmod +x "$archive_root/zig"
archive="$tmp/zig.tar.xz"
tar -cJf "$archive" -C "$tmp/archive" zig-0.17.0
sha256=$(sha256sum "$archive" | cut -d ' ' -f 1)
destination="$tmp/cache/extracted/zig-0.17.0-$sha256"
dirty_marker="$tmp/cache/build-data-updated"

DINX_CACHE_DIRTY_MARKER="$dirty_marker" \
  "$root/scripts/cache-verified-extract.sh" "$archive" "$sha256" 0.17.0 zig "$destination"
[[ -f "$dirty_marker" ]] || { printf 'smoke_cache_verified_extract: cold extraction did not mark cache changes\n' >&2; exit 1; }
rm -f -- "$dirty_marker"
"$root/scripts/cache-verified-extract.sh" "$archive" "$sha256" 0.17.0 zig "$destination"
[[ ! -e "$dirty_marker" ]] || { printf 'smoke_cache_verified_extract: cache hit marked cache changes\n' >&2; exit 1; }

printf '#!/usr/bin/env bash\n[[ ${1:-} == version ]] || exit 2\nprintf "0.17.1\\n"\n' \
  > "$destination/zig"
chmod +x "$destination/zig"
rm -f -- "$dirty_marker"
DINX_CACHE_DIRTY_MARKER="$dirty_marker" \
  "$root/scripts/cache-verified-extract.sh" "$archive" "$sha256" 0.17.0 zig "$destination"
[[ -f "$dirty_marker" ]] || { printf 'smoke_cache_verified_extract: recovery extraction did not mark cache changes\n' >&2; exit 1; }
[[ $("$destination/zig" version) == 0.17.0 ]]

rm -f -- "$dirty_marker"
if "$root/scripts/cache-verified-extract.sh" "$archive" "$(printf '0%.0s' {1..64})" \
  0.17.0 zig "$destination" >/dev/null 2>&1; then
  printf 'smoke_cache_verified_extract: bad archive checksum was accepted\n' >&2
  exit 1
fi
[[ -x "$destination/zig" ]]
[[ ! -e "$dirty_marker" ]] || { printf 'smoke_cache_verified_extract: rejected archive marked cache changes\n' >&2; exit 1; }
printf 'smoke_cache_verified_extract: verified extraction, hit, corruption recovery and checksum rejection passed\n'

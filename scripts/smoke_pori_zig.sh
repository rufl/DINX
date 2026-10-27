#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$root/distro/packages/pori/source.env"
zig_bin=${ZIG:-zig}
command -v "$zig_bin" >/dev/null 2>&1 || {
  printf 'smoke_pori_zig: missing Zig compiler: %s\n' "$zig_bin" >&2
  exit 1
}
expected_zig_version=0.17.0
zig_version=$("$zig_bin" version)
[[ "$zig_version" == "$expected_zig_version" ]] || {
  printf 'smoke_pori_zig: expected Zig %s, found %s\n' "$expected_zig_version" "$zig_version" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

archive="$tmp/pori-${PORI_VERSION}.tar.gz"
curl --fail --silent --show-error --location --retry 3 \
  --output "$archive" \
  "${PORI_REPOSITORY}/archive/refs/tags/v${PORI_VERSION}.tar.gz"
printf '%s  %s\n' "$PORI_SOURCE_SHA256" "$archive" | sha256sum -c - >/dev/null
tar -xzf "$archive" -C "$tmp"

mkdir -p "$tmp/src/services" "$tmp/src/helpers"
cp -a "$tmp/Pori-${PORI_VERSION}/Pori.Ui/src/helpers/." "$tmp/src/helpers/"
for source in privops-dinit units-dinit watch-dinit; do
  install -Dm644 "$root/distro/packages/pori/${source}.zig" "$tmp/src/services/${source}.zig"
done
cat > "$tmp/src/services/devices.zig" <<'EOF'
pub const Device = struct {
    name: []const u8,
    path: []const u8,
    dev: []const u8,
    fs_type: []const u8,
    fs_version: []const u8,
    label: []const u8,
    uuid: []const u8,
    size: u64,
    read_only: bool,
    mount_points: []const []const u8,
    parent: []const u8,
    parent_size: u64,
    table_type: []const u8,
    partition_number: u32,
    partition_count: u32,
};
EOF

cat > "$tmp/src/main.zig" <<'EOF'
const privops = @import("services/privops-dinit.zig");
const units = @import("services/units-dinit.zig");
const watch = @import("services/watch-dinit.zig");

comptime {
    _ = privops;
    _ = units;
    _ = watch;
}
EOF

"$zig_bin" test "$tmp/src/main.zig" \
  --cache-dir "$tmp/zig-cache" \
  --global-cache-dir "$tmp/zig-global-cache"
printf 'pori_zig_smoke version=%s source_pinned=true privops=true units=true watch=true\n' "$PORI_VERSION"

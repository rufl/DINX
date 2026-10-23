#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
zls_bin=${ZLS_BIN:-/usr/bin/zls}
zig_shim=${ZLS_ZIG_SHIM:-/usr/lib/zls/zig-env}
[[ -x "$zls_bin" ]] || { printf 'smoke_zls: missing executable: %s\n' "$zls_bin" >&2; exit 1; }
[[ -x "$zig_shim" ]] || { printf 'smoke_zls: missing Zig shim: %s\n' "$zig_shim" >&2; exit 1; }

source "$repo_root/distro/packages/zls/source.env"
version=$($zls_bin --version)
[[ "$version" == "$ZLS_VERSION" ]] || {
  printf 'smoke_zls: expected ZLS %s, got %s\n' "$ZLS_VERSION" "$version" >&2
  exit 1
}
[[ "$($zig_shim version)" == "$ZIG_VERSION" ]] || {
  printf 'smoke_zls: Zig shim version mismatch\n' >&2
  exit 1
}
config=$($zls_bin env)
grep -Fqx ' "config_file": "/etc/xdg/zls.json",' <<<"$config" \
  || { printf 'smoke_zls: global ZLS config was not selected\n' >&2; exit 1; }
zig_env=$($zig_shim env)
grep -Fq '.std_dir = "/usr/lib/zls/zig/std"' <<<"$zig_env" \
  || { printf 'smoke_zls: bundled Zig standard library was not selected\n' >&2; exit 1; }

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
text='const std = @import("std");
const x = std.
'
initialize=$(jq -cn --arg uri "file://$tmp_dir" '{jsonrpc:"2.0",id:1,method:"initialize",params:{processId:null,rootUri:$uri,capabilities:{}}}')
initialized=$(jq -cn '{jsonrpc:"2.0",method:"initialized",params:{}}')
did_open=$(jq -cn --arg uri "file://$tmp_dir/main.zig" --arg text "$text" '{jsonrpc:"2.0",method:"textDocument/didOpen",params:{textDocument:{uri:$uri,languageId:"zig",version:1,text:$text}}}')
completion=$(jq -cn --arg uri "file://$tmp_dir/main.zig" '{jsonrpc:"2.0",id:2,method:"textDocument/completion",params:{textDocument:{uri:$uri},position:{line:1,character:15}}}')
send() {
  local json=$1
  printf 'Content-Length: %s\r\n\r\n%s' "$(printf %s "$json" | wc -c)" "$json"
}
{
  send "$initialize"
  send "$initialized"
  send "$did_open"
  sleep 1
  send "$completion"
  sleep 3
} | timeout 12 "$zls_bin" --disable-lsp-logs > "$tmp_dir/lsp.out" 2> "$tmp_dir/lsp.err" || true
grep -Fq '"id":1' "$tmp_dir/lsp.out" || { cat "$tmp_dir/lsp.err" >&2; exit 1; }
grep -Fq '"id":2' "$tmp_dir/lsp.out" || { cat "$tmp_dir/lsp.err" >&2; exit 1; }
grep -Fq '"label"' "$tmp_dir/lsp.out" || { cat "$tmp_dir/lsp.err" >&2; exit 1; }
printf 'zls_smoke version=%s stdlib=true initialize=true completion=true systemd=false\n' "$version"

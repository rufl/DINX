#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s RELEASE_TAG [--apply]\n' "$0" >&2
  printf 'environment: ZTASH_ENDPOINT, ZEER_TOKEN_FILE, ZEER_BIN, DINX_GITHUB_REPO\n' >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
release_tag=$1
apply=false
if [[ ${2:-} == --apply ]]; then
  apply=true
elif [[ $# -eq 2 ]]; then
  usage
fi
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9._-]+$ ]] || {
  printf 'deploy-ztash: RELEASE_TAG must look like v0.1.0-alpha.1\n' >&2
  exit 1
}

repo=${DINX_GITHUB_REPO:-rufl/DINX}
endpoint=${ZTASH_ENDPOINT:-https://ddjarin.tail8302a.ts.net}
token_file=${ZEER_TOKEN_FILE:-$HOME/.config/overzeer/ddjarin-agent.token}
zeer_bin=${ZEER_BIN:-}
if [[ -z "$zeer_bin" ]]; then
  if command -v zeer >/dev/null 2>&1; then
    zeer_bin=$(command -v zeer)
  elif [[ -x "$HOME/.local/lib/zeer/zeer" ]]; then
    zeer_bin="$HOME/.local/lib/zeer/zeer"
  else
    printf 'deploy-ztash: zeer binary not found; set ZEER_BIN\n' >&2
    exit 1
  fi
fi
command -v gh >/dev/null 2>&1 || {
  printf 'deploy-ztash: gh is required to read release metadata\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'deploy-ztash: jq is required\n' >&2
  exit 1
}
[[ -r "$token_file" ]] || {
  printf 'deploy-ztash: token file is not readable: %s\n' "$token_file" >&2
  exit 1
}

release_version=${release_tag#v}
package_version="${release_version}-dogfood.1"
metadata_name="dinx-${package_version}-windows-x86_64.json"
metadata_dir=$(mktemp -d)
trap 'rm -rf "$metadata_dir"' EXIT
gh release download "$release_tag" --repo "$repo" --pattern "$metadata_name" --dir "$metadata_dir" --clobber >/dev/null
metadata_path="$metadata_dir/$metadata_name"
[[ -s "$metadata_path" ]] || {
  printf 'deploy-ztash: missing release metadata: %s\n' "$metadata_name" >&2
  exit 1
}

application=$(jq -er '.application' "$metadata_path")
channel=$(jq -er '.channel' "$metadata_path")
version=$(jq -er '.version' "$metadata_path")
build_id=$(jq -er '.build_id' "$metadata_path")
target=$(jq -er '.target' "$metadata_path")
artifact_url=$(jq -er '.url' "$metadata_path")
artifact_sha256=$(jq -er '.sha256' "$metadata_path")
artifact_bytes=$(jq -er '.size' "$metadata_path")
[[ "$application" == dinx && "$channel" == dogfood && "$version" == "$package_version" ]] || {
  printf 'deploy-ztash: release metadata is not the expected DINX dogfood package\n' >&2
  exit 1
}
[[ "$target" == windows-x86_64 ]] || {
  printf 'deploy-ztash: unsupported target: %s\n' "$target" >&2
  exit 1
}
[[ "$artifact_url" == https://* ]] || {
  printf 'deploy-ztash: artifact URL must use HTTPS\n' >&2
  exit 1
}
[[ "$artifact_sha256" =~ ^[0-9a-fA-F]{64}$ ]] || {
  printf 'deploy-ztash: metadata SHA-256 is invalid\n' >&2
  exit 1
}
[[ "$artifact_bytes" =~ ^[1-9][0-9]*$ ]] || {
  printf 'deploy-ztash: metadata size is invalid\n' >&2
  exit 1
}

args=(
  ztash assign
  --endpoint "$endpoint"
  --device-id ddjarin
  --update-id "dinx-${version}"
  --application "$application"
  --version "$version"
  --build-id "$build_id"
  --target "$target"
  --artifact-url "$artifact_url"
  --artifact-sha256 "$artifact_sha256"
  --artifact-bytes "$artifact_bytes"
  --update-kind dogfood
  --dogfood-mode launch
  --execution-seconds 180
  --token-file "$token_file"
)
if "$apply"; then
  args+=(--apply)
  export ZEER_CONFIRM=DEPLOY
fi
printf 'deploy-ztash: %s %s\n' "$zeer_bin" "${args[*]}"
"$zeer_bin" "${args[@]}"

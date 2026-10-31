#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mock_bin="$tmp_dir/bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$MOCK_GH_LOG"
printf '\n' >>"$MOCK_GH_LOG"

if [[ "$1" == api ]]; then
  endpoint=''
  for argument in "${@:2}"; do
    [[ "$argument" == repos/* ]] && endpoint=$argument
  done
  if [[ " $* " == *' --paginate '* ]]; then
    count_file="$MOCK_STATE_DIR/list-attempts"
    count=0
    [[ ! -f "$count_file" ]] || read -r count <"$count_file"
    count=$((count + 1))
    printf '%s\n' "$count" >"$count_file"
    if (( count <= MOCK_LATEST_OLD_QUERIES )); then
      printf '%s\n' "$MOCK_PREVIOUS_RELEASES_JSON"
    else
      printf '%s\n' "$MOCK_LATEST_RELEASES_JSON"
    fi
    exit 0
  fi
  case "$endpoint" in
    "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}")
      count_file="$MOCK_STATE_DIR/release-attempts"
      count=0
      [[ ! -f "$count_file" ]] || read -r count <"$count_file"
      count=$((count + 1))
      printf '%s\n' "$count" >"$count_file"
      if (( count <= MOCK_RELEASE_404S )); then
        printf 'gh: Not Found (HTTP 404)\n' >&2
        exit 1
      fi
      printf '%s\n' "$MOCK_RELEASE_JSON"
      ;;
    "repos/${GITHUB_REPOSITORY}/commits/${RELEASE_TAG}")
      printf '{"sha":"0123456789012345678901234567890123456789"}\n'
      ;;
    "repos/${GITHUB_REPOSITORY}/git/ref/tags/alpha-latest")
      if [[ "$MOCK_ALIAS_MISSING" == true ]]; then
        printf 'gh: Not Found (HTTP 404)\n' >&2
        exit 1
      fi
      printf '{"ref":"refs/tags/alpha-latest"}\n'
      ;;
    "repos/${GITHUB_REPOSITORY}/git/refs/tags/alpha-latest"|"repos/${GITHUB_REPOSITORY}/git/refs")
      printf '{}\n'
      ;;
    *)
      printf 'mock gh: unexpected API endpoint: %s\n' "$endpoint" >&2
      exit 2
      ;;
  esac
  exit 0
fi

if [[ "$1" == release ]]; then
  action=${2:-}
  case "$action" in
    download)
      tag=${3:-}
      [[ "$tag" == "$RELEASE_TAG" ]] || { printf 'unexpected release tag: %s\n' "$tag" >&2; exit 2; }
      shift 3
      pattern=''
      directory=''
      while (($#)); do
        case "$1" in
          --repo) shift 2 ;;
          --pattern) pattern=$2; shift 2 ;;
          --dir) directory=$2; shift 2 ;;
          *) printf 'unexpected release download argument: %s\n' "$1" >&2; exit 2 ;;
        esac
      done
      [[ "$pattern" == "dinx-${RELEASE_TAG#v}-x86_64.iso" && -n "$directory" ]]
      printf 'fixture ISO bytes\n' >"$directory/$pattern"
      ;;
    view)
      if [[ "$MOCK_ALIAS_MISSING" == true ]]; then
        printf 'gh: Not Found (HTTP 404)\n' >&2
        exit 1
      fi
      ;;
    edit|create)
      ;;
    upload)
      shift 3
      asset_path=''
      while (($#)); do
        case "$1" in
          --repo) shift 2 ;;
          --clobber) shift ;;
          *)
            [[ -s "$1" ]] || { printf 'missing upload asset: %s\n' "$1" >&2; exit 2; }
            asset_path=$1
            shift
            ;;
        esac
      done
      [[ -n "$asset_path" ]] || { printf 'missing upload asset path\n' >&2; exit 2; }
      if [[ "$asset_path" == *.iso ]]; then
        upload_kind=iso
        upload_404s=${MOCK_UPLOAD_ISO_404S:-0}
      else
        upload_kind=sha512
        upload_404s=${MOCK_UPLOAD_SHA512_404S:-0}
      fi
      upload_count_file="$MOCK_STATE_DIR/upload-$upload_kind-attempts"
      upload_count=0
      [[ ! -f "$upload_count_file" ]] || read -r upload_count <"$upload_count_file"
      upload_count=$((upload_count + 1))
      printf '%s\n' "$upload_count" >"$upload_count_file"
      if (( upload_count <= upload_404s )); then
        printf 'gh: Not Found (HTTP 404)\n' >&2
        exit 1
      fi
      ;;
    *)
      printf 'mock gh: unexpected release action: %s\n' "$action" >&2
      exit 2
      ;;
  esac
  exit 0
fi

printf 'mock gh: unexpected command: %s\n' "$*" >&2
exit 2
MOCK_GH

cat >"$mock_bin/sleep" <<'MOCK_SLEEP'
#!/usr/bin/env bash
exit 0
MOCK_SLEEP
chmod +x "$mock_bin/gh" "$mock_bin/sleep"

release_tag=v0.1.0-alpha.11
repo=rufl/DINX
release_json=$(printf '{"tag_name":"%s","prerelease":true,"draft":false,"published_at":"2026-10-31T06:03:49Z","assets":[{"name":"dinx-0.1.0-alpha.11-x86_64.iso","size":1024}]}' "$release_tag")
old_releases='[{"tag_name":"v0.1.0-alpha.10","prerelease":true,"draft":false,"published_at":"2026-10-30T06:03:49Z"}]'
current_releases='[{"tag_name":"v0.1.0-alpha.11","prerelease":true,"draft":false,"published_at":"2026-10-31T06:03:49Z"}]'
newer_releases='[{"tag_name":"v0.1.0-alpha.12","prerelease":true,"draft":false,"published_at":"2026-11-01T06:03:49Z"}]'

run_helper() {
  local scenario=$1
  shift
  env \
    RELEASE_TAG="$release_tag" \
    GITHUB_REPOSITORY="$repo" \
    RUNNER_TEMP="$scenario/tmp" \
    MOCK_GH_LOG="$scenario/gh.log" \
    MOCK_STATE_DIR="$scenario/state" \
    MOCK_RELEASE_JSON="$release_json" \
    PATH="$mock_bin:$PATH" \
    "$@" \
    "$root/scripts/publish_latest_alpha_alias.sh"
}

successful="$tmp_dir/success"
mkdir -p "$successful/tmp" "$successful/state"
if output=$(run_helper "$successful" \
  MOCK_RELEASE_404S=2 \
  MOCK_UPLOAD_ISO_404S=2 \
  MOCK_UPLOAD_SHA512_404S=1 \
  MOCK_LATEST_OLD_QUERIES=2 \
  MOCK_PREVIOUS_RELEASES_JSON="$old_releases" \
  MOCK_LATEST_RELEASES_JSON="$current_releases" \
  MOCK_ALIAS_MISSING=false 2>&1); then
  :
else
  printf 'smoke_latest_alpha_alias: expected eventual publication visibility to recover\n%s\n' "$output" >&2
  exit 1
fi
[[ $(<"$successful/state/release-attempts") == 3 ]]
[[ $(<"$successful/state/list-attempts") == 3 ]]
[[ $(<"$successful/state/upload-iso-attempts") == 3 ]]
[[ $(<"$successful/state/upload-sha512-attempts") == 2 ]]
grep -Fq 'retrying in 5s' <<<"$output"
alias_dir="$successful/tmp/dinx-latest-alpha"
[[ -s "$alias_dir/dinx-latest-x86_64.iso" ]]
(cd "$alias_dir" && sha512sum --check dinx-latest-x86_64.iso.sha512 >/dev/null)
grep -Fq 'release upload' "$successful/gh.log"
printf 'latest_alpha_alias_smoke publication_retry=true listing_retry=true upload_retry=true checksum=true upload=true\n'

stale="$tmp_dir/stale"
mkdir -p "$stale/tmp" "$stale/state"
output=$(run_helper "$stale" \
  MOCK_RELEASE_404S=0 \
  MOCK_LATEST_OLD_QUERIES=0 \
  MOCK_PREVIOUS_RELEASES_JSON="$newer_releases" \
  MOCK_LATEST_RELEASES_JSON="$newer_releases" \
  MOCK_ALIAS_MISSING=false 2>&1)
grep -Fq 'Skipping stale alpha' <<<"$output"
if grep -Fq 'release download' "$stale/gh.log"; then
  printf 'smoke_latest_alpha_alias: stale alpha unexpectedly downloaded or mutated the alias\n' >&2
  exit 1
fi
printf 'latest_alpha_alias_smoke stale_release_no_mutation=true\n'

missing="$tmp_dir/missing"
mkdir -p "$missing/tmp" "$missing/state"
if output=$(run_helper "$missing" \
  MOCK_RELEASE_404S=0 \
  MOCK_LATEST_OLD_QUERIES=0 \
  MOCK_PREVIOUS_RELEASES_JSON="$current_releases" \
  MOCK_LATEST_RELEASES_JSON="$current_releases" \
  MOCK_ALIAS_MISSING=true 2>&1); then
  :
else
  printf 'smoke_latest_alpha_alias: first alias publication failed\n%s\n' "$output" >&2
  exit 1
fi
grep -Fq 'api --method POST' "$missing/gh.log"
grep -Fq 'release create alpha-latest' "$missing/gh.log"
printf 'latest_alpha_alias_smoke missing_alias_create=true\n'

upload_unavailable="$tmp_dir/upload-unavailable"
mkdir -p "$upload_unavailable/tmp" "$upload_unavailable/state"
if output=$(run_helper "$upload_unavailable" \
  MOCK_RELEASE_404S=0 \
  MOCK_UPLOAD_ISO_404S=99 \
  MOCK_LATEST_OLD_QUERIES=0 \
  MOCK_PREVIOUS_RELEASES_JSON="$current_releases" \
  MOCK_LATEST_RELEASES_JSON="$current_releases" \
  MOCK_ALIAS_MISSING=false 2>&1); then
  printf 'smoke_latest_alpha_alias: permanently missing alias release unexpectedly uploaded\n' >&2
  exit 1
fi
grep -Fq 'remained unavailable for dinx-latest-x86_64.iso after 6 attempts' <<<"$output"
[[ $(<"$upload_unavailable/state/upload-iso-attempts") == 6 ]]
[[ ! -f "$upload_unavailable/state/upload-sha512-attempts" ]]
printf 'latest_alpha_alias_smoke upload_retry_bound=true permanent_404_rejected=true\n'

unavailable="$tmp_dir/unavailable"
mkdir -p "$unavailable/tmp" "$unavailable/state"
if output=$(run_helper "$unavailable" \
  MOCK_RELEASE_404S=99 \
  MOCK_LATEST_OLD_QUERIES=0 \
  MOCK_PREVIOUS_RELEASES_JSON="$current_releases" \
  MOCK_LATEST_RELEASES_JSON="$current_releases" \
  MOCK_ALIAS_MISSING=false 2>&1); then
  printf 'smoke_latest_alpha_alias: permanently missing release unexpectedly succeeded\n' >&2
  exit 1
fi
grep -Fq 'remained unavailable after 6 attempts' <<<"$output"
[[ $(<"$unavailable/state/release-attempts") == 6 ]]
if grep -Fq 'release download' "$unavailable/gh.log"; then
  printf 'smoke_latest_alpha_alias: downloaded assets before validating the release\n' >&2
  exit 1
fi
printf 'latest_alpha_alias_smoke retry_bound=true permanent_404_rejected=true\n'

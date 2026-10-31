#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

fail() {
  printf 'publish_latest_alpha_alias: %s\n' "$*" >&2
  exit 1
}

[[ "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9._-]+$ ]] \
  || fail "invalid prerelease tag: $RELEASE_TAG"

api_with_publication_retry() {
  local endpoint=$1
  local description=$2
  local attempt response error_file status
  error_file=$(mktemp "$RUNNER_TEMP/dinx-release-api.XXXXXX")
  for attempt in 1 2 3 4 5 6; do
    if response=$(gh api "$endpoint" 2>"$error_file"); then
      [[ ! -s "$error_file" ]] || cat "$error_file" >&2
      rm -f "$error_file"
      printf '%s\n' "$response"
      return 0
    else
      status=$?
    fi
    if ! grep -Fq '(HTTP 404)' "$error_file"; then
      cat "$error_file" >&2
      rm -f "$error_file"
      return "$status"
    fi
    if (( attempt == 6 )); then
      printf 'publish_latest_alpha_alias: %s remained unavailable after %s attempts\n' \
        "$description" "$attempt" >&2
      cat "$error_file" >&2
      rm -f "$error_file"
      return "$status"
    fi
    printf 'publish_latest_alpha_alias: %s is not visible yet (404, attempt %s/6); retrying in 5s\n' \
      "$description" "$attempt" >&2
    sleep 5
  done
  rm -f "$error_file"
  return 1
}

release_api_path="repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}"
echo "Reading published release $RELEASE_TAG."
release_json=$(api_with_publication_retry "$release_api_path" "release $RELEASE_TAG")
jq -e '.prerelease == true and (.draft | not)' <<<"$release_json" >/dev/null \
  || fail "$RELEASE_TAG is not a published prerelease"
release_published_epoch=$(jq -er '.published_at | fromdateiso8601' <<<"$release_json") \
  || fail "$RELEASE_TAG has no valid publication timestamp"

version="${RELEASE_TAG#v}"
versioned_iso="dinx-${version}-x86_64.iso"
alias_iso="dinx-latest-x86_64.iso"
alias_tag=alpha-latest
asset_count=$(jq --arg name "$versioned_iso" '[.assets[] | select(.name == $name)] | length' <<<"$release_json")
[[ "$asset_count" == 1 ]] || fail "release $RELEASE_TAG must contain exactly one $versioned_iso asset"
asset_size=$(jq -r --arg name "$versioned_iso" '.assets[] | select(.name == $name) | .size' <<<"$release_json")
[[ "$asset_size" =~ ^[0-9]+$ ]] || fail "release $RELEASE_TAG has an invalid ISO asset size"
(( asset_size < 2147483648 )) \
  || fail "release $RELEASE_TAG ISO exceeds GitHub's 2 GiB per-asset limit"

latest_alpha_json='{}'
latest_alpha_tag=''
for attempt in 1 2 3 4 5 6; do
  echo "Checking newest published alpha (attempt $attempt/6)."
  latest_alpha_json=$(
    gh api --paginate "repos/${GITHUB_REPOSITORY}/releases?per_page=100" \
      | jq -s -c '
          flatten
          | map(select(
              .prerelease
              and (.draft | not)
              and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+-"))
            ))
          | sort_by(.published_at)
          | last // {}
        '
  )
  latest_alpha_tag=$(jq -r '.tag_name // empty' <<<"$latest_alpha_json")
  if [[ "$latest_alpha_tag" == "$RELEASE_TAG" ]]; then
    break
  fi
  latest_alpha_published=$(jq -r '.published_at // empty' <<<"$latest_alpha_json")
  if [[ -n "$latest_alpha_published" ]]; then
    latest_alpha_epoch=$(jq -er '.published_at | fromdateiso8601' <<<"$latest_alpha_json") \
      || fail 'GitHub returned an invalid latest-alpha publication timestamp'
    if (( latest_alpha_epoch > release_published_epoch )); then
      echo "Skipping stale alpha $RELEASE_TAG; newer published alpha is $latest_alpha_tag."
      exit 0
    fi
  fi
  if (( attempt == 6 )); then
    fail "GitHub release listing did not expose $RELEASE_TAG or a newer alpha after $attempt attempts"
  fi
  echo "Release listing has not caught up with $RELEASE_TAG; retrying in 5s."
  sleep 5
done

alias_dir="$RUNNER_TEMP/dinx-latest-alpha"
mkdir -p "$alias_dir"
download_error_file=$(mktemp "$RUNNER_TEMP/dinx-release-download.XXXXXX")
downloaded=false
for attempt in 1 2 3 4 5 6; do
  echo "Downloading $versioned_iso (attempt $attempt/6)."
  if gh release download "$RELEASE_TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --pattern "$versioned_iso" \
    --dir "$alias_dir" 2>"$download_error_file"; then
    [[ ! -s "$download_error_file" ]] || cat "$download_error_file" >&2
    downloaded=true
    break
  else
    status=$?
  fi
  if ! grep -Fq '(HTTP 404)' "$download_error_file"; then
    cat "$download_error_file" >&2
    rm -f "$download_error_file"
    return_code=$status
    exit "$return_code"
  fi
  rm -f "$alias_dir/$versioned_iso"
  if (( attempt == 6 )); then
    printf 'publish_latest_alpha_alias: asset %s remained unavailable after %s attempts\n' \
      "$versioned_iso" "$attempt" >&2
    cat "$download_error_file" >&2
    rm -f "$download_error_file"
    exit "$status"
  fi
  printf 'publish_latest_alpha_alias: asset %s is not downloadable yet (404, attempt %s/6); retrying in 5s\n' \
    "$versioned_iso" "$attempt" >&2
  sleep 5
done
rm -f "$download_error_file"
[[ "$downloaded" == true && -s "$alias_dir/$versioned_iso" ]] \
  || fail "GitHub did not download a non-empty $versioned_iso asset"
cp "$alias_dir/$versioned_iso" "$alias_dir/$alias_iso"
iso_sha512=$(sha512sum "$alias_dir/$alias_iso" | cut -d ' ' -f 1)
printf '%s  %s\n' "$iso_sha512" "$alias_iso" > "$alias_dir/$alias_iso.sha512"

commit_sha=$(api_with_publication_retry \
  "repos/${GITHUB_REPOSITORY}/commits/${RELEASE_TAG}" "commit for $RELEASE_TAG" \
  | jq -er '.sha')
alias_ref="repos/${GITHUB_REPOSITORY}/git/ref/tags/${alias_tag}"
alias_update_ref="repos/${GITHUB_REPOSITORY}/git/refs/tags/${alias_tag}"
ref_error_file=$(mktemp "$RUNNER_TEMP/dinx-release-ref.XXXXXX")
echo "Updating rolling tag $alias_tag."
if gh api "$alias_ref" >/dev/null 2>"$ref_error_file"; then
  gh api --method PATCH "$alias_update_ref" \
    --field "sha=$commit_sha" \
    --field force=true >/dev/null
else
  status=$?
  if grep -Fq '(HTTP 404)' "$ref_error_file"; then
    gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" \
      --field "ref=refs/tags/${alias_tag}" \
      --field "sha=$commit_sha" >/dev/null
  else
    cat "$ref_error_file" >&2
    rm -f "$ref_error_file"
    exit "$status"
  fi
fi
rm -f "$ref_error_file"

release_url="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${RELEASE_TAG}"
cat > "$alias_dir/notes.md" <<EOF
# DINX latest alpha ISO

Rolling direct-download alias for [${RELEASE_TAG}](${release_url}).

- ISO: \`${alias_iso}\`
- SHA-512: \`${iso_sha512}\`
EOF

release_error_file=$(mktemp "$RUNNER_TEMP/dinx-release-alias.XXXXXX")
echo "Updating rolling release $alias_tag."
if gh release view "$alias_tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>"$release_error_file"; then
  gh release edit "$alias_tag" \
    --repo "$GITHUB_REPOSITORY" \
    --title "DINX latest alpha ISO" \
    --notes-file "$alias_dir/notes.md" \
    --prerelease
else
  status=$?
  if grep -Fq '(HTTP 404)' "$release_error_file"; then
    gh release create "$alias_tag" \
      --repo "$GITHUB_REPOSITORY" \
      --target "$commit_sha" \
      --title "DINX latest alpha ISO" \
      --notes-file "$alias_dir/notes.md" \
      --prerelease
  else
    cat "$release_error_file" >&2
    rm -f "$release_error_file"
    exit "$status"
  fi
fi
rm -f "$release_error_file"
upload_asset_with_retry() {
  local asset_path=$1
  local asset_name=$2
  local error_file attempt status
  error_file=$(mktemp "$RUNNER_TEMP/dinx-release-upload.XXXXXX")
  for attempt in 1 2 3 4 5 6; do
    echo "Uploading $asset_name (attempt $attempt/6)."
    if gh release upload "$alias_tag" \
      --repo "$GITHUB_REPOSITORY" \
      --clobber \
      "$asset_path" 2>"$error_file"; then
      [[ ! -s "$error_file" ]] || cat "$error_file" >&2
      rm -f "$error_file"
      return 0
    else
      status=$?
    fi
    if ! grep -Fq '(HTTP 404)' "$error_file"; then
      cat "$error_file" >&2
      rm -f "$error_file"
      return "$status"
    fi
    if (( attempt == 6 )); then
      printf 'publish_latest_alpha_alias: alias release remained unavailable for %s after %s attempts\n' \
        "$asset_name" "$attempt" >&2
      cat "$error_file" >&2
      rm -f "$error_file"
      return "$status"
    fi
    printf 'publish_latest_alpha_alias: alias release is not visible for %s (404, attempt %s/6); retrying in 5s\n' \
      "$asset_name" "$attempt" >&2
    sleep 5
  done
  rm -f "$error_file"
  return 1
}

upload_asset_with_retry "$alias_dir/$alias_iso" "$alias_iso"
upload_asset_with_retry "$alias_dir/$alias_iso.sha512" "$alias_iso.sha512"

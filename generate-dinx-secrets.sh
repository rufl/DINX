#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s OWNER/REPO BACKUP_PRIVATE_KEY.asc [--replace]\n' "$0" >&2
  printf 'example: %s rufl/DINX /media/secure/dinx-package-signing-key.asc\n' "$0" >&2
  exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

repo=$1
backup_private_key=$2
replace=false

if [[ ${3:-} == --replace ]]; then
  replace=true
elif [[ $# -eq 3 ]]; then
  usage
fi

[[ "$repo" =~ ^[^/]+/[^/]+$ ]] || {
  printf 'invalid repository: %s\n' "$repo" >&2
  exit 1
}

for command in gpg gh awk mktemp install shred; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'required command missing: %s\n' "$command" >&2
    exit 1
  }
done

gh auth status >/dev/null
gh repo view "$repo" >/dev/null

backup_dir=$(dirname -- "$backup_private_key")
backup_name=$(basename -- "$backup_private_key")

if [[ "$backup_name" != *.asc ]]; then
  printf 'backup path must end in .asc: %s\n' "$backup_private_key" >&2
  exit 1
fi

public_backup="${backup_private_key%.asc}.pub.asc"
revocation_backup="${backup_private_key%.asc}.rev"

if [[ "$replace" != true ]]; then
  existing_secrets=$(
    gh secret list --repo "$repo" --json name --jq '.[].name' || true
  )

  if grep -Fxq DINX_PACKAGE_SIGNING_KEY <<<"$existing_secrets" \
    || grep -Fxq DINX_PACKAGE_SIGNING_FINGERPRINT <<<"$existing_secrets"; then
    printf 'DINX signing secrets already exist. Use --replace to rotate them.\n' >&2
    exit 1
  fi
fi

if [[ -e "$backup_private_key" || -e "$public_backup" || -e "$revocation_backup" ]]; then
  printf 'backup output already exists; refusing to overwrite it\n' >&2
  printf 'private: %s\npublic:  %s\nrevocation: %s\n' \
    "$backup_private_key" "$public_backup" "$revocation_backup" >&2
  exit 1
fi

work_dir=$(mktemp -d)
gpg_home="$work_dir/gnupg"
private_tmp="$work_dir/private.asc"
public_tmp="$work_dir/public.asc"

cleanup() {
  set +e
  [[ -f "$private_tmp" ]] && shred -u "$private_tmp"
  [[ -f "$public_tmp" ]] && shred -u "$public_tmp"
  rm -rf "$work_dir"
}
trap cleanup EXIT

install -d -m 700 "$gpg_home" "$backup_dir"

cat >"$work_dir/keyparams" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 3072
Key-Usage: sign
Name-Real: DINX package repository
Name-Email: packages@dinx.invalid
Expire-Date: 0
%commit
EOF

gpg \
  --batch \
  --homedir "$gpg_home" \
  --generate-key "$work_dir/keyparams" >/dev/null

fingerprint=$(
  gpg \
    --batch \
    --homedir "$gpg_home" \
    --with-colons \
    --list-secret-keys |
    awk -F: '$1 == "fpr" { print $10; exit }'
)

[[ "$fingerprint" =~ ^[A-Fa-f0-9]{40}$ ]] || {
  printf 'generated fingerprint is invalid\n' >&2
  exit 1
}

gpg \
  --batch \
  --homedir "$gpg_home" \
  --armor \
  --export-secret-keys "$fingerprint" >"$private_tmp"

gpg \
  --batch \
  --homedir "$gpg_home" \
  --armor \
  --export "$fingerprint" >"$public_tmp"

chmod 600 "$private_tmp"
chmod 644 "$public_tmp"

revocation_source=$(
  find "$gpg_home/openpgp-revocs.d" \
    -maxdepth 1 \
    -type f \
    -name '*.rev' \
    -print -quit
)

[[ -s "$revocation_source" ]] || {
  printf 'GPG did not create a revocation certificate\n' >&2
  exit 1
}

install -m 600 "$private_tmp" "$backup_private_key"
install -m 644 "$public_tmp" "$public_backup"
install -m 600 "$revocation_source" "$revocation_backup"

gh secret set \
  DINX_PACKAGE_SIGNING_KEY \
  --repo "$repo" \
  <"$private_tmp"

gh secret set \
  DINX_PACKAGE_SIGNING_FINGERPRINT \
  --repo "$repo" \
  --body "$fingerprint"

printf '\nDINX signing secrets configured.\n'
printf 'repository:        %s\n' "$repo"
printf 'fingerprint:       %s\n' "$fingerprint"
printf 'private backup:    %s\n' "$backup_private_key"
printf 'public key backup: %s\n' "$public_backup"
printf 'revocation cert:   %s\n' "$revocation_backup"
printf '\nThe private backup must remain offline and must not enter Git or CI artifacts.\n'
printf 'The next tagged release will require this key and publish the signed pacman repository.\n'

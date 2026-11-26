#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
build_script="$root/scripts/build-iso.sh"

fail() {
  printf 'check_dinx_iso_identity: %s\n' "$*" >&2
  exit 1
}

iso_tools_dir="$root/scripts/iso-tools"
xorriso_wrapper="$iso_tools_dir/xorriso"

[[ -r "$build_script" ]] || fail "missing ISO build wrapper: $build_script"
[[ -x "$xorriso_wrapper" ]] || fail "missing executable ISO identity wrapper: $xorriso_wrapper"
grep -Fq -- 'iso_label_replacements' "$build_script" \
  || fail 'ISO build does not rewrite the Artix kernel label source'
grep -Fq -- 'DINX_$(date +%Y%m)' "$build_script" \
  || fail 'ISO build does not select the DINX kernel/volume label'
grep -Fq -- '-p dinx' "$build_script" \
  || fail 'ISO build does not select the DINX profile'

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-iso-identity.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
fake_xorriso="$test_dir/xorriso"
captured_args="$test_dir/args"
cat > "$fake_xorriso" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DINX_TEST_CAPTURE"
EOF
chmod +x "$fake_xorriso"

expected_label="DINX_$(date +%Y%m)"
expected_output="$test_dir/dinx-dinit-20261126-x86_64.iso"
DINX_REAL_XORRISO="$fake_xorriso" \
DINX_TEST_CAPTURE="$captured_args" \
  "$xorriso_wrapper" \
  -as mkisofs \
  -volid ARTIX_202611 \
  -o "$test_dir/artix-dinx-dinit-20261126-x86_64.iso" \
  "$test_dir/tree"

grep -Fxq -- "$expected_label" "$captured_args" \
  || fail "xorriso wrapper did not set DINX volume label"
grep -Fxq -- "$expected_output" "$captured_args" \
  || fail "xorriso wrapper did not normalize DINX ISO filename"
printf 'dinx_iso_identity_contract volume_id=DINX_YYYYMM filename=dinx-dinit-YYYYMMDD-x86_64.iso upstream_prefix_removed=true\n'

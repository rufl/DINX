#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
mimeapps="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
package_dir="$repo_root/distro/packages/floorp"
pkgbuild="$package_dir/PKGBUILD"
source_env="$package_dir/source.env"
wrapper="$package_dir/floorp-launcher"
desktop="$package_dir/floorp.desktop"
policy="$package_dir/policies.json"
manifest="$repo_root/.github/package-updates.json"
builder="$repo_root/scripts/build-iso-container.sh"

fail() {
  printf 'check_floorp: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$mimeapps" "$pkgbuild" "$source_env" "$wrapper" "$desktop" "$policy" "$manifest" "$builder"; do
  [[ -r "$path" ]] || fail "missing $path"
done
[[ -x "$wrapper" ]] || fail 'Floorp launcher is not executable'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'

source "$source_env"
[[ "$FLOORP_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid version: $FLOORP_VERSION"
[[ "$FLOORP_SOURCE_URL" == "https://github.com/Floorp-Projects/Floorp/releases/download/v${FLOORP_VERSION}/floorp-linux-x86_64.tar.xz" ]] \
  || fail 'source URL does not match the official x86_64 release archive'
[[ "$FLOORP_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'source SHA-256 is invalid'
grep -Fq 'pkgver="$FLOORP_VERSION"' "$pkgbuild" || fail 'package version is not wired to source.env'
grep -Fq 'floorp-linux-x86_64.tar.xz::${FLOORP_SOURCE_URL}' "$pkgbuild" \
  || fail 'source URL is not wired to source.env'
grep -Fq '"$FLOORP_SOURCE_SHA256"' "$pkgbuild" || fail 'source checksum is not wired to source.env'
grep -Fq 'cp -a "$srcdir/floorp/." "$pkgdir/usr/lib/floorp/"' "$pkgbuild" \
  || fail 'official Floorp release files are not installed under /usr/lib/floorp'
grep -Fq '"$pkgdir/usr/lib/floorp/distribution/policies.json"' "$pkgbuild" \
  || fail 'managed policy is not installed in Floorp distribution directory'
grep -Fq 'build_package floorp' "$builder" || fail 'ISO builder does not include the Floorp package'

bash -n "$wrapper" || fail 'Floorp wrapper has invalid shell syntax'
grep -Fqx 'exec /usr/lib/floorp/floorp "$@"' "$wrapper" || fail 'Floorp wrapper does not safely forward arguments'
grep -Fqx 'Name=Floorp' "$desktop" || fail 'Floorp desktop name is missing'
grep -Fqx 'Exec=floorp %u' "$desktop" || fail 'Floorp desktop entry has the wrong command'
grep -Fqx 'TryExec=floorp' "$desktop" || fail 'Floorp desktop entry has the wrong executable'
grep -Fqx 'Icon=floorp' "$desktop" || fail 'Floorp desktop icon is missing'
for mime in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https; do
  grep -Fqx "$mime=floorp.desktop;" "$mimeapps" || fail "Floorp is not the default $mime handler"
done

if grep -Eiq '(^|[[:space:]])- firefox$|firefox\.desktop' "$profile" "$mimeapps"; then
  fail 'Firefox remains selected in the profile or default handler list'
fi
[[ ! -e "$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/firefox/policies/policies.json" ]] \
  || fail 'obsolete Firefox policy overlay remains in the ISO'

python3 - "$policy" "$groups" "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    policies = json.load(stream)["policies"]
assert policies["DisableAppUpdate"] is True
assert policies["DisableFirefoxStudies"] is True
assert policies["DisableTelemetry"] is True
assert policies["DisablePocket"] is True
assert policies["IPProtectionAvailable"] is False
assert policies["FirefoxHome"]["SponsoredTopSites"] is False
assert policies["FirefoxSuggest"]["SponsoredSuggestions"] is False
assert policies["UserMessaging"]["SkipOnboarding"] is True
assert policies["GenerativeAI"]["Chatbot"] is False
assert policies["AIControls"]["SidebarChatbot"]["Value"] == "blocked"

with open(sys.argv[2], encoding="utf-8") as stream:
    groups = json.load(stream)
assert "floorp" in groups["groups"]["desktop"]["packages"]
assert "firefox" not in sum((group["packages"] for group in groups["groups"].values()), [])

with open(sys.argv[3], encoding="utf-8") as stream:
    updates = json.load(stream)
entries = [entry for entry in updates["packages"] if entry.get("name") == "floorp"]
assert len(entries) == 1
entry = entries[0]
assert entry["source_file"] == "distro/packages/floorp/source.env"
assert entry["tag_prefix"] == "v"
assert entry["bump_pkgrel_path"] == "distro/packages/floorp/PKGBUILD"
PY

printf 'floorp_contract default=true package-managed_updates=true sponsored=false telemetry=false ai_surfaces=false mime_handlers=true source_refresh=true\n'

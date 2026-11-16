#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
policy="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/lib/firefox/distribution/policies.json"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'firefox_contract: FAIL: %s\n' "$1" >&2
  exit 1
}

for path in "$profile" "$groups" "$mimeapps" "$policy" "$iso_check" "$workflow"; do
  [[ -r "$path" ]] || fail "missing file: ${path#$root/}"
done

grep -Fqx '    - firefox' "$profile" || fail 'profile is missing Firefox'
jq -e '.groups.desktop.packages | index("firefox") != null' "$groups" >/dev/null \
  || fail 'desktop group is missing Firefox'
if grep -Eiq '(^|[[:space:]])floorp([[:space:]]|$)|floorp\.desktop' "$profile" "$groups" "$mimeapps"; then
  fail 'Floorp remains selected or registered'
fi
for mime in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https; do
  grep -Fqx "$mime=firefox.desktop;" "$mimeapps" || fail "Firefox is not the default $mime handler"
done
for required in \
  '  usr/bin/firefox' \
  '  usr/share/applications/firefox.desktop' \
  '  usr/lib/firefox/distribution/policies.json'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
grep -Fq 'scripts/check_firefox.sh' "$workflow" || fail 'workflow does not run the Firefox contract'
python3 - "$policy" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    policies = json.load(stream)["policies"]
assert policies["DisableAppUpdate"] is True
assert policies["DisableFirefoxStudies"] is True
assert policies["DisableTelemetry"] is True
assert policies["DisablePocket"] is True
assert policies["FirefoxHome"]["SponsoredTopSites"] is False
assert policies["FirefoxSuggest"]["SponsoredSuggestions"] is False
assert policies["UserMessaging"]["SkipOnboarding"] is True
assert policies["GenerativeAI"]["Chatbot"] is False
assert policies["AIControls"]["SidebarChatbot"]["Value"] == "blocked"
PY
printf 'firefox_contract default=true managed_policy=true floorp=false\n'

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
mimeapps="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
noctalia="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml"
policy="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/firefox/policies/policies.json"

fail() {
  printf 'check_firefox: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$mimeapps" "$noctalia" "$policy"; do
  [[ -r "$path" ]] || fail "missing $path"
done

command -v python3 >/dev/null 2>&1 || fail 'python3 is required'

grep -Fqx '    - firefox' "$profile" || fail 'DINX profile does not install Firefox'
if grep -Fqx '    - palemoon' "$profile"; then
  fail 'DINX profile still installs Pale Moon'
fi

grep -Fqx 'text/html=firefox.desktop;' "$mimeapps" || fail 'Firefox is not the default HTML handler'
grep -Fqx 'application/xhtml+xml=firefox.desktop;' "$mimeapps" || fail 'Firefox is not the default XHTML handler'
grep -Fqx 'x-scheme-handler/http=firefox.desktop;' "$mimeapps" || fail 'Firefox is not the default HTTP handler'
grep -Fqx 'x-scheme-handler/https=firefox.desktop;' "$mimeapps" || fail 'Firefox is not the default HTTPS handler'
grep -Fq 'pinned = ["firefox"' "$noctalia" || fail 'Noctalia does not pin Firefox'

if grep -Eiq 'palemoon|moonchild' "$profile" "$mimeapps" "$noctalia"; then
  fail 'Pale Moon remains in the DINX default browser contract'
fi

python3 - "$policy" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    policies = json.load(stream)["policies"]

assert policies["DisableFirefoxStudies"] is True
assert policies["DisableTelemetry"] is True
assert policies["DisablePocket"] is True
assert policies["IPProtectionAvailable"] is False

home = policies["FirefoxHome"]
assert home["Search"] is True
assert home["TopSites"] is True
for key in ("SponsoredTopSites", "Highlights", "Pocket", "Stories", "SponsoredPocket", "SponsoredStories", "Snippets"):
    assert home[key] is False
assert home["Locked"] is True

suggest = policies["FirefoxSuggest"]
for key in ("WebSuggestions", "SponsoredSuggestions", "ImproveSuggest"):
    assert suggest[key] is False
assert suggest["Locked"] is True

messaging = policies["UserMessaging"]
for key in ("ExtensionRecommendations", "FeatureRecommendations", "UrlbarInterventions", "MoreFromMozilla", "FirefoxLabs"):
    assert messaging[key] is False
assert messaging["SkipOnboarding"] is True
assert messaging["Locked"] is True

generative = policies["GenerativeAI"]
for key in ("Chatbot", "LinkPreviews", "TabGroups"):
    assert generative[key] is False
assert generative["Locked"] is True

for key in ("SidebarChatbot", "LinkPreviewKeyPoints", "SmartTabGroups", "SmartWindow"):
    assert policies["AIControls"][key] == {"Value": "blocked", "Locked": True}

prefs = policies["Preferences"]
for key in ("browser.urlbar.suggest.quicksuggest.sponsored", "browser.urlbar.quicksuggest.dataCollection.enabled"):
    assert prefs[key] == {"Value": False, "Status": "locked", "Type": "boolean"}
assert prefs["identity.fxaccounts.toolbar"] == {
    "Value": False,
    "Status": "default",
    "Type": "boolean",
}

print("firefox_contract default=true sponsored=false telemetry=false ai_assistant=false vpn=false sync=manual")
PY

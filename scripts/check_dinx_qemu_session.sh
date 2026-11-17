#!/usr/bin/env bash
set -euo pipefail

screenshot=${1:-}
mode=${2:-session}
ocr_language=${DINX_QEMU_OCR_LANG:-eng}

fail() {
  printf 'dinx-qemu-session: %s\n' "$*" >&2
  exit 1
}

[[ $# -le 2 ]] || fail 'usage: scripts/check_dinx_qemu_session.sh SCREENSHOT.ppm [session|first-run|greeter]'
[[ -n "$screenshot" ]] || fail 'usage: scripts/check_dinx_qemu_session.sh SCREENSHOT.ppm [session|first-run|greeter]'
case "$mode" in
  session|first-run|greeter) ;;
  *) fail 'mode must be session, first-run or greeter' ;;
esac
[[ -s "$screenshot" ]] || fail "session screenshot is missing or empty: $screenshot"
command -v python3 >/dev/null 2>&1 || fail 'required command not found: python3'

ppm_magic=
IFS= read -r ppm_magic < "$screenshot" || true
[[ "$ppm_magic" == P6 ]] || fail "session screenshot is not a binary PPM: $screenshot"
if ! python3 - "$screenshot" <<'PY'
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
try:
    magic, dimensions, maximum, pixels = data.split(b"\n", 3)
    width, height = map(int, dimensions.split())
    max_value = int(maximum)
except ValueError:
    sys.exit(1)
if magic.strip() != b"P6" or max_value != 255 or len(pixels) != width * height * 3:
    sys.exit(1)

visible = sum(max(pixels[offset], pixels[offset + 1], pixels[offset + 2]) > 32 for offset in range(0, len(pixels), 3))
if visible * 1000 < width * height * 2:
    print(f"visible pixels above DINX canvas: {visible}/{width * height}", file=sys.stderr)
    sys.exit(1)
PY
then
  fail 'QEMU session screenshot is visually blank (fewer than 0.2% visible pixels)'
fi

recognized=$(tesseract "$screenshot" stdout -l "$ocr_language" --psm 11 2>/dev/null) \
  || fail "Tesseract could not inspect the session screenshot with language '$ocr_language': $screenshot"
if [[ -z "${recognized//[[:space:]]/}" ]]; then
  ocr_tmp=$(mktemp)
  trap 'rm -f "$ocr_tmp"' EXIT
  python3 - "$screenshot" "$ocr_tmp" <<'PY'
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
try:
    magic, dimensions, maximum, pixels = data.split(b"\n", 3)
    width, height = map(int, dimensions.split())
    max_value = int(maximum)
except ValueError:
    sys.exit(1)
if magic.strip() != b"P6" or width < 1 or height < 1 or max_value != 255 or len(pixels) != width * height * 3:
    sys.exit(1)

scale = 3
crop_height = min(height, 64)
with Path(sys.argv[2]).open("wb") as output:
    output.write(f"P6\n{width * scale} {crop_height * scale}\n255\n".encode())
    for y in range(crop_height):
        row = pixels[y * width * 3:(y + 1) * width * 3]
        enlarged = bytearray(width * scale * 3)
        for x in range(width):
            start = x * scale * 3
            enlarged[start:start + scale * 3] = row[x * 3:x * 3 + 3] * scale
        for _ in range(scale):
            output.write(enlarged)
PY
  recognized=$(tesseract "$ocr_tmp" stdout -l "$ocr_language" --psm 11 2>/dev/null) \
    || fail "Tesseract could not inspect the enlarged session panel with language '$ocr_language': $screenshot"
fi
if [[ -z "${recognized//[[:space:]]/}" ]]; then
  fail "no readable text in QEMU session screenshot: $screenshot"
fi

if [[ "$mode" == greeter ]]; then
  if grep -Eiq 'access[[:space:]]*denied|greeterstartupfailed|broken[[:space:]]*pipe|cannot[[:space:]]+open[[:space:]]+display|segmentation[[:space:]]+fault' <<<"$recognized"; then
    printf 'dinx-qemu-session: rejected greeter startup failure:\n%s\n' "$recognized" >&2
    exit 1
  fi
  greeter_text=$(printf '%s' "$recognized" | tr -cd '[:alnum:]')
  if ! grep -Eiq 'agreety|greeter|dinx|river' <<<"$greeter_text" \
    || ! grep -Eiq 'signin|login' <<<"$greeter_text" \
    || ! grep -Eiq 'pas[[:alpha:]]{0,4}rd' <<<"$greeter_text"; then
    printf 'dinx-qemu-session: agreety identity, sign-in and password controls are not visible:\n%s\n' "$recognized" >&2
    exit 1
  fi
  printf 'dinx-qemu-session: greeter_ready=true marker=Agreety+SignIn+Password screenshot=%s\n' "$screenshot"
  exit 0
fi

if grep -Eiq 'no[[:space:]]+desktop folder is configured|XDG_DESKTOP_DIR' <<<"$recognized"; then
  fail 'the session reports a missing XDG Desktop directory'
fi
if grep -Eiq 'agreety|greeter|select[[:space:]]*user|login[[:space:]]*:|tty[[:space:]]*[[:digit:]]+|password|sign[[:space:]]*in|fail|error|panic|not[[:space:]]+found|dinit:.*execution failed' <<<"$recognized"; then
  printf 'dinx-qemu-session: rejected non-session screen:\n%s\n' "$recognized" >&2
  exit 1
fi
# A compositor titlebar must name the DINX session stack. Any other "… - Wayland"
# title means a foreign or retired compositor owns the seat.
while IFS= read -r title_line; do
  printf 'dinx-qemu-session: unsupported compositor title: %s\n' "$title_line" >&2
  exit 1
done < <(grep -Ei '[^[:space:]][[:space:]]+-[[:space:]]*Wayland([[:space:]]|$)' <<<"$recognized" \
  | grep -Eiv '(^|[^[:alnum:]_])(river|kwm)([^[:alnum:]_]|$)')

if [[ "$mode" == first-run ]]; then
  if ! grep -Eiq 'Install[[:space:]]+DINX' <<<"$recognized"; then
    printf 'dinx-qemu-session: live desktop has no readable Install DINX shortcut:\n%s\n' "$recognized" >&2
    exit 1
  fi
  printf 'dinx-qemu-session: first_run_shortcut_visible=true marker=Install+DINX screenshot=%s\n' "$screenshot"
  exit 0
fi
marker=identity
if grep -Eiq '(^|[^[:alnum:]_])(river|kwm)([^[:alnum:]_]|$)' <<<"$recognized"; then
  marker=river-desktop
elif grep -Eiq '(^|[^[:alnum:]_])dinx([^[:alnum:]_]|$)' <<<"$recognized"; then
  marker=dinx-desktop
else
  printf 'dinx-qemu-session: no River/KWM or DINX desktop marker in QEMU screen:\n%s\n' "$recognized" >&2
  exit 1
fi
printf 'dinx-qemu-session: graphical_ready=true marker=%s screenshot=%s\n' "$marker" "$screenshot"

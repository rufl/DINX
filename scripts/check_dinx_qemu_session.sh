#!/usr/bin/env bash
set -euo pipefail

screenshot=${1:-}
ocr_language=${DINX_QEMU_OCR_LANG:-eng}

fail() {
  printf 'dinx-qemu-session: %s\n' "$*" >&2
  exit 1
}

[[ -n "$screenshot" ]] || fail 'usage: scripts/check_dinx_qemu_session.sh SESSION_SCREENSHOT.ppm'
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
  fail "no readable text in QEMU session screenshot: $screenshot"
fi
if grep -Eiq 'no[[:space:]]+desktop folder is configured|XDG_DESKTOP_DIR' <<<"$recognized"; then
  fail 'Pearl reports a missing XDG Desktop directory'
fi
if grep -Eiq 'pearl[[:space:]]+greeter|login[[:space:]]*:|tty[[:space:]]*[[:digit:]]+|password|sign[[:space:]]*in|select[[:space:]]*user|fail|dinit:.*execution failed|initializing[[:space:]]+aqueous[[:space:]]+version' <<<"$recognized"; then
  printf 'dinx-qemu-session: rejected non-session screen:\n%s\n' "$recognized" >&2
  exit 1
fi
marker=identity
if ! grep -Eiq '(^|[^[:alnum:]_])(pearl|aqueous|dinx)([^[:alnum:]_]|$)' <<<"$recognized"; then
  if grep -Eiq '(^|[^[:alnum:]_])Desktop([^[:alnum:]_]|$)' <<<"$recognized" \
    && grep -Eiq 'English[[:space:]]+\(US\)' <<<"$recognized" \
    && grep -Eiq '[0-2]?[[:digit:]]:[0-5][[:digit:]]' <<<"$recognized"; then
    marker=pearl-panel
  else
    printf 'dinx-qemu-session: no Pearl/Aqueous desktop marker in QEMU screen:\n%s\n' "$recognized" >&2
    exit 1
  fi
fi
printf 'dinx-qemu-session: graphical_ready=true marker=%s screenshot=%s\n' "$marker" "$screenshot"

#!/usr/bin/env bash
# Runs the Consent Lifecycle showcase test against the booted iOS simulator,
# watches stdout for [SCREENSHOT:<name>] markers, and captures PNGs to
# ../doc/screenshots/<name>.png.
#
# Prereqs:
#   - A booted iPhone simulator (xcrun simctl list devices booted).
#   - Gemma 4 E2B model cached at model_cache/gemma-4-E2B-it.litertlm
#     (run scripts/precache_gemma_e2b.sh once to populate).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$(cd "$EXAMPLE_DIR/../doc/screenshots" && pwd)"

cd "$EXAMPLE_DIR"

SIM_ID="$(xcrun simctl list devices booted -j \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print([dev["udid"] for cat in d["devices"].values() for dev in cat if dev.get("state")=="Booted"][0])')"

if [[ -z "$SIM_ID" ]]; then
  echo "No booted iOS simulator found." >&2
  exit 1
fi

export SIM_ID OUT_DIR

echo "Running showcase on sim $SIM_ID; screenshots → $OUT_DIR"

# The test runs in line-buffered mode so [SCREENSHOT:] markers land promptly.
# The while-loop body runs in a subshell; SIM_ID and OUT_DIR are exported so
# it sees them.
stdbuf -oL flutter test -d "$SIM_ID" \
  integration_test/consent_lifecycle_showcase_test.dart \
  --dart-define=LLM_ADAPTER=gemma \
  --dart-define=GEMMA_MODEL_PATH="$EXAMPLE_DIR/model_cache/gemma-4-E2B-it.litertlm" \
  2>&1 | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" =~ \[SCREENSHOT:([a-zA-Z0-9_]+)\] ]]; then
      name="${BASH_REMATCH[1]}"
      out="$OUT_DIR/${name}.png"
      # Brief settle so the captured frame matches the marker point.
      sleep 1
      if xcrun simctl io "$SIM_ID" screenshot "$out" 2>/tmp/simctl_err.$$; then
        echo "  → captured $out"
      else
        echo "  !! capture FAILED for $name:" >&2
        cat /tmp/simctl_err.$$ >&2
      fi
      rm -f /tmp/simctl_err.$$
    fi
  done

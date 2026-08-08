#!/bin/bash
#
# Kiln's local test runner. Guarded: a run is a PASS only if xcodebuild exits 0 AND at
# least one test executed. See ADR-004.
#
#   ./scripts/run-tests.sh            # macOS (default — fastest, no simulator)
#   ./scripts/run-tests.sh macos
#   ./scripts/run-tests.sh ios
#   ./scripts/run-tests.sh all
#
# macOS is the default because it needs no simulator boot. Simulator runs are slower and,
# per ADR-003, cannot exercise live model paths anyway — the suites here are deterministic
# by design, so the platform difference is about the build, not the behaviour.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/xcresult.sh
. "$ROOT/scripts/lib/xcresult.sh"

MODE="${1:-macos}"
IOS_DESTINATION="${KILN_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
FAILED=0

run_suite() {
  local label="$1" scheme="$2"
  shift 2

  local bundle="$ROOT/build/test-results/$label.xcresult"
  mkdir -p "$(dirname "$bundle")"
  rm -rf "$bundle"

  echo "=== $label ==="
  xcodebuild test \
    -project Kiln.xcodeproj \
    -scheme "$scheme" \
    -configuration Debug \
    -resultBundlePath "$bundle" \
    "$@" \
    > "$ROOT/build/test-results/$label.log" 2>&1
  local rc=$?

  # The guard runs even when rc is 0 — that is the case it exists for.
  if assert_tests_ran "$bundle" "$rc" "$label"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (see build/test-results/$label.log)"
    grep -E "error:|failed" "$ROOT/build/test-results/$label.log" | head -20
    FAILED=1
  fi
  echo
}

command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet

case "$MODE" in
  macos) run_suite macos Kiln-macOS ;;
  ios)   run_suite ios   Kiln-iOS -destination "$IOS_DESTINATION" ;;
  all)
    run_suite macos Kiln-macOS
    run_suite ios   Kiln-iOS -destination "$IOS_DESTINATION"
    ;;
  *)
    echo "usage: $0 [macos|ios|all]" >&2
    exit 2
    ;;
esac

exit "$FAILED"

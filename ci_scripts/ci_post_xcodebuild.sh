#!/bin/bash
#
# Xcode Cloud post-xcodebuild hook for Kiln — the zero-test guard. See ADR-004.
#
# `xcodebuild` can exit 0 having run nothing, printing verbatim
# "Test run with 0 tests in 1 suite passed". Locally that trap is closed by
# scripts/lib/xcresult.sh, which run-tests.sh calls. Xcode Cloud has no equivalent: a test
# action that silently runs nothing renders in App Store Connect as a green check,
# indistinguishable from a real pass.
#
# That is worse than having no test action at all. No test action is honestly no signal;
# a green one that ran nothing is a false signal you will trust.
#
# So this sources the SAME library the local runner uses, deliberately — a safety check
# duplicated in two places is a safety check that will drift.
#
# Fails closed: an unreadable or missing bundle is "unproven", never "zero", never a pass.
#
set -euo pipefail

# Only meaningful after a test action. Build and archive actions legitimately run no
# tests, and failing those would be nonsense.
ACTION="${CI_XCODEBUILD_ACTION:-}"
case "$ACTION" in
  *test*) ;;
  *)
    echo "--- ci_post_xcodebuild: action '${ACTION:-<unset>}' runs no tests — guard not applicable"
    exit 0
    ;;
esac

echo "--- ci_post_xcodebuild: zero-test guard (action: $ACTION) ---"

if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  ROOT="$CI_PRIMARY_REPOSITORY_PATH"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

LIB="$ROOT/scripts/lib/xcresult.sh"
[ -f "$LIB" ] || { echo "    ERROR: $LIB missing — cannot verify the test count" >&2; exit 1; }
# shellcheck source=../scripts/lib/xcresult.sh
. "$LIB"

# Prefer what Cloud tells us. The /Volumes/workspace fallback is the path Cloud has
# historically used; the find is a last resort so a future layout change degrades into a
# search rather than a false pass.
BUNDLE="${CI_RESULT_BUNDLE_PATH:-}"
if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
  if [ -d /Volumes/workspace/resultbundle.xcresult ]; then
    BUNDLE=/Volumes/workspace/resultbundle.xcresult
  else
    # `|| true`: under `set -e -o pipefail` a failing find (e.g. the directory does not
    # exist off-Cloud) would abort here, skipping the diagnostic below. Still fails
    # closed — BUNDLE ends up empty and the check underneath reports why.
    BUNDLE="$(find /Volumes/workspace -maxdepth 2 -name '*.xcresult' -type d 2>/dev/null | head -1 || true)"
  fi
fi

if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
  echo "    ERROR: no .xcresult found — refusing to report a pass we cannot prove." >&2
  echo "           CI_RESULT_BUNDLE_PATH='${CI_RESULT_BUNDLE_PATH:-<unset>}'" >&2
  exit 1
fi
echo "    result bundle: $BUNDLE"

# rc=0 because reaching a post-xcodebuild hook means xcodebuild itself succeeded — which
# is precisely the case this guard is about.
if assert_tests_ran "$BUNDLE" 0 "$ACTION"; then
  echo "--- ci_post_xcodebuild: guard passed ---"
  exit 0
else
  echo "--- ci_post_xcodebuild: FAILING the build — a green run that tested nothing is not a pass ---" >&2
  exit 1
fi

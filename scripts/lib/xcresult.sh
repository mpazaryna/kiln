#!/bin/bash
# Shared xcresult helpers for guarded test runs. See ADR-004.
#
# Sourced by scripts/run-tests.sh (local) and ci_scripts/ci_post_xcodebuild.sh (Xcode
# Cloud). It lives in one place on purpose: this is a safety check, and a safety check
# that exists in the local runner but not its CI twin is exactly the thing that drifts
# back out of sync.

# Total tests recorded in a result bundle. Prints nothing if the count cannot be read —
# callers MUST treat that as "unproven", never as zero and never as a pass.
#
# Reads totalTestCount from the bundle rather than grepping xcodebuild's stdout. The
# Swift Testing summary line ("Test run with N tests in M suites") excludes XCTest cases,
# so it under-reports any target that mixes the two frameworks. The bundle counts both.
tests_in_bundle() {
  [ -d "$1" ] || return 0
  xcrun xcresulttool get test-results summary --path "$1" --compact 2>/dev/null \
    | grep -o '"totalTestCount"[[:space:]]*:[[:space:]]*[0-9]\{1,\}' \
    | grep -o '[0-9]\{1,\}$' \
    | head -1
}

# The zero-test guard. Call after a test run with (bundle, xcodebuild_rc, filter_label).
# Echoes the count and returns the exit status the caller should exit with.
#
# This must run on every path, including rc == 0: "xcodebuild exited 0" and "tests ran"
# are different claims, and conflating them is the whole bug. xcodebuild CAN exit 0 having
# run nothing, printing verbatim "Test run with 0 tests in 1 suite passed".
#
# It does not always: a plainly bogus -only-testing suite name fails loudly (exit 70 on
# Xcode 26, verified). The guard exists for the cases that do not — a filter that resolves
# but matches nothing, an all-skipped suite, a target that silently built no tests. Which
# shapes exit 0 is an Xcode implementation detail that has changed before and will again,
# so the count is checked unconditionally rather than trusted to the exit code.
#
# Fails closed. A green run that tested nothing is worse than no run at all: no run is
# honestly no signal, a false green is a signal you will act on.
assert_tests_ran() {
  local bundle="$1" rc="$2" label="$3" count
  count="$(tests_in_bundle "$bundle")"

  if [ -z "$count" ]; then
    echo "" >&2
    echo "error: could not read a test count from $bundle." >&2
    echo "       Refusing to report a pass we cannot prove. Inspect the bundle with:" >&2
    echo "       xcrun xcresulttool get test-results summary --path $bundle" >&2
    [ "$rc" -eq 0 ] && return 1
    return "$rc"
  fi

  if [ "$count" -eq 0 ]; then
    echo "" >&2
    echo "error: ran 0 tests — filter '$label' matched no tests." >&2
    echo "       A run that executed no tests is not a pass, whatever xcodebuild returned." >&2
    [ "$rc" -eq 0 ] && return 1
    return "$rc"
  fi

  echo ""
  echo "$count tests executed (mode: $label)."
  return "$rc"
}

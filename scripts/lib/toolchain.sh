#!/bin/bash
# Pick an Xcode new enough for this project. Sourced by scripts/run-tests.sh,
# scripts/probe.sh and scripts/run-app.sh.
#
# The Xcode a terminal builds with is whatever `xcode-select` points at: a machine setting,
# not a repository fact. A Mac can have Xcode 27 installed as Xcode-beta.app while the
# terminal still builds with Xcode 26, and a 27.0 deployment target then fails with errors
# that read as if the code were wrong. Opening the project in Xcode hides this, because the
# app always uses its own toolchain. So the scripts check, and pick.
#
# The requirement is read from project.yml's xcodeVersion, so it lives in one place.
#
# Precedence:
#   1. DEVELOPER_DIR, if set. An explicit choice is never overridden.
#   2. The selected Xcode, if its major version meets the requirement.
#   3. The first /Applications/Xcode*.app that does.
# Otherwise it fails and says what it found.
#
# Xcode Cloud never sources this. Its Xcode is pinned on the workflow (ADR-004 amendment).

# Major version of the Xcode that owns a Developer directory. Prints nothing if unreadable,
# which callers treat as "not new enough".
xcode_major() {
  /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$1/../Info.plist" 2>/dev/null \
    | cut -d. -f1
}

select_xcode() {
  local root="$1" required selected app
  required="$(sed -n 's/^ *xcodeVersion: *"\{0,1\}\([0-9]\{1,\}\).*/\1/p' "$root/project.yml" | head -1)"
  if [ -z "$required" ]; then
    echo "toolchain: no xcodeVersion in project.yml" >&2
    return 1
  fi

  [ -n "${DEVELOPER_DIR:-}" ] && return 0

  selected="$(xcode-select -p 2>/dev/null || true)"
  if [ "$(xcode_major "$selected")" -ge "$required" ] 2>/dev/null; then
    return 0
  fi

  for app in /Applications/Xcode*.app; do
    [ -d "$app/Contents/Developer" ] || continue
    if [ "$(xcode_major "$app/Contents/Developer")" -ge "$required" ] 2>/dev/null; then
      export DEVELOPER_DIR="$app/Contents/Developer"
      echo "toolchain: the selected Xcode is older than $required, so using $app"
      return 0
    fi
  done

  echo "toolchain: Kiln needs Xcode $required or later. Selected: ${selected:-none}." >&2
  echo "           None found in /Applications. Set DEVELOPER_DIR to one that is." >&2
  return 1
}

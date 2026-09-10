#!/bin/bash
#
# Build Kiln for macOS and launch it: the app as a user meets it, not the test suite.
#
#   ./scripts/run-app.sh                          # launch in the Mac's own appearance
#   ./scripts/run-app.sh --light                  # force light appearance
#   ./scripts/run-app.sh --screenshot kiln.png    # also capture the Kiln window, only it
#
# Relaunching replaces the copy this script started last time. A copy run from Xcode is a
# different build and is left alone.
#
# macOS only. An iPhone needs a device and signing, which Xcode handles better than a
# script: run the Kiln-iOS scheme from Xcode. Live prompts need Apple Intelligence enabled,
# and the iOS Simulator often lacks the model's guardrail assets anyway (ADR-003).
#
# Dark appearance has no flag: on a Mac already in dark mode the default is dark, and
# forcing it from the command line has not been verified here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/toolchain.sh
. "$ROOT/scripts/lib/toolchain.sh"

LIGHT=0
SCREENSHOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --light) LIGHT=1 ;;
    --screenshot) SCREENSHOT="${2:?usage: --screenshot <file.png>}"; shift ;;
    *) echo "usage: $0 [--light] [--screenshot <file.png>]" >&2; exit 2 ;;
  esac
  shift
done

select_xcode "$ROOT"
command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet

mkdir -p "$ROOT/build"
DERIVED="$ROOT/build/app"
xcodebuild -project Kiln.xcodeproj -scheme Kiln-macOS -configuration Debug \
  -derivedDataPath "$DERIVED" build > "$ROOT/build/app.log" 2>&1 || {
    echo "build failed — see build/app.log" >&2
    grep -E "error:" "$ROOT/build/app.log" | head -20 >&2
    exit 1
  }

APP="$DERIVED/Build/Products/Debug/Kiln.app"
BINARY="$APP/Contents/MacOS/Kiln"

# Matching on the full binary path is what spares a copy launched from Xcode.
pkill -f "$BINARY" 2>/dev/null || true

# -NSRequiresAquaSystemAppearance YES opts the app out of dark mode for this launch only.
# It changes nothing about the Mac's own setting.
if [ "$LIGHT" -eq 1 ]; then
  open -n "$APP" --args -NSRequiresAquaSystemAppearance YES
else
  open -n "$APP"
fi

PID=""
for _ in $(seq 1 40); do
  PID="$(pgrep -nf "$BINARY" || true)"
  [ -n "$PID" ] && break
  sleep 0.25
done
[ -n "$PID" ] || { echo "Kiln did not start" >&2; exit 1; }
echo "Kiln is running (pid $PID) from build/app"

[ -n "$SCREENSHOT" ] || exit 0

# Capture the Kiln window by ID, never the whole screen, which could show anything else
# that is open. The terminal needs Screen Recording permission for this; without it,
# screencapture returns an image without the window's contents.
HELPER="$ROOT/build/window-id"
if [ ! -x "$HELPER" ] || [ "$ROOT/scripts/lib/window-id.swift" -nt "$HELPER" ]; then
  xcrun swiftc -O "$ROOT/scripts/lib/window-id.swift" -o "$HELPER"
fi

WINDOW=""
for _ in $(seq 1 40); do
  WINDOW="$("$HELPER" "$PID" || true)"
  [ -n "$WINDOW" ] && break
  sleep 0.25
done
[ -n "$WINDOW" ] || { echo "no Kiln window appeared to capture" >&2; exit 1; }

# A window can be on screen a moment before its first frame is drawn.
sleep 1
screencapture -x -o -l "$WINDOW" "$SCREENSHOT"
echo "screenshot: $SCREENSHOT"

#!/bin/bash
#
# Build and run KilnProbe. See project.yml's KilnProbe target.
#
#   ./scripts/probe.sh capabilities
#   ./scripts/probe.sh tool "What temperature does cone 6 mature at?"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/toolchain.sh
. "$ROOT/scripts/lib/toolchain.sh"
select_xcode "$ROOT"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet

BUILD_DIR="$ROOT/build/probe"
xcodebuild -project Kiln.xcodeproj -scheme KilnProbe -configuration Debug \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" build > "$ROOT/build/probe.log" 2>&1 || {
    echo "build failed — see build/probe.log" >&2
    grep -E "error:" "$ROOT/build/probe.log" | head -20 >&2
    exit 1
  }

exec "$BUILD_DIR/KilnProbe" "$@"

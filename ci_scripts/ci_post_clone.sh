#!/bin/sh
#
# Xcode Cloud post-clone hook for Kiln. See ADR-004.
#
# Runs after Xcode Cloud clones the repo, before it resolves packages or builds. It does
# the two things this repo's structure forces, neither provided by a plain `git clone`:
#
#   1. Stamp CURRENT_PROJECT_VERSION from $CI_BUILD_NUMBER — before XcodeGen runs.
#   2. Generate Kiln.xcodeproj — gitignored; XcodeGen owns it (project.yml).
#
# Deliberately absent, and each absence is a property of Kiln worth preserving:
#
#   - No secrets reconstitution. Kiln ships no API keys and declares no network
#     entitlement. Everything runs against on-device frameworks.
#   - No Package.resolved install. Kiln has no package dependencies at all.
#   - No SPM build-tool plugin pre-trust. Nothing in the graph carries one.
#
# All three change the day mlx-swift arrives (ADR-002, the Neural half). Adding it
# reintroduces the CudaBuild build-tool plugin, which needs an interactive
# "Trust & Enable" that Cloud cannot grant — Cloud generates its own xcodebuild
# invocation and accepts no extra flags. Pin mlx-swift with an explicit upper bound and
# commit spm/Package.resolved when that day comes; `from:` is a floor, not a pin.
#
set -eu

echo "--- ci_post_clone: locating the project ---"
# On Cloud the checkout root is $CI_PRIMARY_REPOSITORY_PATH. Locally we resolve relative
# to this script, so the same script is runnable off-Cloud for testing.
if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  ROOT="$CI_PRIMARY_REPOSITORY_PATH"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
cd "$ROOT"
echo "    root: $ROOT"

# Must run BEFORE xcodegen: XcodeGen bakes project.yml's CURRENT_PROJECT_VERSION into the
# generated project, and that value — not $CI_BUILD_NUMBER — is what ends up in the
# archive's CFBundleVersion.
#
# Xcode Cloud's build-number setting only moves the environment variable. Without this
# stamp, Cloud would count 42 and upload a binary marked 1, colliding with whatever is
# already in TestFlight. App Store Connect rejects duplicates.
#
# So: Cloud owns the build number for anything Cloud builds. project.yml's committed value
# stays the source of truth for local builds. This rewrites the clone-time working copy
# only and is never committed.
#
# No-op off-Cloud: without $CI_BUILD_NUMBER, project.yml is left untouched.
echo "--- ci_post_clone: stamping the build number ---"
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  CURRENT=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*"\{0,1\}\([0-9][0-9]*\)"\{0,1\}[[:space:]]*$/\1/p' project.yml | head -1)
  [ -n "$CURRENT" ] || { echo "    ERROR: could not read CURRENT_PROJECT_VERSION from project.yml" >&2; exit 1; }
  # Guard the collision this exists to prevent: going backwards silently produces a
  # duplicate or out-of-order build. Fix by raising Cloud's counter in App Store Connect
  # (Xcode Cloud > Settings > Build Number) above the latest real build.
  if [ "$CI_BUILD_NUMBER" -le "$CURRENT" ]; then
    echo "    ERROR: CI_BUILD_NUMBER ($CI_BUILD_NUMBER) is not ahead of project.yml ($CURRENT)." >&2
    echo "           Raise it in App Store Connect > Xcode Cloud > Settings > Build Number." >&2
    exit 1
  fi
  sed -i.bak "s/^\([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*\).*$/\1\"$CI_BUILD_NUMBER\"/" project.yml
  rm -f project.yml.bak
  echo "    stamped CURRENT_PROJECT_VERSION: $CURRENT -> $CI_BUILD_NUMBER"
else
  echo "    CI_BUILD_NUMBER unset (not an Xcode Cloud run) — leaving project.yml alone"
fi

echo "--- ci_post_clone: generating Kiln.xcodeproj (XcodeGen) ---"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "    installing xcodegen via Homebrew"
  # Homebrew's auto-update costs ~15s per build and can fail on a slow formula fetch;
  # we only need the bottle.
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install xcodegen
fi
xcodegen generate
echo "    generated: $(ls -d Kiln.xcodeproj)"

echo "--- ci_post_clone: done ---"

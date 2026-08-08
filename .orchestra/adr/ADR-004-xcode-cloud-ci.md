---
id: ADR-004
status: accepted
created_on: 2026-08-08
---

# ADR-004: Xcode Cloud CI — adopt build + test now, defer archive

## Context

Kiln's project is generated (XcodeGen, gitignored), which a plain `git clone` cannot
build. That is the same structural fact that made CI non-obvious in a sibling project,
and it has the same fix: a post-clone hook.

Kiln is an unusually good CI candidate, for one reason that is easy to miss:

**It has no package dependencies at all.** `FoundationModels` is a system framework — no
package, no build-tool plugin, no fingerprint gate, no `Package.resolved`, no secrets, no
network entitlement. The single hardest CI problem in the sibling projects (an SPM
build-tool plugin requiring interactive "Trust & Enable", which Cloud cannot grant because
it generates its own `xcodebuild` invocation and accepts no extra flags) does not exist
here.

The test suite is also deterministic by construction (ADR-001, ADR-003). Nothing in the
default run needs Apple Intelligence enabled, a model downloaded, or a device eligible.
That is what makes a CI test action meaningful rather than a coin flip.

## Decision

**Adopt Xcode Cloud for build + test. Do not archive or upload yet.**

### Stage 1 — build gate

Cloud builds `Kiln-iOS` and `Kiln-macOS` from a clean clone. Green means the app compiles
without anything warm in a local DerivedData, and without a file that exists only on one
laptop.

### Stage 2 — test action, with a zero-test guard

**A test action without the guard is worse than no test action.**

`xcodebuild` can exit 0 having run nothing, printing "Test run with 0 tests in 1 suite
passed". In App Store Connect that renders as a green check, indistinguishable from a real
pass. No test action is honestly no signal; a false green is a signal you will act on.

`ci_scripts/ci_post_xcodebuild.sh` closes it by reading `totalTestCount` from the result
bundle, sourcing the *same* `scripts/lib/xcresult.sh` that the local runner uses. One
implementation, deliberately: a safety check that exists in one runner but not its twin is
the thing that drifts back out of sync. It fails closed — an unreadable or missing bundle
is *unproven*, never zero and never a pass.

Verified locally: a real run reports 10 tests and passes; a filter matching nothing
reports 0 and is rejected. (In that probe `xcodebuild` also exited 70 on its own — Xcode
26 fails loudly on a plainly bogus suite name. The guard is defence in depth for the
shapes that *do* exit 0, and because which shapes those are is an Xcode implementation
detail that has changed before.)

### Stage 3 — archive + TestFlight: deliberately not yet

Kiln is a lab. Nobody installs it from TestFlight. Archiving every push would spend
minutes producing builds no one runs, and would fill a TestFlight the app does not need.
Build + test is the whole signal at this stage.

The build-number stamping in `ci_post_clone.sh` is written and ready for the day that
changes, because it must run *before* XcodeGen — but it is inert until Cloud archives.

### Correction: an App Store Connect record is required regardless

An earlier draft of this ADR claimed that archiving needs an App Store Connect app record
while build and test do not, and used that as a reason to defer stage 3. **That is
wrong.** An app record must exist for Xcode Cloud at all — Apple's requirement is that
"an app record for your app must exist in App Store Connect, or you must have the
required role or permission to create one."

In practice the onboarding assistant checks whether the bundle identifier already exists
and creates the record for you if it does not, using the project's bundle ID and an SKU
it asks for. So it is a step inside workflow creation rather than separate preparation —
but it is not optional, and it does mean **setting up CI claims `land.paz.kiln` in App
Store Connect**. Bundle identifiers are not meaningfully reusable once registered, so
that is a decision to make deliberately rather than discover.

The staging decision is unchanged; only its justification was faulty. Deferring the
archive still rests on what Kiln is, which was always the stronger of the two reasons.

## Workflow topology

| Workflow | Start condition | Actions |
|---|---|---|
| `PR Gate` | **pull requests targeting `main`** | Build + Test (both platforms) |
| `Release` | manual, later | Build + Test + Archive + TestFlight |

### Trigger on pull requests, never on branch-name patterns

This is the load-bearing decision and it is easy to get wrong, because branch patterns
look tidier.

A `feat/*` pattern silently skips CI for any branch named otherwise. It does not error —
it does nothing, which is the worst available behaviour for a safety net. A workflow that
does not run produces no red.

A PR-targeting-`main` condition covers every branch regardless of prefix and cannot be
opted out of by accident.

### Two traps inherited from a sibling project, at zero cost

Both were paid for elsewhere. They are recorded here so Kiln never pays again.

**Distribution Preparation is a one-way door.** Any workflow that should ever reach
external testers or the App Store must use **"App Store Connect"** preparation — never
"TestFlight (Internal Testing Only)". The latter stamps every build
`buildAudienceType: INTERNAL_ONLY` permanently and immutably at upload. There is no
promotion path and no undo; a sibling project stranded thirteen builds that way. The
cautious-looking option is the trap. When a valid build refuses to appear in the external
picker, check `buildAudienceType` via the `iris/v1/builds/<id>` API first — the UI never
surfaces it.

**Secrets and environment variables attach per *workflow*, not per app.** A newly created
workflow starts with an empty environment, and variables set on another workflow are
invisible to it. Kiln has no secrets today, so this costs nothing now — but it will bite
the first time one is added.

## Consequences

- A green Cloud run means "compiles from clean, and N tests actually ran". Not more.
- Cost is not a constraint at this volume. A build-only run in a comparable project was
  ~6 minutes against a free allotment of 25 compute hours/month. Revisit only if build
  frequency changes by an order of magnitude.
- **Cloud requires a remote repository.** Kiln must be pushed to GitHub before any of this
  can run.
- **Cloud requires an App Store Connect app record**, created during onboarding from the
  project's bundle identifier. Enabling CI therefore registers `land.paz.kiln`. The bundle
  ID in `project.yml` must match the record exactly, or builds fail to associate.
- The post-clone hook is currently three-quarters absent by design — no secrets, no
  `Package.resolved`, no plugin trust. Adding `mlx-swift` (ADR-002) reinstates all three.
  Its comment block names them so that day is a lookup rather than a rediscovery.
- Local `./scripts/run-tests.sh` stays the fast inner loop and works offline. Only the
  gate is coupled to Apple's infrastructure.

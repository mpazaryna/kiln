---
id: ADR-004
status: accepted
created_on: 2026-08-08
---

# ADR-004: Xcode Cloud CI — build + test as a gate, archive on a separate workflow

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

**Adopt Xcode Cloud. A PR gate builds and tests; a separate Release workflow archives
and ships to TestFlight.**

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

### Stage 3 — archive + TestFlight: adopted

An earlier version of this ADR deferred stage 3 on the reasoning that "Kiln is a lab,
nobody installs it from TestFlight." **That was an assumption, and it was wrong.**
Colleagues and other developers are exactly the audience for a teaching repository, and
most of them want to *see the thing run* without cloning it, installing XcodeGen,
supplying their own team ID, and building it.

TestFlight is how a Swift project is demonstrated to people who are not going to build
it. That is a first-class use for this repo, not an afterthought.

**But archiving stays on a separate workflow from the gate.** The PR Gate does not
archive: it costs minutes on every pull request and produces builds nobody installs. The
`Release` workflow archives; the gate proves.

Consequences of turning this on:

- **The build-number stamping in `ci_post_clone.sh` becomes load-bearing.** It must run
  before XcodeGen, because the archive takes `CFBundleVersion` from the generated project
  rather than from `$CI_BUILD_NUMBER`. Until now it has been inert.
- **Exactly one thing may own the build number.** That is now Cloud. Any local archive
  during Cloud's tenure needs the number reconciled deliberately.
- **Distribution Preparation must be "App Store Connect".** See the trap below. This is
  the single most consequential setting in the whole configuration and it cannot be
  undone per-build.

### Internal vs external testers — decide before inviting anyone

These are different mechanisms and the difference matters here:

- **Internal** — up to 100 App Store Connect users on your team. No Beta App Review.
  Builds are available within minutes. Right for colleagues you can add to the team.
- **External** — up to 10,000 testers, invited by email or a public link. **Requires Beta
  App Review** for the first build of each version. Right for "other developers" at large,
  and the public link is what makes a teaching repo shareable.

External is the one worth thinking about before committing. Kiln is currently a single
screen that runs one prompt. "App is incomplete" is a real Beta App Review rejection
reason, and a lab whose entire UI is a text field and a Fire button is a plausible
candidate for it. That is an argument for filling out the Playground/Runs surfaces before
opening an external group — not an argument against TestFlight.

### TestFlight builds expire after 90 days

Whatever a colleague installs stops launching 90 days after upload, with no failure on our
side except not having shipped. For a demo channel that is acceptable; it just means the
expiry date is knowable at upload time and belongs on a calendar. If Kiln ever becomes
something people *depend* on rather than look at, that is the point to consider unlisted
App Store distribution instead.

### Correction: an App Store Connect record is required regardless

An earlier draft of this ADR claimed that archiving needs an App Store Connect app record
while build and test do not, and used that as a reason to defer stage 3. **That is
wrong.** An app record must exist for Xcode Cloud at all — Apple's requirement is that
"an app record for your app must exist in App Store Connect, or you must have the
required role or permission to create one."

Apple's documentation implies the onboarding assistant will create the record for you
from the project's bundle ID. **In practice, on Xcode 26, it did not.** The assistant
refused to advance and reported the app *name* as invalid — a misleading error, since no
variation of the name helped. The fix was to create the app in App Store Connect first,
then return to Xcode.

So the working order is:

1. **Create the app record in App Store Connect** — Apps → + → New App — before touching
   Xcode Cloud.
2. Then run the Xcode Cloud onboarding, which finds the existing record instead of trying
   to make one.

Do not rely on the assistant to bootstrap the record, and do not trust its error text:
it collapses several distinct failure modes into a complaint about whichever field it
happens to highlight. Creating the app directly gives specific errors; the assistant
gives one unhelpful line.

This also means **setting up CI claims `land.paz.kiln` in App Store Connect**. Bundle
identifiers are not meaningfully reusable once registered, so that is a decision to make
deliberately rather than discover.

Note the App Store Connect *app name* is globally unique across the entire App Store and
is unrelated to the project's identity. "Kiln" is long since taken. The store-listing
name has no bearing on the repository name, the bundle identifier, or
`INFOPLIST_KEY_CFBundleDisplayName` — which is what actually appears under the icon.

Both of this ADR's corrections came from reasoning about Apple's tooling from
documentation rather than from clicking through it. Where the two disagree, the clicking
wins — record what actually happened, not what the docs imply.

## Workflow topology

| Workflow | Start condition | Actions |
|---|---|---|
| `PR Gate` | **pull requests targeting `main`** | Build + Test (both platforms) |
| `Release` | `main` changes, or manual | Build + Test + Archive + TestFlight |

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

**Distribution Preparation is a one-way door, and the trap is the DEFAULT.** Any workflow
that should ever reach external testers or the App Store must use **"App Store Connect"**
preparation — never "TestFlight (Internal Testing Only)".

Observed on Kiln, 2026-08-08: the workflow Xcode's onboarding assistant generates arrives
with **"TestFlight (Internal Testing Only)" preselected on every Archive action**. A
sibling project's ADR framed this as a cautious choice someone makes; that understates it.
It is what you get by not choosing. Check both radio buttons on every Archive action of
every assistant-generated workflow before the first upload — after that it is too late for
the builds already sent. The latter stamps every build
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

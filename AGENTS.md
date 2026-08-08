# Kiln — Apple Foundation Models workbench

SwiftUI iOS/macOS lab for on-device intelligence. See [README](README.md) for what the
name means and how to build.

---

## Hard Rules

### XcodeGen — the project is generated

**Never edit `Kiln.xcodeproj`.** It is generated from `project.yml` and gitignored.

- Sources are auto-discovered from `Kiln/` and `KilnTests/` — just create the file
- Add packages in `project.yml`, not the Xcode UI
- After editing `project.yml`: `xcodegen generate`
- A pre-build script regenerates on every build, so new files are picked up next build

### All layout values go in config structs (ADR-000)

No magic numbers in view bodies. No `#if os(...)` inside `body`. No `sizeClass ==` checks
in views.

```swift
// NEVER: .padding(16) / .frame(height: 150) / .font(.system(size: 17))
// ALWAYS: .padding(config.cardPadding)
```

Every view with layout values defines a `fileprivate` config in its own file, flattening
shared values from `BasePlatformConfig`. Flatten, never nest — `config.cardPadding`, not
`config.base.cardPadding`.

### No ViewModels (ADR-001)

`@State` for view state, `@Environment` for services, enums for mutually exclusive
states, business logic in services. Split large views into subviews.

### Every model goes through `KilnModel` (ADR-002)

Views never name a concrete provider. They resolve one through `ModelRegistry` and call
the protocol. This holds even though there is currently one conformance — comparison is
the point of the lab.

### Availability does not guarantee generation (ADR-003)

A provider can report `.available` and still fail the request — the Simulator commonly
lacks guardrail assets, so generation fails with `assetsUnavailable` after a clean
pre-flight. Never flatten a failure to `localizedDescription`. Map it to a
`KilnGenerationIssue` and carry summary, recovery, and raw detail separately.

**Run live prompts on a real device or the macOS app, not the iOS Simulator.**

### Tests must be deterministic

The default test run must not depend on whether Apple Intelligence is enabled, downloaded,
or in a good mood. Stub `KilnModel` for logic tests. Live-model runs, when they exist, go
in a separately-invoked category.

A run is a pass only if it exits 0 **and** executed at least one test. Use
`./scripts/run-tests.sh`, which enforces this via `scripts/lib/xcresult.sh` — the same
library Xcode Cloud's post-xcodebuild hook sources, so the check cannot drift between
them. A green run that tested nothing is worse than no run.

### On-device only

No network entitlement, no API keys, no secrets. If a provider ever needs the network,
that is a deliberate, reviewed change to the sandbox — not a quiet default.

### Public repository

Nothing from private projects crosses over: no client data, no proprietary models, no
internal identifiers. Assume every commit message and comment is read by someone
learning from it, because that is the point.

---

## Commands

```bash
xcodegen generate

./scripts/run-tests.sh              # macOS, guarded (default)
./scripts/run-tests.sh ios          # iOS Simulator, guarded
./scripts/run-tests.sh all

xcodebuild -project Kiln.xcodeproj -scheme Kiln-macOS -configuration Debug build
xcodebuild -project Kiln.xcodeproj -scheme Kiln-iOS -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild test -project Kiln.xcodeproj -scheme Kiln-macOS -configuration Debug
```

---

## Structure

```
Kiln/
├── App/                      # KilnApp — entry point, service injection
├── Core/
│   ├── Configuration/        # PlatformConfig.swift — ALL layout values
│   └── Intelligence/         # KilnModel, AppleIntelligenceModel, ModelRegistry
└── Views/                    # SwiftUI views, one fileprivate config each
KilnTests/                    # Deterministic unit tests
scripts/                      # run-tests.sh, lib/xcresult.sh (shared with CI),
                              # create-xcode-cloud-workflow.sh (ASC API)
ci_scripts/                   # Xcode Cloud hooks (post-clone, post-xcodebuild)
.orchestra/                   # Agent knowledge base — see .orchestra/README.md
├── adr/                      # Architecture decisions
├── work/                     # Per-work-item PRD, spec, gherkin (TEMPLATES/ to copy)
├── uml/                      # Mermaid diagrams
└── devlog/                   # Chronological session journal, by quarter
```

---

## Orchestra SDLC — required workflow

Work in this project follows the Orchestra lifecycle, served by the `orchestra` MCP
server. `.orchestra/` is the shared knowledge base — read the ADRs, and the roadmap once
it exists, before acting on any work item.

Before starting anything non-trivial:

1. `orchestra_list_stages` to orient — intake → prd → spec → gherkin → plan → execute.
2. `orchestra_list_skills`, then `orchestra_get_skill` for the activity at hand, and
   follow it as the playbook.
3. Respect the gates (`orchestra_get_gates`): a PRD before a spec, a spec before
   implementation, and explicit human approval at each one.

Record sessions with `orchestra_devlog_entry` (write the file it returns to
`.orchestra/devlog/`). Record significant decisions as ADRs. See
[ADR-005](.orchestra/adr/ADR-005-the-score.md).

---

## ADRs

- `ADR-000-platform-config` — all layout values in configs (read before any UI work)
- `ADR-001-no-viewmodels-in-swiftui` — SwiftUI state management
- `ADR-002-model-provider-seam` — the `KilnModel` protocol and why it exists early
- `ADR-003-availability-is-not-sufficiency` — failure mapping; Simulator asset caveat
- `ADR-004-xcode-cloud-ci` — CI staging, zero-test guard, Distribution Preparation trap
- `ADR-005-the-score` — the Orchestra SDLC itself; why the score is not ADR-000 here

---

## Roadmap

**Language** (now) — Apple Intelligence through the seam. Prompt, response, availability.

**Neural** (later) — an MLX-backed provider as a second `KilnModel` conformance. Adding
`mlx-swift` reintroduces a `CudaBuild` build-tool plugin that headless CI cannot grant
interactively; pin with an explicit upper bound and commit `spm/Package.resolved` when
that day comes. `from:` is a floor, not a pin.

**iOS 27** — adopt the system `LanguageModel` protocol. `AppleIntelligenceModel` becomes a
bridge; views do not change. That is the seam earning its keep.

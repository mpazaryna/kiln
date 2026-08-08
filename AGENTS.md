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

### Tests must be deterministic

The default test run must not depend on whether Apple Intelligence is enabled, downloaded,
or in a good mood. Stub `KilnModel` for logic tests. Live-model runs, when they exist, go
in a separately-invoked category.

A run is a pass only if it exits 0 **and** executed at least one test. `xcodebuild` exits
0 when a filter matches nothing — a green run that tested nothing is worse than no run.

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
.orchestra/adr/               # Architecture decisions
```

---

## ADRs

- `ADR-000-platform-config` — all layout values in configs (read before any UI work)
- `ADR-001-no-viewmodels-in-swiftui` — SwiftUI state management
- `ADR-002-model-provider-seam` — the `KilnModel` protocol and why it exists early

---

## Roadmap

**Language** (now) — Apple Intelligence through the seam. Prompt, response, availability.

**Neural** (later) — an MLX-backed provider as a second `KilnModel` conformance. Adding
`mlx-swift` reintroduces a `CudaBuild` build-tool plugin that headless CI cannot grant
interactively; pin with an explicit upper bound and commit `spm/Package.resolved` when
that day comes. `from:` is a floor, not a pin.

**iOS 27** — adopt the system `LanguageModel` protocol. `AppleIntelligenceModel` becomes a
bridge; views do not change. That is the seam earning its keep.

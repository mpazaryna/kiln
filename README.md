# Kiln

A workbench for Apple's on-device intelligence, on iOS and macOS.

A kiln fires raw material at high heat, in one sealed chamber, into something permanent.
Nothing leaves the room. That is on-device inference, and it is what this repository is
for: a place to load a model, fire a prompt at it, and look closely at what comes out.

## The name

Kiln is a mnemonic, and it expands three ways depending on which part you care about:

| | |
|---|---|
| **K**it: **I**ntelligence **L**ab, **N**ative | What it is — a kit, a lab, on-device |
| **K**nowledge & **I**ntelligence **L**ab, **N**ative | What it studies |
| **K**it for **I**ntelligence, **L**anguage & **N**eural models | What is in scope |

The third is the one that carries the roadmap. **Language** is the Apple Foundation
Models half, built now. **Neural** is the MLX half, deliberately deferred — see
[ADR-002](.orchestra/adr/ADR-002-model-provider-seam.md).

## Status

Early. `Hello, Kiln` runs a prompt against Apple Intelligence and shows the response, on
both platforms. That is the whole app today, and it is enough to have established the
three patterns everything else inherits.

## Requirements

- iOS 26 / macOS 26 or later
- Apple Silicon, with Apple Intelligence enabled, for live runs
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

> **Run live prompts on a real device or the macOS app, not the iOS Simulator.**
> The Simulator's model catalog frequently lacks the guardrail assets
> (`com.apple.fm.language.instruct_300m.safety`). Availability still reports
> `.available`, and generation then fails with `assetsUnavailable`. Kiln names this
> case explicitly rather than reporting a generic error — see
> [ADR-003](.orchestra/adr/ADR-003-availability-is-not-sufficiency.md).

## Build

`Kiln.xcodeproj` is generated and **not** committed. Generate it first:

```bash
xcodegen generate
open Kiln.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Kiln.xcodeproj -scheme Kiln-macOS -configuration Debug build
xcodebuild -project Kiln.xcodeproj -scheme Kiln-iOS -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild test -project Kiln.xcodeproj -scheme Kiln-macOS -configuration Debug
```

Never edit `Kiln.xcodeproj` directly — it is regenerated from `project.yml` on every
build. Add sources by creating files (they are auto-discovered) and packages by editing
`project.yml`.

## How it is built

Three decisions do most of the work, and each is written down.

**[ADR-000 — Platform Config](.orchestra/adr/ADR-000-platform-config.md).** Every layout
value lives in a config struct. Views contain no magic numbers and no `#if os(...)` in
the body. A view reads `config.cardPadding`, never `16`.

**[ADR-001 — No ViewModels](.orchestra/adr/ADR-001-no-viewmodels-in-swiftui.md).**
`@State` for view state, `@Environment` for services, enums for mutually exclusive
states, business logic in services. SwiftUI views are structs; MVVM fights that.

**[ADR-002 — Model Provider Seam](.orchestra/adr/ADR-002-model-provider-seam.md).** Every
model is reached through the `KilnModel` protocol, including the only one that currently
exists. Comparing providers is the point of the lab, so the abstraction is present from
the first commit rather than retrofitted at the second provider.

```
Kiln/
├── App/                      # Entry point, service injection
├── Core/
│   ├── Configuration/        # PlatformConfig.swift — ALL layout values
│   └── Intelligence/         # KilnModel seam, providers, registry
└── Views/                    # SwiftUI views, one local config each
```

## On-device only

Kiln declares no network entitlement and ships no API keys. Everything runs against
frameworks already on the device. If a future provider needs the network, that becomes a
deliberate, visible change to the sandbox — not a quiet default.

## License

Apache-2.0. See [LICENSE](LICENSE).

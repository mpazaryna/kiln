---
ticket: "#6"
status: draft
created_on: 2026-08-08
---

# iOS 27

**Objective:** Kiln runs on the iOS/macOS 27 `FoundationModels` surface — the new error
taxonomy, capability pre-flight, token usage and transcript entries — with the change
contained to the provider and nothing above the seam moving.

> **Superseded objective (2026-08-08):** *"Adopt the system `LanguageModel` protocol.
> `AppleIntelligenceModel` becomes a bridge."* That was aimed at the wrong protocol. See
> **Finding 3** below: `LanguageModel` is the custom-provider path and belongs to Neural
> (#5), not here.

## Success Criteria

- [x] Builds and tests green against Xcode 27 with a 27.0 deployment target
- [x] No use of deprecated `LanguageModelSession.GenerationError`
- [x] Capability read from the framework and surfaced before a run, not discovered by one
- [x] `usage` and transcript entries carried through the seam rather than discarded
- [ ] Reasoning exercised end-to-end — **blocked**, see Finding 1: no available model
      advertises the capability on-device
- [ ] Xcode Cloud builds on Xcode 27 (ADR-004 pipeline is version-pinned)

## Context

Part of the [Kiln Roadmap](../../roadmap.md). Was gated on the OS; the gate is now lifted
— every machine is on 27 and Xcode 27 (27A5252f) is installed. The measure of success is
how little has to change above the seam — see
[ADR-002](../../adr/ADR-002-model-provider-seam.md).

**Measured:** raising the deployment target produced exactly four deprecation warnings,
all in `AppleIntelligenceModel.swift`. Nothing in the views, the registry, the protocol,
or the config. The seam held.

## Finding — 2026-08-08: this milestone was aimed at the wrong risk

An iPad was updated to iOS 27 beta 3. The TestFlight build already installed on it —
unchanged, built against the iOS 26 SDK — began returning the model's reasoning alongside
its answer:

> to answer this question, I will first check if there is any tool available to retrieve
> information about kiln's function

Kiln registers no tools anywhere. **Nothing failed.** `respond` returned normally, no
error was thrown, `.success` rendered. ADR-003 says availability does not guarantee
generation; this is the next step along — generation succeeding does not guarantee a
*response*.

**The part that matters:** no code changed, no rebuild happened, and the behaviour changed
anyway. This PRD assumed the work was API breakage at compile time. The first real symptom
was silent behavioural drift in a shipped binary.

## Findings — 2026-09-07: verified against Xcode 27 and the live model

The 2026-08-08 notes were cross-checked against a third-party interface dump. Three of
them did not survive first-hand verification. Session write-up:
[`devlog/2026-Q3/2026-09-07-ios-27-adopted-reasoning-not-supported.md`](../../devlog/2026-Q3/2026-09-07-ios-27-adopted-reasoning-not-supported.md).

### 1. The on-device model does not support reasoning

`SystemLanguageModel.default.capabilities` on macOS 27 reports `toolCalling`, `vision`,
`guidedGeneration` — and **not** `reasoning`. Requesting a `ReasoningLevel` throws
`LanguageModelError.unsupportedCapability`: *"The selected model does not support
reasoning. Consider trying again with a different model."*

So `ReasoningLevel`, `Transcript.Entry.reasoning` and `Usage.output.reasoningTokenCount`
exist but belong to another model. `PrivateCloudComputeLanguageModel` is the likely
candidate — and it is off-device, which puts it against the on-device-only rule in
`AGENTS.md`. **Open question, ADR before code.**

### 2. #7 did not reproduce on macOS 27

Clean answer, no tool-search preamble, `reasoningTokenCount = 0`, only a `.response`
entry. `toolCallingMode = .disallowed` changed nothing measurable (65 in / 39 out either
way). Kiln now defaults to `.disallowed` anyway — it registers no tools. The defect stays
open: **unreproduced here, not disproven.** The iPad symptom was beta 3 specifically.

### 3. `LanguageModel` is a model descriptor, not a session protocol

```swift
public protocol LanguageModel: Sendable {
  associatedtype Executor: LanguageModelExecutor where Self == Self.Executor.Model
  var capabilities: LanguageModelCapabilities { get }
  var executorConfiguration: Self.Executor.Configuration { get }
}
```

Paired with a `LanguageModelExecutor` that does the work; the path for supplying a custom
model *into* a `LanguageModelSession`. Apple Intelligence already is the system model, so
`AppleIntelligenceModel` does not conform to it. **This is the Neural (#5) path.**

### 4. The error taxonomy shifted, and is no longer constructible in tests

`GenerationError` is `deprecated: 27.0` → `LanguageModelError`. `assetsUnavailable` moved
to `SystemLanguageModel.Error`; `concurrentRequests` and `decodingFailure` are gone;
`timeout`, `unsupportedCapability` and `unsupportedTranscriptContent` arrived.

The new payload structs have **no public initializers**, so ADR-003's stated testing
pattern — construct the framework error, assert the mapping — no longer works.
`LanguageModelSession.Usage` is still constructible, so token mapping stays deterministic.
This is a real coverage loss on the code ADR-003 exists to protect.

## Materials

| Material | Location | Status |
|----------|----------|--------|
| Seam carries run evidence + capabilities | `Kiln/Core/Intelligence/KilnModel.swift` | Done |
| Provider on the 27 API | `Kiln/Core/Intelligence/AppleIntelligenceModel.swift` | Done |
| Capability-gated controls, usage metrics | `Kiln/Views/HelloKilnView.swift` | Done |
| Suite rebuilt for 27 constructibility | `KilnTests/` | Done |
| `Tool` conformance + neutral tool identifiers | `Kiln/Core/Intelligence/Tools/` | Done |
| CLI probe target for API exploration | `KilnProbe/`, `scripts/probe.sh` | Done |
| ADR-003 amendment — capability stage + testability loss | `.orchestra/adr/` | Not Started |
| ADR-002 amendment — `LanguageModel` is the Neural path | `.orchestra/adr/` | Not Started |
| ADR — Private Cloud Compute vs on-device-only | `.orchestra/adr/` | Not Started |
| Xcode Cloud on Xcode 27 | `ci_scripts/`, ASC workflow | Not Started |

## Notes

**The earlier constraint has been overridden deliberately.** It read: *"Do not adopt an
Xcode 27 beta to chase this… held at iOS 26 until every machine can move together."* Every
machine is now on 27 and the project has moved with them. The reasoning behind the
constraint was sound and one part of it still stands: the interface is a beta and may
still move, so `project.yml` now requires Xcode 27 and **Xcode Cloud has not been verified
against it**. That is the open risk ADR-004 cares about.

Tracked as #6; the defect itself is #7.

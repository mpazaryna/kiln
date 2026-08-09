---
ticket: SHE-28
status: draft
created_on: 2026-08-08
---

# iOS 27

**Objective:** Adopt the system `LanguageModel` protocol. `AppleIntelligenceModel` becomes
a bridge and the views do not change — the seam earning its keep.

## Success Criteria

- [ ] To be defined — run /orchestra-plan to flesh this out

## Context

Part of the [Kiln Roadmap](../../roadmap.md). Gated on the OS, not on us. The measure of
success is how little has to change above the seam — see
[ADR-002](../../adr/ADR-002-model-provider-seam.md).

## Finding — 2026-08-08: this milestone was aimed at the wrong risk

An iPad was updated to iOS 27 beta 3. The TestFlight build already installed on it —
unchanged, built against the iOS 26 SDK — began returning the model's reasoning alongside
its answer:

> to answer this question, I will first check if there is any tool available to retrieve
> information about kiln's function

Kiln registers no tools anywhere. `HelloKilnView` passes `instructions: nil`, so the
session is a bare `LanguageModelSession()`. A session with zero tools narrating a search
for tools places the behaviour in the framework, not in anything this project configured.

**Nothing failed.** `respond(to:instructions:)` returned normally, no error was thrown,
`.success` rendered. ADR-003 says availability does not guarantee generation; this is the
next step along — generation succeeding does not guarantee a *response*.

**The part that matters:** no code changed, no rebuild happened, and the behaviour changed
anyway. This PRD assumed the work was API breakage at compile time. The first real symptom
was silent behavioural drift in a shipped binary, which no ADR anticipates and which is
harder to catch precisely because nothing fails.

### What iOS 27 beta 3 added

Confirmed against the Xcode 27 beta interface tracked in
`rudrankriyam/Foundation-Models-Framework-Lab` (commit `8bf0a50`):

- `Transcript.Entry.reasoning(Transcript.Reasoning)` — reasoning as a first-class entry
- `ContextOptions.ReasoningLevel` — `.light` / `.moderate` / `.deep` / `.custom(String)`
- `GenerationOptions.toolCallingMode` — `.allowed` / `.required` / `.disallowed`
- `LanguageModelCapabilities` gains `.reasoning` and `.toolCalling`
- `onReasoning` lifecycle hooks on `DynamicProfile`
- `LanguageModelSession.Response` gains `usage`, carrying `reasoningTokenCount`

An iOS 26 client has no surface to receive a reasoning entry, and
`AppleIntelligenceModel.swift` returns `response.content` unmodified.

**Confidence:** the capability change and the SDK mismatch are verified. The causal link
between them is a strong inference, not a confirmed fact — confirming it means building
against Xcode 27 and seeing whether reasoning separates into its own entry.

### Likely scope when unblocked

- Set `toolCallingMode` to `.disallowed` — Kiln registers no tools, so a tool search is
  pure waste
- Set `reasoningLevel`, probably `.light` by default and exposed as a lab control
- Route `Transcript.Reasoning` entries to their own surface rather than into the answer
- Surface `usage.reasoningTokenCount`

### Constraint

**Do not adopt an Xcode 27 beta to chase this.** The interface is still moving — beta 2 to
beta 3 renamed `SamplingMode.Kind` cases, and beta 4 rewrote 155 lines of the interface two
weeks after beta 3. A beta toolchain on the primary dev box also drags Xcode Cloud with it,
trading a working release pipeline for an API that cannot ship. Held at iOS 26 until every
machine can move together.

## Materials

| Material | Location | Status |
|----------|----------|--------|
| To be defined | | Not Started |

## Notes

Run /orchestra-plan ios-27 to start the planning loop for this milestone.

Tracked as SHE-28; the defect itself is SHE-29. Session write-up:
[`devlog/2026-Q3/2026-08-08-ios-27-reasoning-drift.md`](../../devlog/2026-Q3/2026-08-08-ios-27-reasoning-drift.md).

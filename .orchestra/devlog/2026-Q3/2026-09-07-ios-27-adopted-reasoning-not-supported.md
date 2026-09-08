---
created_on: 2026-09-07
---

# 2026-09-07: Moved to macOS 27 and the new FoundationModels API — and the on-device model has no reasoning

## Summary

Kiln now targets macOS/iOS 27.0, builds against Xcode 27 (27A5252f), runs in Swift 6
language mode, and uses the new `FoundationModels` surface. 16 tests pass through the
guarded runner, zero warnings.

The headline finding is not the migration. It is that **the macOS 27 on-device system
model does not support reasoning at all**, which contradicts the premise the `iOS 27`
milestone and the 2026-08-08 devlog were both written on.

## The hold was lifted, and one premise did not survive it

`.orchestra/work/ios-27/prd.md` carried a constraint — do not adopt an Xcode 27 beta,
the interface is still moving. That was overridden deliberately: every machine is on 27
now. Xcode 27.0 was already installed at `/Applications/Xcode-beta.app`; it simply was
not the selected toolchain, which is why an earlier probe saw only the 26.5 SDKs.

Everything below was verified first-hand against the real 27.0 interface and against the
live model on this Mac, rather than inferred from the interface dump in
`rudrankriyam/Foundation-Models-Framework-Lab`. Three things the PRD recorded turned out
to be wrong or imprecise.

### 1. The on-device model has no reasoning capability

```
=== CAPABILITIES ===
toolCalling, vision, guidedGeneration
contains(.reasoning) = false
```

Asking for one anyway throws:

```
LanguageModelError.unsupportedCapability
debugDescription: "The selected model does not support reasoning.
                   Consider trying again with a different model."
errorDescription:  "The model doesn't support the requested capability."
recoverySuggestion: nil
```

So `ContextOptions.ReasoningLevel`, `Transcript.Entry.reasoning` and
`Usage.output.reasoningTokenCount` are real, but they belong to some *other* model — the
error's own wording points at one. `PrivateCloudComputeLanguageModel` is the obvious
candidate and is off-device by definition, which puts it against the on-device-only rule
in `AGENTS.md`. That is an ADR decision, not a quiet import.

### 2. SHE-29 did not reproduce

The default prompt returned a clean two-sentence answer with no "checking if there is any
tool available" preamble, `reasoningTokenCount = 0`, and only a `.response` transcript
entry. Setting `toolCallingMode = .disallowed` changed nothing measurable — identical
65 in / 39 out token counts.

The iPad symptom was iPadOS 27 beta 3. Either it was a beta defect since fixed, or it is
specific to a model variant this Mac does not run. Kiln now defaults to `.disallowed`
regardless, because it registers no tools and a tool search is pure waste — but the
defect should not be closed on this evidence. It is unreproduced here, not disproven.

### 3. `LanguageModel` is not what the milestone assumed

```swift
public protocol LanguageModel: Sendable {
  associatedtype Executor: LanguageModelExecutor where Self == Self.Executor.Model
  var capabilities: LanguageModelCapabilities { get }
  var executorConfiguration: Self.Executor.Configuration { get }
}
```

It is a model *descriptor* paired with an executor that does the work — the path for
supplying a custom model *into* a `LanguageModelSession`. Apple Intelligence already is
the system model, so `AppleIntelligenceModel` does not and should not conform to it.

The milestone's stated objective — "adopt the system `LanguageModel` protocol,
`AppleIntelligenceModel` becomes a bridge" — was aimed at the wrong target. This protocol
is the **Neural/MLX** story, confirming the open question the last devlog raised.

## What shipped

| Change | File |
|---|---|
| Deployment target 26 → 27, Xcode 27, Swift 6 language mode | `project.yml` |
| `respond → String` replaced by `run → KilnRun` (content, usage, entry kinds, duration) | `Kiln/Core/Intelligence/KilnModel.swift` |
| `capabilities` added to the seam; `KilnRunOptions` for tool calling / reasoning / sampling | `Kiln/Core/Intelligence/KilnModel.swift` |
| `GenerationError` → `LanguageModelError`; capability pre-flight; usage + transcript mapping | `Kiln/Core/Intelligence/AppleIntelligenceModel.swift` |
| Token/duration/transcript metrics; capability-gated controls | `Kiln/Views/HelloKilnView.swift` |
| Suite rebuilt around what iOS 27 leaves constructible | `KilnTests/` |

The whole framework migration landed in `AppleIntelligenceModel.swift`. Measured before
any code was written: raising the deployment target produced exactly **four deprecation
warnings, all in that one file** (lines 53, 72, 90, 91), and none anywhere else. ADR-002
claimed the seam would absorb a framework change without views moving. That is now a
measurement rather than an assertion.

## The error taxonomy genuinely shifted

`LanguageModelSession.GenerationError` is `deprecated: 27.0`. It is not a rename:

| Kiln issue | iOS 27 |
|---|---|
| `contextWindowExceeded` | → `contextSizeExceeded` |
| `guardrailViolation`, `refused`, `rateLimited`, `unsupportedLanguageOrLocale` | carried over |
| `assetsUnavailable` | moved to `SystemLanguageModel.Error` — model-level, not generation-level |
| `concurrentRequests`, `decodingFailure` | gone from the new enum |
| — | new: `timeout`, `unsupportedCapability`, `unsupportedTranscriptContent` |

Kiln keeps the departed cases. They still describe how a provider can fail, and an MLX
provider will need them. ADR-003 said a recurring `other` is the signal to add a case;
this time the signal arrived from the framework instead of from traffic.

## The gotcha: the new errors are not constructible

ADR-003 recorded a testing pattern — "tests construct `GenerationError` cases directly,
`Context` has a public initializer, so the mapping is verified without a live model."
**That no longer works.** The `LanguageModelError` payload structs expose public
properties and *zero* public initializers. `AppleIntelligenceModel.issue(for:)` and
`detail(for:)` can no longer be unit-tested by construction.

`LanguageModelSession.Usage` does still have public initializers, so token mapping stays
deterministic. The suite was rebuilt around that line: everything on Kiln's side of the
seam is tested, and the two framework-error mappers are now covered only by reading.
That is a real loss of coverage on the exact code ADR-003 exists to protect, and it
should be recorded as a consequence rather than papered over.

Note also that `recoverySuggestion` came back `nil` on the one live error we provoked.
Kiln supplying its own recovery text is doing more work under iOS 27, not less.

## Next

- Amend ADR-003: capability is a third pre-flight stage, and record the testability loss
- Amend ADR-002: `LanguageModel`/`LanguageModelExecutor` is the Neural path, not a bridge
  for `AppleIntelligenceModel`
- Rewrite the `iOS 27` PRD objective — the current one is aimed at the wrong protocol
- Decide on `PrivateCloudComputeLanguageModel`: it is the likely home of reasoning, and
  it is off-device. ADR before code
- Check whether Xcode Cloud offers Xcode 27 before this reaches CI — `project.yml` now
  requires it, and ADR-004's pipeline is pinned
- SHE-29 stays open: unreproduced on macOS 27, not disproven

---
id: ADR-003
status: accepted
created_on: 2026-08-08
---

# ADR-003: Availability is not sufficiency — map failures, don't flatten them

## Context

The first `Hello, Kiln` run on the iOS Simulator produced this:

```
handleError: unknown top level error type: DecodingError.keyNotFound:
Key 'thoughtContents' not found ... Path: _response.candidates[0]

End sanitizeText with error: Error Domain=com.apple.SensitiveContentAnalysisML Code=15
"Failed model manager query for model com.apple.fm.language.instruct_300m.safety:
The data couldn't be read because it is missing."
```

Two facts matter here, and the second is the one worth writing down.

**First, the environment was broken, not the code.** The Simulator's model catalog had no
guardrail assets. `com.apple.fm.language.instruct_300m.safety` is a *separate* asset from
the main language model, and the Simulator frequently ships without it. The
`thoughtContents` decoding failure is downstream version skew between the framework and
the assets actually present. Nothing in Kiln caused this and nothing in Kiln can fix it.

**Second — and this is the defect — `SystemLanguageModel.default.availability` returned
`.available`.** The pre-flight check passed. The provider declared itself ready, accepted
the request, and only then failed on a dependency it had not checked.

The original `respond(to:)` caught everything and threw
`generationFailed(error.localizedDescription)`. That is how a broken simulator install and
a rejected prompt became the same red box.

## Decision

**Availability is a necessary but not sufficient precondition, and generation failures are
mapped to a provider-neutral taxonomy rather than flattened to a string.**

### Availability stays, but is not trusted as a guarantee

The pre-flight `availability` check is still worth doing — it catches the common,
cheap-to-detect cases before a request is made, and it is what lets the idle screen say
"Turn on Apple Intelligence" before the user presses anything.

But it is a *hint about likelihood*, not a contract. Any provider may fail at generation
time for reasons no pre-flight can see. Code must handle that path as a first-class
outcome, not an unexpected one.

### `KilnGenerationIssue` — provider-neutral failure kinds

Apple's `LanguageModelSession.GenerationError` cases map onto a Kiln enum:
`assetsUnavailable`, `contextWindowExceeded`, `guardrailViolation`, `refused`,
`rateLimited`, `concurrentRequests`, `unsupportedLanguageOrLocale`, `decodingFailure`,
`other`.

Provider-neutral is the point. An MLX-backed model can exhaust a context window or refuse
a prompt too, and **comparing how providers fail is as much the lab's job as comparing
what they produce.** Mapping each provider's native errors into this shape is the
provider's responsibility; views never see a framework-specific error type.

### Three pieces of information, kept separate

Every failure carries:

1. **summary** — what happened, in one line
2. **recovery** — what to do, or `nil` where there is genuinely nothing to do
3. **detail** — the framework's own debug text, verbatim

Keeping `detail` separate from `summary` is what lets the UI show a legible diagnosis
without discarding the evidence. In this incident the debug text named the exact missing
asset, which is the entire difference between a diagnosis and a shrug. **The raw text is
displayed, not hidden behind a disclosure** — in a lab it is usually the most valuable
thing on screen.

The recovery text for `assetsUnavailable` names the actual fix: run on a real device or
the macOS app.

## Consequences

- Every new provider must map its native errors into `KilnGenerationIssue`. That is real
  work per provider, and it is the work that makes providers comparable.
- The taxonomy will be wrong somewhere — a provider will fail in a way none of these
  cases describes. `other` exists for that, and a recurring `other` is a signal to add a
  case, not to widen an existing one.
- `unsupportedGuide` currently folds into `decodingFailure`. Both are "the response did
  not fit the requested shape," and separating them is not useful until structured output
  exists (ADR-002 defers it).
- Tests construct `GenerationError` cases directly — `Context` has a public initializer —
  so the mapping is verified without a live model. This is the pattern for all provider
  error handling: deterministic tests over real error values.

---

## Amendment — 2026-09-07: capability is a third stage, and the mapping lost its tests

iOS 27 extends this ADR's argument in one direction and undercuts its testing strategy in
another.

### Availability → capability → generation

This ADR established two stages: a provider can be *available* and still fail to
*generate*. iOS 27 adds a stage between them. `SystemLanguageModel.capabilities` on macOS
27 reports `toolCalling`, `vision` and `guidedGeneration` — and **not** `reasoning`. Ask
for a `ReasoningLevel` anyway and the request fails after a clean availability pre-flight:

```
LanguageModelError.unsupportedCapability
"The selected model does not support reasoning. Consider trying again with a different model."
```

So the chain is now: **available** (the provider will take a request) → **capable** (it
will take *this* request) → **generated** (it actually produced something). `KilnModel`
gained a `capabilities` property for the middle stage, read at call time for the same
reason availability is. The payoff is a UI that disables a control it cannot honour rather
than a lab that spends a request to discover the same thing.

### The framework's recovery text is thinner than ours

`LanguageModelError` carries `errorDescription` and `recoverySuggestion` of its own, which
looks at first like it makes `KilnGenerationIssue.recovery` redundant. It does not. The one
error we provoked live returned `recoverySuggestion: nil` on the case whose fix is most
obvious to a human. Kiln's own recovery text does *more* work under iOS 27, not less.

### The mapping is no longer testable by construction

This ADR recorded, as the pattern for all provider error handling: *"Tests construct
`GenerationError` cases directly — `Context` has a public initializer — so the mapping is
verified without a live model."*

**That no longer holds.** `GenerationError` is deprecated in favour of `LanguageModelError`,
whose payload structs (`GuardrailViolation`, `Timeout`, `UnsupportedCapability`, …) expose
public properties and **zero public initializers**. A test cannot build one, so
`AppleIntelligenceModel.issue(for:)` and `detail(for:)` are covered only by reading.

`LanguageModelSession.Usage` *is* still constructible, so response/token mapping stays
deterministic, and the suite was rebuilt along that line. But this is a genuine coverage
loss on exactly the code this ADR exists to protect, and it is recorded here rather than
quietly absorbed. If a future provider makes the same mapping testable again — an MLX
provider's errors will be Kiln's own types — that is an argument for routing more of the
taxonomy through types we control.

### The limit case: Private Cloud Compute traps

Verified 2026-09-07. `PrivateCloudComputeLanguageModel` reports `isAvailable == true`,
advertises `.reasoning`, and returns a healthy `quotaUsage` — all before any entitlement
exists. Opening a session then does this:

```
FoundationModels/ErrorConversion.swift:140: Fatal error:
Missing entitlement: com.apple.developer.private-cloud-compute
```

Not a throw. A trap. Every pre-flight this ADR argues for said yes, and the call still
terminated the process.

That is worth stating plainly because it bounds what this ADR can promise. Mapping
failures well protects you from failures that *arrive as errors*. It does nothing for an
API that asserts. The only defence is refusing to make the call — which means an
entitlement check, not a capability check, has to gate PCC, and it has to be a build-time
fact rather than a runtime one.

`com.apple.developer.private-cloud-compute` is a **managed** entitlement: requested from
Apple, subject to eligibility review. So the gate is knowable at build time, which is the
one piece of good news here.

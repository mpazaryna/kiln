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

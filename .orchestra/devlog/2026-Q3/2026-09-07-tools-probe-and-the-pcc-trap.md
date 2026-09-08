---
created_on: 2026-09-07
---

# 2026-09-07: A tool, a probe target, and the discovery that Private Cloud Compute traps rather than throws

## Summary

Follow-on to the iOS 27 migration earlier today. Kiln gained a `Tool` conformance and a
command-line probe target, and using the probe turned up four facts about the framework
that were not knowable from the interface alone. 26 tests pass, zero warnings.

The one to remember: **`PrivateCloudComputeLanguageModel` calls `fatalError` when the
managed entitlement is missing.** It does not throw. There is no defensive handling.

## Why a tool was the right next thing

After the migration Kiln *displayed* four capabilities and could exercise none of them.
The header read "Tool calling · Vision · Guided generation" and there was no way to try
any. `toolCallingMode` was a knob wired to nothing, because Kiln registers no tools — so
the SHE-29 experiment ("does `.disallowed` change anything?") was meaningless by
construction.

`ConeTemperatureTool` fixes that, and cone numbering makes it a genuinely good test
subject: the scale is counter-intuitive (06 is much cooler than 6), so a model that
guesses gets caught.

### The comparison the lab exists for

Same prompt, same model, one variable:

| `toolCallingMode` | transcript | answer for cone 06 |
|---|---|---|
| `.allowed` | `toolCalls → toolOutput → response` | 998 °C / **1828 °F** — correct |
| `.disallowed` | `response` | **1,100 °F** — hallucinated, 728 °F low |

Asked to list every known cone it produced `toolCalls → toolOutput → toolOutput →
toolOutput → response` — three calls in one turn.

This is the first thing Kiln has done that a plain `respond(to:)` sample cannot.

## Architecture: where the seam falls for tools

`ConeTemperature` is pure — a lookup table, normalisation, and phrasing, with no
`FoundationModels` import and no async. `ConeTemperatureTool` is the adapter that carries
`@Generable` / `@Guide` and conforms to Apple's `Tool`.

Tools cross the seam as `KilnToolID` identifiers rather than as any framework's tool type.
Apple's `Tool`, an MLX equivalent, and a remote model's function-calling schema are three
different shapes; what they share is *which* tool is on offer. `tools(for:)` switches
exhaustively, so adding an identifier fails to compile until a provider decides whether it
can host it — ADR-002's "capabilities that can be absent," applied.

**Offering a tool is deliberately independent of permitting calls.** Normalising that away
would have destroyed the comparison in the table above.

## Findings

### 1. PCC traps; it does not throw

```
FoundationModels/ErrorConversion.swift:140: Fatal error:
Missing entitlement: com.apple.developer.private-cloud-compute
```

`com.apple.developer.private-cloud-compute` is a **managed** entitlement — requested from
Apple through a form, subject to eligibility review, not a checkbox in Xcode.

The severity is in the failure mode. Before any entitlement exists:

- `pcc.isAvailable` → `true`
- `pcc.capabilities.contains(.reasoning)` → `true`
- `pcc.quotaUsage.status` → `belowLimit(isApproachingLimit: false)`

Availability says yes. Capability says yes. Quota says yes. The call then terminates the
process. This is ADR-003's thesis at its limit — and worse than the cases that ADR was
written for, because a trap cannot be caught, mapped, or degraded around. The only safe
pre-check is not making the call.

It also killed the probe mid-run, taking sections that had already printed down with it
(stdout never flushed). PCC now lives in its own `probe.sh pcc` command for that reason.

### 2. On-device errors *do* bridge — the earlier worry was unfounded

I flagged a risk after the migration: the PCC failure had arrived looking like a bridged
`NSError` rather than a `LanguageModelError`, which would have flattened real failures to
`.other`. Provoked properly on-device, it does not happen:

```
2. Same failure, raw — does it bridge to LanguageModelError?
bridges ✓  → maps to .guardrailViolation
```

The NSError shape was specific to the PCC/entitlement path, which traps anyway. Kiln's
mapper is sound. Recording this because the risk was raised in writing and should be
closed in writing.

### 3. The context window is 8192 tokens

```
detail: Content contains 26056 tokens, which exceeds the maximum allowed
        context size of 8192.
```

An exact number, from the framework, naming both sides of the comparison. Precisely the
text ADR-003 insists on carrying verbatim — `errorDescription` alone would have said
"Prompt exceeded the context window" and left you guessing by how much.

### 4. The guardrail fires before the context check

200,000 repetitions of `"kiln "` → `guardrailViolation` ("May contain unsafe content").
The same volume of *coherent* prose → `contextSizeExceeded`.

So the two limits are not evaluated in the order you would guess, and degenerate input
never reaches the context check at all. Worth knowing before concluding anything from a
synthetic load test.

## Tooling: the probe target

`KilnProbe` is a macOS command-line target that compiles `Kiln/Core/Intelligence`
directly rather than duplicating it, so what it reports is what the app does. It is
deliberately unsandboxed and unentitled — it exists to answer questions about the
framework, and a sandbox would add a second variable to every answer.

```
./scripts/probe.sh capabilities   # on-device vs PCC, side by side
./scripts/probe.sh tool           # tool offered, calling allowed
./scripts/probe.sh offered        # same tool, calling disallowed
./scripts/probe.sh reasoning      # fails on-device by design
./scripts/probe.sh errors         # provoke real failures, check they survive the mapper
./scripts/probe.sh pcc            # TRAPS without the managed entitlement
```

Every finding above came out of this target within an hour of it existing. It has earned
its place — the alternative was scratch files that link nothing and rot immediately.

## A test caught a real bug

`ConeTemperature.knownCones` sorted the zero-prefixed cones as strings, and `"06" > "022"`
lexically — which puts the hottest of the group first on a scale where 022 is the coolest.
Fixed to sort on the numeric part after the leading zero. Fitting, given the tool exists
because cone numbering is counter-intuitive.

## Also worth recording

`project.yml` was edited with an unanchored string replace and the probe target landed
twice — the second copy inside the `Kiln-iOS` scheme, corrupting it. Caught by parsing the
YAML back and asserting on the target and scheme lists. Anchor replacements in this file;
`  KilnTests-iOS:` is a substring of the scheme's `        KilnTests-iOS: [test]`.

## Next

- ADR for Private Cloud Compute: managed entitlement, off-device, and a trap on misuse.
  Three separate reasons it is a deliberate decision rather than an import
- `@Generable` structured output — `guidedGeneration` is advertised and still unexercised
  outside tool arguments
- Streaming via `streamResponse`
- The live-model test category AGENTS.md promises and does not yet have; findings 3 and 4
  are exactly what belongs in it
- Nothing is committed yet

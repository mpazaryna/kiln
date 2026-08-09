---
created_on: 2026-08-08
---

# 2026-08-08: A shipped build changed behaviour without being rebuilt — holding at iOS 26

## Summary

An iPad was updated to iOS 27 beta 3. The TestFlight build of Kiln already installed on
it — unchanged, built weeks earlier against the iOS 26 SDK — started answering prompts
differently. Filed as `SHE-29`. The decision coming out of it: stay on iOS 26 for all
work until every machine is on 27.

No code changed today. No tests ran.

## What was seen

The default prompt, *"Explain what a kiln does, in two sentences,"* came back with:

> to answer this question, I will first check if there is any tool available to retrieve
> information about kiln's function

Kiln registers no tools anywhere. `HelloKilnView.swift:228` passes `instructions: nil`, so
`AppleIntelligenceModel.swift:44` builds a bare `LanguageModelSession()` — no instructions,
no `tools:` argument. A session with zero tools was narrating a search for tools, which
placed the behaviour in the framework rather than in anything this project configured.

## The important part is what did *not* happen

`respond(to:instructions:)` returned normally. No error, no crash, `.success` rendered.
Generation succeeded — the content simply stopped being only an answer.

That is ADR-003's shape one step further along. That ADR says availability does not
guarantee generation. This says generation succeeding does not guarantee a *response*.

And the delivery mechanism matters more than the symptom: **no code changed, no rebuild
happened, and the behaviour changed anyway.** The `iOS 27` milestone was written assuming
the risk was API breakage at compile time — the system `LanguageModel` protocol arriving,
`AppleIntelligenceModel` becoming a bridge. The actual first symptom was silent behavioural
drift in a binary that never recompiled. Nothing in the ADRs anticipates that, and it is
the harder case precisely because nothing fails.

## Root cause

Cross-checked against `rudrankriyam/Foundation-Models-Framework-Lab`, cloned locally in
`~/workspace/third-party`, which tracks the Xcode 27 beta interface. Commit `8bf0a50`
documents the beta 3 delta:

- `Transcript.Entry.reasoning(Transcript.Reasoning)` — reasoning as a first-class entry
- `ContextOptions.ReasoningLevel` — `.light` / `.moderate` / `.deep` / `.custom(String)`,
  "the amount of thinking that the model is allowed to output before producing a response"
- `GenerationOptions.toolCallingMode` — `.allowed` / `.required` / `.disallowed`
- `LanguageModelCapabilities` gains `.reasoning` and `.toolCalling`
- `onReasoning` lifecycle hooks on `DynamicProfile`

iOS 27 beta 3 made the on-device model reasoning-capable. Kiln builds against Xcode 26.6 /
iOS 26.5 SDK with a 26.0 deployment target — a surface with nowhere to put a reasoning
entry. `AppleIntelligenceModel.swift:52` returns `response.content` and hands back whatever
arrived.

Stated honestly: the capability change and the SDK mismatch are verified. The causal link —
reasoning landing inline *because* the old surface cannot hold it — is a strong inference,
not a confirmed fact. Confirming it means building against Xcode 27 and seeing whether
reasoning separates out.

## Decision: hold at iOS 26 until every machine is on 27

Three reasons, in order of weight:

**The interface is still moving.** Between beta 2 and beta 3, `SamplingMode.Kind` renamed
`top(k:seed:)` → `randomTopK(_:seed:)` and `nucleus(threshold:)` →
`randomProbabilityThreshold(_:)`. Beta 4 rewrote 155 lines of that interface two weeks
later. Code written against beta 3 stands a real chance of not compiling against beta 5.

**The blast radius is bigger than Kiln.** ADR-004's CI is calibrated to a specific Xcode.
A beta toolchain on the primary dev box drags Xcode Cloud along with it — trading a working
release pipeline for an API that cannot ship.

**Nothing is blocked.** `Language`, `Distribution` and `Workbench` are all iOS 26 work. The
`iOS 27` milestone is last by design and gated on the OS, not on us.

The device split while we hold:

| Surface | OS | Role |
|---|---|---|
| Mac desktop | macOS 26 | Primary dev + live runs |
| iPhone | iOS 26 | Clean device target — auto-updates off |
| iPad | iOS 27 beta | Canary for framework drift |

Leaving the iPad on 27 is deliberate rather than lazy. It is now the only way to observe
iOS 27 behaviour without touching the toolchain, and it will already be on the target OS
when Xcode 27 arrives. Losing it as a clean iOS 26 device makes the macOS app the primary
live-run surface — which is what AGENTS.md already said, now with teeth.

## What this changes downstream

**`Workbench` gained a second argument.** It was sequenced before `Neural` on the grounds
that comparing two providers needs somewhere for comparison to happen. Independently of
that: the response carries structure Kiln discards — transcript entries, and in iOS 27 a
`usage` field with `reasoningTokenCount`. Watching a reasoning token count move is exactly
what a lab is for, and `return response.content` throws it away. Building that surface now,
against iOS 26, means there is somewhere for reasoning entries to land when the toolchain
catches up.

**`Neural` gained an open question.** iOS 27 exposes `LanguageModelExecutor` as Apple's
sanctioned custom-provider path — the beta notes call it "the lower-level replacement
direction for Xcode 26 adapter-style examples." An MLX provider might belong there rather
than beside `KilnModel`. Speculation, but the kind that should sit in the PRD as a question
rather than arrive as a surprise.

**Distribution is further along than the roadmap said.** A TestFlight build actually
shipped and is installable — which is how this defect reached a device at all. Two things
follow: `buildAudienceType` on that build needs verifying via `iris/v1/builds/<id>` (ADR-004:
permanent and immutable at upload, and the Xcode-generated workflow preselects
`INTERNAL_ONLY`), and testers on iOS 27 will see behaviour the developer on iOS 26 does not.

## Next

- Verify `buildAudienceType` on the shipped build — the one item here with a deadline that
  has already passed rather than one approaching
- Write today's finding into `.orchestra/work/ios-27/prd.md` and `neural/prd.md`; Linear
  currently knows more than the source of truth does
- The MLX / Xcode Cloud spike remains open and is untouched by the iOS 27 hold

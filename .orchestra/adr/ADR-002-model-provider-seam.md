---
id: ADR-002
status: accepted
created_on: 2026-08-08
---

# ADR-002: Every model goes through the KilnModel seam — including the first one

## Context

Kiln exists to compare on-device language model providers. Today exactly one is
reachable: Apple Intelligence, via `FoundationModels`. Others are expected —

- an **MLX-backed local model**, the "Neural" half of the name
- **Private Cloud Compute**, exposed in Xcode 27 builds
- a remote/cloud model, for contrast rather than production use

WWDC 2026 introduced a public `LanguageModel` protocol in `FoundationModels` (iOS 27 /
macOS 27) that lets any provider plug into `LanguageModelSession`. Kiln targets **iOS
26**, so that protocol is not available to it yet.

The tempting shortcut is to call `LanguageModelSession` directly from the view and
introduce an abstraction later, when there is a second provider to justify it.

## Decision

**Every model is reached through the `KilnModel` protocol, from the first commit, while
there is exactly one conformance.**

`AppleIntelligenceModel` is a conformance, not a special case. Views never name it; they
resolve a provider through `ModelRegistry` and call `respond(to:instructions:)`.

### Why now rather than at the second provider

The cost is asymmetric, and that asymmetry is the entire argument.

Introducing the protocol now costs one file and one indirection. Introducing it at the
second provider costs a change to every call site that assumed the first — and those
call sites will have accumulated exactly the assumptions that make the abstraction hard:
a session held across calls, a `SystemLanguageModel`-shaped availability check, an error
type from one framework leaking into the UI.

For a repository whose purpose is comparison, hardcoding one provider is not a shortcut
that gets paid back later. It is building the wrong thing quickly.

### This is not a claim about Apple's API

`KilnModel` is *modelled on* the shape a provider-agnostic session API needs, informed by
the existence of iOS 27's `LanguageModel`. It is deliberately **not** an attempt to
predict that protocol's signature.

When Kiln adopts iOS 27, `AppleIntelligenceModel` becomes a thin bridge onto the system
protocol and the views do not change. That is the seam doing its job: absorbing a change
in the framework without propagating it outward.

This mirrors the `SavvyModel` decision in the savvy repo (its ADR-005), taken in June
2026 for the same reason — with one difference. Savvy retrofitted a seam into a shipping
app; Kiln has the luxury of starting with one.

### Scope of the first cut

Deliberately small:

- `respond(to:instructions:)` returns a complete `String`.
- **No streaming.** It is a different shape (`AsyncSequence`), and designing it against a
  single implementation would bake that implementation's assumptions into the protocol.
- **No structured output / `@Generable`.** Same reasoning; it is also the most
  Apple-specific surface, and the least likely to generalise unchanged.
- **No shared session across calls.** Multi-turn context is a lab subject in its own
  right. A session held on the provider would silently make every run depend on the ones
  before it — the exact variable a lab needs to control rather than inherit.

Each of these is a candidate for the protocol *after* a second conformance exists to
design against.

### Availability is a property, not a constructor argument

`availability` is read at call time rather than cached at init. Apple Intelligence can
become unavailable after launch — toggled off in Settings, storage pressure evicting the
model — and a value captured at startup would be confidently wrong.

It is also a three-case enum rather than a `Bool`, because the user's next action differs:
`unsupported` is terminal, `notReady` is a trip to Settings. Collapsing them into "not
available" would teach the wrong thing in a repository meant for teaching.

## Consequences

- One indirection between a view and a model. Accepted; it is the point.
- `any KilnModel` existentials rather than generics. Chosen for a registry that holds a
  heterogeneous, runtime-selected list — the performance cost is irrelevant next to model
  inference, and generics would push the provider choice to compile time, which is the
  opposite of what a comparison lab needs.
- Provider-specific capabilities (structured output, tool calling, image input) do not
  fit the protocol yet. When they are added they must be added as *capabilities that can
  be absent*, not assumed present — otherwise the seam encodes Apple Intelligence's
  feature set and stops being a seam.
- Adding MLX later means adding the `mlx-swift` package, which reintroduces the
  `CudaBuild` build-tool plugin gate documented in savvy's ADR-013. Pin it with an
  explicit upper bound and commit `spm/Package.resolved` when that day comes; `from:` is
  a floor, not a pin.

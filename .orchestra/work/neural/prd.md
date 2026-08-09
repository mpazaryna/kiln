---
ticket: SHE-27
status: draft
created_on: 2026-08-08
---

# Neural

**Objective:** An MLX-backed provider as a second `KilnModel` conformance, answering the
same prompt as Apple Intelligence through the same seam. This is the comparison the
abstraction was built for.

## Success Criteria

- [ ] To be defined — run /orchestra-plan to flesh this out

## Context

Part of the [Kiln Roadmap](../../roadmap.md). Adding `mlx-swift` reintroduces a `CudaBuild`
build-tool plugin that headless CI cannot grant interactively — pin with an explicit upper
bound and commit `spm/Package.resolved`. `from:` is a floor, not a pin. See
[ADR-002](../../adr/ADR-002-model-provider-seam.md).

## Open question — 2026-08-08: is `KilnModel` still the right place to hang MLX?

iOS 27 exposes a first-class custom-provider path that did not exist when this milestone
was written:

```swift
public protocol LanguageModel: Sendable {
    var capabilities: LanguageModelCapabilities { get }
}

public protocol LanguageModelExecutor: Sendable {
    func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: Model,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws
}
```

`LanguageModelExecutorGenerationChannel` emits response deltas, reasoning deltas, and
tool-call events. The beta notes call this "the lower-level replacement direction for
Xcode 26 adapter-style examples."

So an MLX provider could conform to `LanguageModelExecutor` and be reached through Apple's
own protocol, rather than sitting beside `AppleIntelligenceModel` as a second `KilnModel`.
That would make both providers visible to the system rather than only to Kiln — and it
would change what this milestone builds.

**This is speculation, not a decision.** It is recorded here so it arrives as a question at
planning time instead of as a surprise mid-build. Resolving it needs Xcode 27, which the
project is deliberately not adopting yet — see [ios-27](../ios-27/prd.md).

Note the sequencing risk: if MLX belongs behind `LanguageModelExecutor`, this milestone
becomes partly dependent on `ios-27`, which the roadmap currently places *after* it.

## Proposed de-risking spike

The riskiest unknown here is a build question, not a modelling one, and it is answerable
now — nothing about it is blocked by the iOS 27 hold.

- Branch `spike/mlx-ci`; add `mlx-swift` with an explicit upper bound; commit
  `spm/Package.resolved`
- **No `KilnModel` conformance.** Import the module, make one trivial call, prove it links
- Try a command-line `xcodebuild` first — the plugin-trust problem is about an
  *interactive* prompt, so CLI is closer to the headless path and costs no Cloud minutes
- Kill condition: not green in two Xcode Cloud runs means "not without more work," which is
  a complete and useful result
- Delete the branch either way. **The deliverable is a written finding in this file, not
  code**, which is what keeps the spike inside ADR-005's no-implementation-without-a-spec
  gate

Step zero, ten minutes: check whether `mlx-swift` still carries the `CudaBuild` plugin at
all. The hazard above came from a sibling project and may have been resolved upstream since,
in which case the spike gets much shorter.

## Materials

| Material | Location | Status |
|----------|----------|--------|
| To be defined | | Not Started |

## Notes

Run /orchestra-plan neural to start the planning loop for this milestone.

Tracked as SHE-27. Session write-up:
[`devlog/2026-Q3/2026-08-08-ios-27-reasoning-drift.md`](../../devlog/2026-Q3/2026-08-08-ios-27-reasoning-drift.md).

# Kiln Roadmap

**Objective:** A workbench for looking closely at on-device models — load one, fire a
prompt at it, and read what comes back. Apple Foundation Models first, an MLX-backed
provider second, both reached through the same seam so they can be compared rather than
merely used.

## Success Criteria

- [ ] Two providers answer the same prompt through one `KilnModel` seam, side by side
- [ ] A colleague installs it and runs a prompt without cloning the repo
  - So far: TestFlight builds install on the developer's own iPhone. No colleague yet.
- [ ] Every pattern the repo teaches is written down as an ADR, not just demonstrated
- [ ] The suite is deterministic and gates every build — no green run that tested nothing
  - Deterministic, and guarded locally: `scripts/run-tests.sh` fails a run that executed
    no tests. Not yet a gate in CI: Xcode Cloud reports only its archive actions on
    `main`, with no test action and no pull-request check. The macOS test action also
    cannot run until Cloud offers a macOS 27 image
    ([ADR-004](adr/ADR-004-xcode-cloud-ci.md)).

## Context

Kiln is a teaching repository as much as a lab. The audience is colleagues and other
developers, so the patterns have to be legible and the app has to be runnable without a
clone. The seam (`KilnModel`) exists from the first commit precisely because comparison is
the point — a second provider is the payoff, not an afterthought. On-device only, no
network entitlement, no keys.

## Milestones

| Material | Location | Ticket | Status | Where it stands |
|----------|----------|--------|--------|-----------------|
| Language | [work/language/prd.md](work/language/prd.md) | [#2](https://github.com/mpazaryna/kiln/issues/2) | In Progress | The objective has shipped: the seam, availability, and failure mapping. The PRD was never given success criteria, so it is not closed. |
| Distribution | [work/distribution/prd.md](work/distribution/prd.md) | [#3](https://github.com/mpazaryna/kiln/issues/3) | In Progress | TestFlight builds install on the developer's iPhone. No colleague has installed one, and `buildAudienceType` is unverified. |
| Workbench | [work/workbench/prd.md](work/workbench/prd.md) | [#4](https://github.com/mpazaryna/kiln/issues/4) | Not Started | Comes before Neural: a second provider is only worth adding once the UI can show two answers. |
| Neural | [work/neural/prd.md](work/neural/prd.md) | [#5](https://github.com/mpazaryna/kiln/issues/5) | Not Started | Open question: Apple's `LanguageModelExecutor` may be a better home for MLX than a second `KilnModel`. A build spike is proposed. |
| iOS 27 | [work/ios-27/prd.md](work/ios-27/prd.md) | [#6](https://github.com/mpazaryna/kiln/issues/6) | In Progress | Adopted; 5 of 6 criteria met. Reasoning is blocked: no on-device model supports it. The Private Cloud Compute ADR is outstanding. |

## Planning

This file is the source of truth. [GitHub Issues](https://github.com/mpazaryna/kiln/issues)
mirrors these five as tickets for scheduling and status — they carry no plan of their
own. When the two disagree, this file wins and the issue gets corrected.

Orchestra arrived on 2026-08-08, with Language and Distribution already under way, and
generated a stub PRD for each milestone. Only iOS 27 has been worked through its PRD since:
success criteria, materials, and dated findings that corrected its earlier notes. The
other four still read "To be defined". The
[adoption devlog](devlog/2026-Q3/2026-08-08-orchestra-init.md) records why the milestones
are ordered as they are.

## References

- ADR-005: [The Score](adr/ADR-005-the-score.md)
- ADR-002: [Model Provider Seam](adr/ADR-002-model-provider-seam.md) — why Neural is the payoff
- ADR-004: [Xcode Cloud CI](adr/ADR-004-xcode-cloud-ci.md) — how Distribution reaches colleagues
- ADR-006: [Tickets in GitHub Issues](adr/ADR-006-tickets-in-github-issues.md) — why an issue is the ticket, not the plan

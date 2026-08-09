# Kiln Roadmap

**Objective:** A workbench for looking closely at on-device models — load one, fire a
prompt at it, and read what comes back. Apple Foundation Models first, an MLX-backed
provider second, both reached through the same seam so they can be compared rather than
merely used.

## Success Criteria

- [ ] Two providers answer the same prompt through one `KilnModel` seam, side by side
- [ ] A colleague installs it and runs a prompt without cloning the repo
- [ ] Every pattern the repo teaches is written down as an ADR, not just demonstrated
- [ ] The suite is deterministic and gates every build — no green run that tested nothing

## Context

Kiln is a teaching repository as much as a lab. The audience is colleagues and other
developers, so the patterns have to be legible and the app has to be runnable without a
clone. The seam (`KilnModel`) exists from the first commit precisely because comparison is
the point — a second provider is the payoff, not an afterthought. On-device only, no
network entitlement, no keys.

## Milestones

| Material | Location | Ticket | Status |
|----------|----------|--------|--------|
| Language | .orchestra/work/language/prd.md | SHE-24 | In Progress |
| Distribution | .orchestra/work/distribution/prd.md | SHE-25 | In Progress |
| Workbench | .orchestra/work/workbench/prd.md | SHE-26 | Not Started |
| Neural | .orchestra/work/neural/prd.md | SHE-27 | Not Started |
| iOS 27 | .orchestra/work/ios-27/prd.md | SHE-28 | Not Started |

## Planning

This file is the source of truth. [Linear](https://linear.app/workshed/project/kiln-5274e9117490/overview)
mirrors these five as milestones for human scheduling and status — it carries no plan of
its own. When the two disagree, this file wins and Linear gets corrected.

## References

- ADR-005: [The Score](adr/ADR-005-the-score.md)
- ADR-002: [Model Provider Seam](adr/ADR-002-model-provider-seam.md) — why Neural is the payoff
- ADR-004: [Xcode Cloud CI](adr/ADR-004-xcode-cloud-ci.md) — how Distribution reaches colleagues

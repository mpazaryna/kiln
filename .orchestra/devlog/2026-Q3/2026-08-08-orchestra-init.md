---
created_on: 2026-08-08
---

# 2026-08-08: Orchestra init — the scaffold, and the roadmap it produced

## Summary

Stood up the Orchestra lifecycle in Kiln: scaffolded `.orchestra/`, wrote the score ADR,
and bootstrapped a five-milestone roadmap with stub PRDs. No source files changed and no
tests ran — this session was entirely planning infrastructure.

Three commits, pushed to `main` (`d75716d..f75e9b6`):

| Commit | What |
|--------|------|
| `76ea8c3` | Ignore `.mcp.json` — it holds an API key and this repo is public |
| `7f4c18c` | Orchestra: scaffold the agent knowledge base |
| `f75e9b6` | Roadmap: five milestones, and Workbench earns its place before Neural |

## The score is ADR-005, not ADR-000

Orchestra ships its lifecycle decision as ADR-000: The Score. Kiln's ADR-000 was already
spent on platform config, and that number is cited in `README.md`, `AGENTS.md`, and four
commit messages. Renumbering the existing four ADRs to free the slot would break every one
of those references and buy nothing but a matching number.

So the score is `.orchestra/adr/ADR-005-the-score.md`, and it explains the gap in its own
Decision section — because someone who knows Orchestra will go looking for ADR-000 first,
and the explanation has to be where they land, not where we'd prefer they read.

The same reasoning applied to the workflow prose: it went into `AGENTS.md`, not
`CLAUDE.md`, because `CLAUDE.md` here is a one-line pointer to `AGENTS.md` and that is
where the project's standards actually live.

## Workbench before Neural, and why the ordering is load-bearing

`AGENTS.md` carried a three-phase roadmap in prose — Language, Neural, iOS 27. The
bootstrapped roadmap has five, and two of the additions are the interesting part.

**Distribution split out of Language.** ADR-004 already treats reaching colleagues as a
distinct goal with its own machinery and its own traps. It is not a finishing touch on
provider work.

**Workbench inserted between Distribution and Neural.** This is the one worth remembering.
A second `KilnModel` conformance is only interesting if the UI can show two answers at
once. The roadmap's own objective says comparison is the payoff — so shipping Neural
against a single-response `Hello, Kiln` screen would prove the seam compiles and nothing
else. The lab needs somewhere for comparison to happen before the thing being compared
arrives.

That makes the sequencing a real constraint rather than a preference: **if the Workbench
PRD gets scoped without side-by-side output, the ordering loses its reason and Neural
should move up.**

## Stubs carry the constraint that will bite them

The stock stub PRD is a placeholder with "To be defined" in every section. Each of the
five here also names the trap specific to that milestone:

- `neural` — the `CudaBuild` build-tool plugin headless CI cannot grant interactively, and
  `from:` being a floor rather than a pin
- `distribution` — `buildAudienceType`, set permanently and immutably at upload
- `workbench` — ADR-000 (config structs) and ADR-001 (no ViewModels)

That knowledge already exists in ADR prose, which a planner has to *think to go read*.
Putting it in the document being planned means it is in front of whoever picks the
milestone up months from now.

`language` and `distribution` are marked **In Progress**, not Not Started — `HelloKilnView`
runs and the CI scripts exist. A roadmap opening with five untouched milestones would have
been tidier and wrong.

## Gotcha: an API key one `git add -A` from being public

`.mcp.json` was untracked and holds a Context7 key in plaintext. Nothing in `.gitignore`
covered it, so a single `git add -A` would have published it — against this project's own
hard rule that there are no API keys and no secrets here.

Checked before ignoring: `git log --all -- .mcp.json` came back empty, so the key was never
committed and no history rewrite was needed.

**The key is still live.** It never reached this repo, but if the same `.mcp.json` has been
copied into other project directories, one of those may not have been as lucky. Rotating it
is cheap insurance.

## Two things left deliberately unverified

**The README Brief is drafted, not dictated.** Vision came from the README intro, audience
from ADR-004's "colleagues and other developers are exactly the audience for a teaching
repository." Both are traceable to the repo's own material — but they are now the seed
every future milestone gets derived from, and they are pushed. If either reads wrong, that
is the first thing to fix.

**Orchestra's roadmap template writes root-relative links** (`.orchestra/adr/...`), which
resolve wrong from inside `.orchestra/roadmap.md`. Rewritten as relative here. Worth
watching for in future generated artifacts.

## Next

Run `/orchestra-plan language` or `/orchestra-plan distribution`. Both are mid-flight, so
their PRDs will be partly a record of what already landed rather than pure forward
planning — which is an unusual first planning loop and may expose whether the PRD format
handles retroactive documentation gracefully.

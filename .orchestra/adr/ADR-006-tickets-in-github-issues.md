---
id: ADR-006
status: accepted
created_on: 2026-09-10
---

# ADR-006: Tickets live in GitHub Issues

## Context

Kiln's plan lives in `.orchestra/`: `roadmap.md` indexes the milestones and each work item
carries its own PRD. A Linear project in the workshed workspace mirrored the five
milestones, plus one defect, for scheduling and status. It carried no plan of its own —
`roadmap.md` already said that when the two disagreed, the file won and Linear got
corrected.

Kiln's issues are not discussed with anyone outside the project. The Linear project was a
second place to keep in sync for six identifiers and their status, in a workspace that
readers of this public repository cannot open.

## Decision

**GitHub Issues on `mpazaryna/kiln` replace Linear as the mirror of `roadmap.md`.** The
roadmap stays the source of truth; an issue is the ticket, not the plan.

The alternatives were keeping Linear, or mapping the milestones onto GitHub Milestones.
Keeping Linear kept the second place to sync. GitHub Milestones are containers for issues,
and `roadmap.md` already is the milestone index — so each work item became an issue, and
the defect became an issue labelled `bug`.

| Linear | GitHub | Work item |
|---|---|---|
| SHE-24 | [#2](https://github.com/mpazaryna/kiln/issues/2) | Language |
| SHE-25 | [#3](https://github.com/mpazaryna/kiln/issues/3) | Distribution |
| SHE-26 | [#4](https://github.com/mpazaryna/kiln/issues/4) | Workbench |
| SHE-27 | [#5](https://github.com/mpazaryna/kiln/issues/5) | Neural |
| SHE-28 | [#6](https://github.com/mpazaryna/kiln/issues/6) | iOS 27 |
| SHE-29 | [#7](https://github.com/mpazaryna/kiln/issues/7) | Defect: a session with zero tools narrates a search for tools |

## Consequences

- PRD frontmatter carries the issue as `ticket: "#N"`. The quotes are required: an
  unquoted `#` starts a YAML comment, and the field would read as empty.
- New work gets a roadmap row and a PRD first, then an issue — the same order as before,
  with `gh issue create` in place of Linear.
- This table is the only place the `SHE-*` IDs remain. Every other reference, dated
  devlogs included, now links to its issue: an ID pointing into a workspace no reader can
  open tells them nothing. A devlog is still a record of its day; the ticket it names is
  the one thing that moved. The issue bodies dropped their "Migrated from Linear" line for
  the same reason.
- Live documents — the roadmap, PRDs, ADR-002, `AGENTS.md`, the Unreleased changelog, and
  two code comments — cite `#N`. In Markdown it is written as a link, because GitHub turns
  a bare `#N` into one only in issues and pull requests, never in a rendered file.
- The Linear project is retired. Archiving it happens in Linear, outside this repository.

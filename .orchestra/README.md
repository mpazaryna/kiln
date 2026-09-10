# .orchestra/

How work on Kiln is planned, decided, and recorded. It is written for the agents that do
much of the work, and for anyone reading the repository to see how that work is organised.

The process is Orchestra, a software development lifecycle encoded for agents and served to
them over MCP. Kiln adopted it in [ADR-005](adr/ADR-005-the-score.md).

## Where to start

1. [`roadmap.md`](roadmap.md) — the milestones, where each one stands, and the PRD and
   GitHub issue that track it.
2. [`work/ios-27/prd.md`](work/ios-27/prd.md) — the milestone taken furthest through its
   PRD: success criteria, materials, and dated findings that overturned its earlier notes.
3. [`devlog/`](devlog/) — what each session found, including what turned out to be wrong.
4. [`adr/`](adr/) — the decisions, amended rather than rewritten when they meet reality.

## Structure

| Path | Holds | In Kiln so far |
|---|---|---|
| `roadmap.md` | Vision and milestone index; the source of truth that GitHub Issues mirrors | |
| `adr/` | Architecture Decision Records | ADR-005 adopts Orchestra |
| `work/<item>/` | One folder per work item: a PRD, then a spec, then Gherkin scenarios | PRDs only |
| `work/TEMPLATES/` | Starting points for a PRD and a spec | |
| `devlog/<quarter>/` | A dated journal, one entry per session | |
| `uml/` | Mermaid diagrams | None yet |

## The lifecycle

Stages run in order, and each needs explicit human approval before the next begins:

```
intake → prd → spec → gherkin → plan → execute
```

Each activity has a playbook, served as a skill:

| Skill | Does |
|---|---|
| `orchestra-roadmap` | Sets up or updates the roadmap |
| `orchestra-plan` | Runs PRD → spec → Gherkin for one work item, stopping at each gate |
| `orchestra-implement` | Executes an approved spec on a branch |
| `orchestra-review` | Checks the branch against its spec before merge |
| `orchestra-merge` | Merges and closes the work item |
| `orchestra-adr`, `orchestra-devlog` | Record a decision, or a session |

## Rules

- Read the roadmap and the relevant ADRs before acting on a work item
- A PRD before a spec; a spec before implementation
- Nothing moves forward without explicit human approval at each gate

## How closely Kiln follows it

Orchestra arrived on 2026-08-08, partway through the project. ADR-000 to ADR-004, and the
Language and Distribution work, predate it. Since then, work has been scoped in PRDs and
recorded in ADRs and the devlog, but no spec or Gherkin scenario has been written yet: the
iOS 27 adoption ran against its PRD's success criteria rather than a spec.

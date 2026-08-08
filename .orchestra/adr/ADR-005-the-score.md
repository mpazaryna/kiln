---
id: ADR-005
status: accepted
created_on: 2026-08-08
---

# ADR-005: The Score

## Decision

This project uses Orchestra — a software development lifecycle encoded for agents. PRDs are the unit of work. Every significant piece of work has a PRD before a spec, and a spec before implementation.

Orchestra ships this decision as ADR-000. Kiln's ADR-000 was already spent on
[platform config](ADR-000-platform-config.md) before Orchestra was adopted, and that
number is cited in the README, `AGENTS.md`, and the commit history. Renumbering the
existing four to make room would break every one of those references to buy nothing. The
score is ADR-005 here; the number is not the point.

## Rationale

Without a written PRD, work drifts. Without a spec, agents have no contract to
execute against. Without Gherkin, there is no definition of done an agent can verify.

The `.orchestra/` folder is the shared knowledge base. Agents read it. Humans update
it at each gate. The score doesn't change mid-performance without a new ADR.

## Consequences

- No implementation without an approved spec
- No spec without an approved PRD
- All significant architectural decisions are recorded as ADRs
- ADR-000 through ADR-004 predate this decision and were not written to Orchestra's
  process; they are accepted as-is and not retrofitted

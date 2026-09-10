---
ticket: "#3"
status: draft
created_on: 2026-08-08
---

# Distribution

**Objective:** A colleague installs Kiln from TestFlight and runs a prompt on their own
device, without cloning the repo, installing XcodeGen, or supplying a team ID.

## Success Criteria

- [ ] To be defined — run /orchestra-plan to flesh this out

## Context

Part of the [Kiln Roadmap](../../roadmap.md). In progress:
[ADR-004](../../adr/ADR-004-xcode-cloud-ci.md) is accepted, `ci_scripts/` hooks and
`scripts/create-xcode-cloud-workflow.sh` exist. Watch the `buildAudienceType` trap — it is
set permanently and immutably at upload.

## Progress

- **2026-08-08** — A TestFlight build was already installed on an iPad, which is how the
  defect in [#7](https://github.com/mpazaryna/kiln/issues/7) reached a device at all.
- **2026-09-10** — Confirmed: a build uploaded to TestFlight installs on an iPhone. The
  path from upload to the developer's own device works.

Not yet shown, and the objective needs both:

- **A colleague installs it.** So far the only devices are the developer's own.
- **`buildAudienceType` is verified** on the uploaded builds, via `iris/v1/builds/<id>`.
  An `INTERNAL_ONLY` build reaches App Store Connect team members, never an external
  tester or a public link, and the stamp cannot be changed after upload (ADR-004).

## Materials

| Material | Location | Status |
|----------|----------|--------|
| To be defined | | Not Started |

## Notes

Run /orchestra-plan distribution to start the planning loop for this milestone.

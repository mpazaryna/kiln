---
ticket: "#4"
status: draft
created_on: 2026-08-08
---

# Workbench

**Objective:** The lab UI grows past `Hello, Kiln` — prompt history, generation
parameters, and side-by-side output. Comparison needs somewhere to happen before there is
a second provider to compare.

## Success Criteria

- [ ] To be defined — run /orchestra-plan to flesh this out

## Context

Part of the [Kiln Roadmap](../../roadmap.md). Precedes Neural deliberately: a second
`KilnModel` conformance is only interesting if the UI can show two answers at once. All
layout values go in config structs per
[ADR-000](../../adr/ADR-000-platform-config.md); no ViewModels per
[ADR-001](../../adr/ADR-001-no-viewmodels-in-swiftui.md).

## Materials

| Material | Location | Status |
|----------|----------|--------|
| Liquid Glass on the controls panel ([#11](https://github.com/mpazaryna/kiln/issues/11)) | `Kiln/Views/HelloKilnView.swift` | Done |

## Notes

Run /orchestra-plan workbench to start the planning loop for this milestone.

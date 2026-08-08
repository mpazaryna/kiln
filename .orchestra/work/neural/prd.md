---
ticket: neural
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

## Materials

| Material | Location | Status |
|----------|----------|--------|
| To be defined | | Not Started |

## Notes

Run /orchestra-plan neural to start the planning loop for this milestone.

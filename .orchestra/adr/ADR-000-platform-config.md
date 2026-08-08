---
id: ADR-000
status: accepted
created_on: 2026-08-08
priority: foundational
---

# ADR-000: All layout values live in config structs

## Context

Kiln ships one codebase to three form factors — macOS, iPad, iPhone — with genuinely
different layout needs: pointer precision and window space on the Mac, comfortable touch
targets on iPad, density on iPhone.

Without a convention, platform adaptation decays into conditionals scattered through view
bodies:

```swift
// ❌ The anti-pattern
VStack(spacing: sizeClass == .regular ? 16 : 12) {
    Text("Header").font(.system(size: 17))
    #if os(macOS)
    content.padding(20)
    #else
    content.padding(16)
    #endif
}
```

That fails four ways: the same conditional is duplicated across views, it is easy to miss
a platform, changing one value means finding every site, and nothing is verifiable
without running all three.

## Decision

**Every platform-specific layout value lives in a config struct. View bodies contain no
literals and no platform conditionals.**

A view reads `config.cardPadding`. It never reads `16`, never asks `#if os(macOS)`, and
never tests `sizeClass == .regular`.

### Two layers

`BasePlatformConfig` (in `Core/Configuration/PlatformConfig.swift`) is the single source
of truth for values shared by more than one view — base spacing, corner radius, fonts,
control sizes.

Each view then defines a **local `fileprivate` config** in its own file that *flattens*
the base values it needs and adds its own:

```swift
private struct HelloLayoutConfig {
    // Flattened from BasePlatformConfig
    let cardPadding: CGFloat
    // View-specific
    let promptMinHeight: CGFloat
}
```

Local-and-`fileprivate` is the **default**, not the exception. It keeps ownership next to
the view, and it avoids the AttributeGraph cycles that shared config objects can trigger
in split-view hierarchies.

### Flatten, never nest

```swift
// ❌ Nested — every access carries the noise
struct Config { let base: BasePlatformConfig }
config.base.cardPadding

// ✅ Flattened
struct Config { let cardPadding: CGFloat }
config.cardPadding
```

Flattening keeps the call site clean, keeps autocomplete useful, and — the real reason —
lets a property move between the base and a local config without editing a single view.

### Platform detection happens once, in the config

```swift
#if os(iOS)
static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self { ... }
#else
static var current: Self { ... }
#endif
```

iOS resolves from `horizontalSizeClass` rather than the device idiom, so an iPad in Slide
Over gets compact values — which is what the layout needs, not what the device nominally
is. macOS has no size class, so it is a static property.

### The mandatory view preamble

```swift
#if os(iOS)
@Environment(\.horizontalSizeClass) private var sizeClass
private var config: SomeLayoutConfig { SomeLayoutConfig.current(sizeClass) }
#else
private var config: SomeLayoutConfig { SomeLayoutConfig.current }
#endif
```

This is the *only* `#if os(...)` permitted in a view file, and it sits above `body`, never
inside it.

## Consequences

- Layout is predictable, and a design change propagates from one edit.
- Adding a platform (visionOS, watchOS) means extending configs, not auditing views.
- `PlatformConfig.swift` grows over time. Acceptable — one large, well-organised file
  beats the same values scattered across fifty.
- The pattern has to be learned before the first UI contribution. That is what this ADR
  is for.

## Checklist

- [ ] Any hardcoded number in a view body? → move to config
- [ ] Any `#if os()` inside `body`? → move to config
- [ ] Any `sizeClass ==` check in a view body? → move to config
- [ ] A local `let` for a layout value? → move to config
- [ ] Values provided for all three form factors? → iPhone, iPad, macOS

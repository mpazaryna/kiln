---
id: ADR-001
status: accepted
created_on: 2026-08-08
---

# ADR-001: No ViewModels in SwiftUI

## Context

MVVM arrived in SwiftUI as UIKit baggage. The Massive View Controller problem was real,
and ViewModels were a real answer to it — in UIKit, where views are long-lived reference
types.

SwiftUI views are **structs**: lightweight, disposable, recreated constantly. Apple's own
data-flow sessions barely mention ViewModels, and SwiftData's `@Query` is unusable
through one without giving up everything it does. A ViewModel in SwiftUI is not a neutral
organisational choice; it fights the framework's design.

## Decision

**Kiln has no ViewModels.**

```
Models    — data structures
Services  — logic, I/O, model providers    (injected via @Environment)
Views     — state representations           (@State for local UI state)
```

### The pattern

```swift
struct SomeView: View {
    @Environment(ModelRegistry.self) private var registry

    private enum RunState {
        case idle, running
        case success(String)
        case failed(String)
    }
    @State private var state: RunState = .idle

    var body: some View {
        switch state {
        case .idle:    ContentUnavailableView(...)
        case .running: ProgressView()
        case .success(let text): Text(text)
        case .failed(let message): ContentUnavailableView(...)
        }
    }

    private func run() async {
        state = .running
        do { state = .success(try await registry.selected.respond(...)) }
        catch { state = .failed(error.localizedDescription) }
    }
}
```

### Enums for mutually exclusive states

`RunState` is an enum, not a set of booleans. `isLoading` + `errorMessage` + `result` can
represent "loading and failed at the same time"; an enum cannot. The illegal state is
unrepresentable rather than merely unlikely.

### Environment for services

Services are owned by the `App` and injected downward. Kiln uses `@Environment` rather
than singletons deliberately: `ModelRegistry` is exactly the thing a test or a future
provider-comparison harness needs to substitute, and a `.shared` would make that
substitution a global mutation.

### When a view gets too large, split it

Extract subviews. Do not add a ViewModel. Split when a file passes ~300 lines, when the
body nests more than three levels, or when a section owns state nothing else touches.

## Testing

**Test services and logic, not views.**

`ModelRegistry` and `KilnModelAvailability` have unit tests. `HelloKilnView` does not, and
should not — it is a rendering of state, and the state transitions it performs are three
lines calling a service that *is* tested.

Tests must be deterministic. A suite whose result depends on whether the device has
Apple Intelligence enabled is not a test. Live-model checks, when they exist, belong in a
separately-invoked category — never in the default run.

## Consequences

- Less code, less boilerplate, no manual state syncing.
- Views stay simple enough that visual inspection is adequate coverage.
- Requires discipline: the reflex to add a ViewModel has to be resisted, and reviewers
  have to catch it.
- Large views need active splitting, since there is no ViewModel to hide bulk in.

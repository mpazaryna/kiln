import Testing
import Foundation
@testable import Kiln

/// A stub provider. Tests here are deterministic on purpose — nothing in this file
/// touches Apple Intelligence, because a suite whose result depends on whether the
/// device has a model downloaded is not a test, it is a weather report.
private struct StubModel: KilnModel {
    let identifier: String
    let displayName: String
    var availability: KilnModelAvailability = .available
    var capabilities: Set<KilnModelCapability> = [.toolCalling]

    func run(_ prompt: String,
             instructions: String?,
             options: KilnRunOptions) async throws -> KilnRun {
        KilnRun(
            content: "echo: \(prompt)",
            usage: KilnTokenUsage(inputTokens: 1, cachedInputTokens: 0,
                                  outputTokens: 1, reasoningTokens: 0),
            entries: [.prompt, .response],
            duration: .milliseconds(1)
        )
    }
}

@Suite("ModelRegistry")
@MainActor
struct ModelRegistryTests {
    @Test("selects the first model by default")
    func defaultsToFirst() {
        let registry = ModelRegistry(models: [
            StubModel(identifier: "a", displayName: "A"),
            StubModel(identifier: "b", displayName: "B"),
        ])

        #expect(registry.selectedIdentifier == "a")
        #expect(registry.selected.identifier == "a")
    }

    @Test("selection follows the identifier")
    func selectsByIdentifier() {
        let registry = ModelRegistry(models: [
            StubModel(identifier: "a", displayName: "A"),
            StubModel(identifier: "b", displayName: "B"),
        ])

        registry.selectedIdentifier = "b"

        #expect(registry.selected.identifier == "b")
    }

    /// Guards the fallback in `selected`. A stale identifier must degrade to a working
    /// provider rather than to none — the failure mode this prevents is a Run button
    /// that silently does nothing.
    @Test("unknown identifier falls back to the first model")
    func unknownIdentifierFallsBack() {
        let registry = ModelRegistry(models: [
            StubModel(identifier: "a", displayName: "A"),
        ])

        registry.selectedIdentifier = "does-not-exist"

        #expect(registry.selected.identifier == "a")
    }
}

@Suite("KilnModelAvailability")
struct KilnModelAvailabilityTests {
    @Test("available carries no reason")
    func availableHasNoReason() {
        #expect(KilnModelAvailability.available.isAvailable)
        #expect(KilnModelAvailability.available.reason == nil)
    }

    /// `unsupported` and `notReady` are distinct because the user action differs —
    /// one is fixable in Settings, the other is not fixable at all.
    @Test("unavailable cases carry their reason and are not available")
    func unavailableCasesCarryReason() {
        let unsupported = KilnModelAvailability.unsupported("no NPU")
        let notReady = KilnModelAvailability.notReady("still downloading")

        #expect(!unsupported.isAvailable)
        #expect(unsupported.reason == "no NPU")
        #expect(!notReady.isAvailable)
        #expect(notReady.reason == "still downloading")
        #expect(unsupported != notReady)
    }
}

/// Capability is the third stage of the chain ADR-003 started with two: available →
/// capable → generated. macOS 27 supplies the live example — the system model reports
/// `.available` and advertises tool calling, vision and guided generation, but not
/// reasoning, so a reasoning request fails after a clean availability pre-flight.
@Suite("KilnModelCapability")
struct KilnModelCapabilityTests {
    @Test("supports reflects the advertised set")
    func supportsReflectsSet() {
        let model = StubModel(identifier: "a", displayName: "A",
                              capabilities: [.toolCalling, .vision])

        #expect(model.supports(.toolCalling))
        #expect(model.supports(.vision))
        #expect(!model.supports(.reasoning))
        #expect(!model.supports(.guidedGeneration))
    }

    @Test("a model advertising nothing supports nothing")
    func emptyCapabilities() {
        let model = StubModel(identifier: "a", displayName: "A", capabilities: [])

        for capability in KilnModelCapability.allCases {
            #expect(!model.supports(capability), "\(capability) should not be supported")
        }
    }

    @Test("the convenience run overload uses default options")
    func convenienceRun() async throws {
        let model = StubModel(identifier: "a", displayName: "A")

        let run = try await model.run("hello")

        #expect(run.content == "echo: hello")
        #expect(run.entries == [.prompt, .response])
    }
}

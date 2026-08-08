import Foundation

/// Why a provider can be unavailable. Distinguishing these matters because the fixes
/// are completely different — "turn on Apple Intelligence" is a settings trip, while
/// "this Mac is Intel" is unfixable — and a lab that collapses them into one error
/// teaches the wrong thing.
enum KilnModelAvailability: Equatable, Sendable {
    case available
    /// The device or OS cannot run this provider at all.
    case unsupported(String)
    /// The provider exists but is not ready — disabled, not yet downloaded, out of space.
    case notReady(String)

    var isAvailable: Bool { self == .available }

    /// Human-readable reason, or nil when available.
    var reason: String? {
        switch self {
        case .available: nil
        case .unsupported(let why), .notReady(let why): why
        }
    }
}

enum KilnModelError: Error, LocalizedError {
    case unavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let why): "Model unavailable: \(why)"
        case .generationFailed(let why): "Generation failed: \(why)"
        }
    }
}

/// A language model Kiln can run a prompt against.
///
/// **This protocol exists before it has a second conformance, deliberately.**
///
/// Kiln's reason to exist is comparing providers — Apple Intelligence today, an
/// MLX-backed local model next, a Private Cloud Compute or remote model after that.
/// Introducing the abstraction at the point where the second provider arrives means
/// retrofitting it through every call site that assumed the first one. Introducing it
/// now costs one file and makes each new provider an additive change.
///
/// It is modelled on the shape a provider-agnostic session API needs, informed by the
/// `LanguageModel` protocol Apple introduced at WWDC 2026. It is **not** a claim about
/// that API's signature — Kiln targets iOS 26 and owns this protocol. When we adopt the
/// system protocol, `AppleIntelligenceModel` becomes a thin bridge and views do not
/// change. See ADR-002.
protocol KilnModel: Sendable {
    /// Stable identifier used for run records and provider selection.
    var identifier: String { get }

    /// Name shown in the UI.
    var displayName: String { get }

    /// Checked before every run — availability is not static. Apple Intelligence can
    /// become unavailable after launch (toggled off, storage pressure), so this is a
    /// property read at call time rather than a value cached at init.
    var availability: KilnModelAvailability { get }

    /// Run a single prompt and return the complete response.
    ///
    /// Streaming is deliberately absent from the first cut. It is a different shape
    /// (`AsyncSequence`) and adding it before there are two providers to compare would
    /// be designing the seam against one implementation.
    func respond(to prompt: String, instructions: String?) async throws -> String
}

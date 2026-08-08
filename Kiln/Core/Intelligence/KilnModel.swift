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

/// Why a single generation failed, in provider-neutral terms.
///
/// These are deliberately not Apple-specific. An MLX provider can exhaust a context
/// window or refuse a prompt too, and comparing *how* providers fail is as much the
/// point of this lab as comparing what they produce. Mapping each provider's native
/// error into this shape is the provider's job, not the view's.
enum KilnGenerationIssue: Equatable, Sendable {
    /// A required model asset is missing or unreadable. Distinct from unavailability:
    /// the provider reported itself ready, then could not load something it needed.
    case assetsUnavailable
    case contextWindowExceeded
    /// A safety guardrail rejected the prompt or the response.
    case guardrailViolation
    /// The model declined to answer, with an explanation available.
    case refused
    case rateLimited
    case concurrentRequests
    case unsupportedLanguageOrLocale
    /// The response could not be decoded into the requested shape.
    case decodingFailure
    case other

    var summary: String {
        switch self {
        case .assetsUnavailable: "Required model assets are missing"
        case .contextWindowExceeded: "Prompt exceeded the context window"
        case .guardrailViolation: "Blocked by a safety guardrail"
        case .refused: "The model declined to answer"
        case .rateLimited: "Rate limited"
        case .concurrentRequests: "Too many concurrent requests"
        case .unsupportedLanguageOrLocale: "Unsupported language or locale"
        case .decodingFailure: "The response could not be decoded"
        case .other: "Generation failed"
        }
    }

    /// What the operator can actually do about it. `nil` where there is no user action.
    var recovery: String? {
        switch self {
        case .assetsUnavailable:
            // The common cause in practice: the Simulator's model catalog has no
            // guardrail assets, so availability reports .available and generation then
            // fails on a missing dependency. Run on a real device or the Mac app.
            "Run on a real device or the macOS app — the Simulator often lacks the guardrail model assets."
        case .contextWindowExceeded:
            "Shorten the prompt or the instructions."
        case .guardrailViolation:
            "Rephrase the prompt."
        case .rateLimited, .concurrentRequests:
            "Wait a moment and fire again."
        case .refused, .unsupportedLanguageOrLocale, .decodingFailure, .other:
            nil
        }
    }
}

enum KilnModelError: Error, LocalizedError {
    /// The provider cannot run at all — checked before the request is sent.
    case unavailable(String)
    /// The provider accepted the request and could not complete it. `detail` carries the
    /// framework's own debug text, which a lab should show rather than swallow.
    case generationFailed(issue: KilnGenerationIssue, detail: String?)

    var errorDescription: String? {
        switch self {
        case .unavailable(let why):
            "Model unavailable: \(why)"
        case .generationFailed(let issue, _):
            issue.summary
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unavailable: nil
        case .generationFailed(let issue, _): issue.recovery
        }
    }

    /// Raw framework text, kept separate from the human-readable summary so the UI can
    /// show both without one drowning the other.
    var detail: String? {
        switch self {
        case .unavailable: nil
        case .generationFailed(_, let detail): detail
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

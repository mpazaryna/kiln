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

/// What a provider can actually do, as opposed to whether it is switched on.
///
/// This is the third stage of a chain ADR-003 started with two. Availability says the
/// provider will accept a request; capability says it will accept *this* request. On
/// macOS 27 the system model reports `.available` and advertises `toolCalling`, `vision`
/// and `guidedGeneration` — but **not** `reasoning`, so asking for a reasoning level
/// throws `unsupportedCapability` after a clean pre-flight. Checking first turns that
/// throw into a disabled control.
enum KilnModelCapability: String, CaseIterable, Sendable {
    case reasoning
    case toolCalling
    case vision
    case guidedGeneration

    var displayName: String {
        switch self {
        case .reasoning: "Reasoning"
        case .toolCalling: "Tool calling"
        case .vision: "Vision"
        case .guidedGeneration: "Guided generation"
        }
    }
}

/// How much thinking the model may do before answering. Only meaningful on a provider
/// whose capabilities include `.reasoning`.
enum KilnReasoningLevel: String, CaseIterable, Sendable {
    case light, moderate, deep
}

/// Whether the model may call tools. Kiln registers none, so `.disallowed` is the honest
/// default — see the SHE-29 finding, where a session with zero tools narrated a search
/// for tools and put that narration in the answer.
enum KilnToolCalling: String, CaseIterable, Sendable {
    case allowed, disallowed
}

/// A tool Kiln can offer a provider, named neutrally.
///
/// The seam trades in identifiers rather than in any framework's tool type. Apple's
/// `Tool` protocol, an MLX provider's equivalent, and a remote model's function-calling
/// schema are three different shapes; what they share is *which* tool is on offer.
/// Each provider maps these to its own representation, and a provider that cannot host
/// a given tool simply does not offer it — a capability that can be absent (ADR-002).
enum KilnToolID: String, CaseIterable, Sendable {
    case coneTemperature

    var displayName: String {
        switch self {
        case .coneTemperature: "Cone temperature"
        }
    }
}

/// The knobs a lab needs on a single run. Provider-neutral: a provider that cannot honour
/// one maps it to nothing rather than failing, except where the request is meaningless
/// (asking for reasoning from a model without it), which is a capability error.
struct KilnRunOptions: Equatable, Sendable {
    var temperature: Double?
    var maximumResponseTokens: Int?
    var toolCalling: KilnToolCalling = .disallowed
    var reasoning: KilnReasoningLevel?

    /// Which tools to hand the provider. Independent of `toolCalling` on purpose:
    /// offering a tool and then forbidding calls is a legitimate experiment, and seeing
    /// the model ignore an available tool is exactly the kind of thing a lab is for.
    var tools: Set<KilnToolID> = []

    static let `default` = KilnRunOptions()
}

/// Token accounting for one run. `reasoning` is carried even where it is always zero,
/// because watching it stay zero on a model without the capability is itself the lesson.
struct KilnTokenUsage: Equatable, Sendable {
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
}

/// The kinds of entry a run can add to a transcript.
///
/// Kiln records the *kind* rather than the payload. The payloads are provider-specific
/// and mostly opaque (`Transcript.Reasoning` exposes an `Action` with no public members),
/// while the sequence of kinds is exactly what a lab wants to compare across providers.
enum KilnTranscriptEntryKind: String, Sendable {
    case instructions, prompt, response, reasoning, toolCalls, toolOutput, unknown
}

/// One completed run: the answer, plus the evidence around it.
///
/// `respond` used to return `String`. It threw away everything the framework said about
/// *how* the answer was produced — which, in a lab, is most of the value. iOS 27 added
/// `usage` and a `.reasoning` transcript entry; both land here without the protocol
/// changing shape again.
struct KilnRun: Sendable {
    let content: String
    let usage: KilnTokenUsage?
    let entries: [KilnTranscriptEntryKind]
    let duration: Duration
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
    /// The request asked for something this model cannot do — iOS 27's
    /// `LanguageModelError.unsupportedCapability`. The live instance of this is asking
    /// the macOS 27 system model for a reasoning level it does not advertise.
    case unsupportedCapability
    /// The transcript contained content this model cannot consume (iOS 27).
    case unsupportedTranscriptContent
    /// The request exceeded its time budget (iOS 27).
    case timedOut
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
        case .unsupportedCapability: "This model does not support what was asked"
        case .unsupportedTranscriptContent: "The transcript contains unsupported content"
        case .timedOut: "The request timed out"
        case .other: "Generation failed"
        }
    }

    /// What the operator can actually do about it. `nil` where there is no user action.
    ///
    /// Worth keeping even though iOS 27's errors carry their own `recoverySuggestion`:
    /// the live `unsupportedCapability` returns `nil` for it, so the one case where the
    /// fix is most obvious to a human is the case the framework says nothing about.
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
        case .unsupportedCapability:
            "Turn the unsupported option off, or select a model that advertises it."
        case .timedOut:
            "Try again, or shorten the prompt."
        case .refused, .unsupportedLanguageOrLocale, .decodingFailure,
             .unsupportedTranscriptContent, .other:
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
/// iOS 27 tested that claim and it held: adopting the new `FoundationModels` surface
/// changed `AppleIntelligenceModel` and nothing above it. Note what the seam is *not* —
/// iOS 27's own `LanguageModel` protocol is a model *descriptor* paired with a
/// `LanguageModelExecutor`, the path for supplying a custom model to a
/// `LanguageModelSession`. That is the Neural/MLX story, not this one. See ADR-002.
protocol KilnModel: Sendable {
    /// Stable identifier used for run records and provider selection.
    var identifier: String { get }

    /// Name shown in the UI.
    var displayName: String { get }

    /// Checked before every run — availability is not static. Apple Intelligence can
    /// become unavailable after launch (toggled off, storage pressure), so this is a
    /// property read at call time rather than a value cached at init.
    var availability: KilnModelAvailability { get }

    /// What this provider can do. Read at call time for the same reason as availability.
    var capabilities: Set<KilnModelCapability> { get }

    /// Run a single prompt and return the complete response with its evidence.
    ///
    /// Streaming is still deliberately absent. It is a different shape
    /// (`AsyncSequence`) and adding it before there are two providers to compare would
    /// be designing the seam against one implementation.
    func run(_ prompt: String,
             instructions: String?,
             options: KilnRunOptions) async throws -> KilnRun
}

extension KilnModel {
    /// Convenience for the common case — a bare prompt with default options.
    func run(_ prompt: String) async throws -> KilnRun {
        try await run(prompt, instructions: nil, options: .default)
    }

    func supports(_ capability: KilnModelCapability) -> Bool {
        capabilities.contains(capability)
    }
}

import Foundation
import FoundationModels

/// Apple Intelligence — the on-device system model, via `FoundationModels`.
///
/// The first `KilnModel` conformance, and the reason the protocol's surface is as small
/// as it is: everything here is available from a system framework with no package
/// dependency, no build-tool plugin, and no network access.
///
/// This file is the whole blast radius of the iOS 26 → 27 migration. Nothing in the
/// views, the registry, or the config moved — which is the claim ADR-002 made before
/// there was any way to check it.
struct AppleIntelligenceModel: KilnModel {
    let identifier = "apple-intelligence"
    let displayName = "Apple Intelligence"

    private var model: SystemLanguageModel { .default }

    var availability: KilnModelAvailability {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            // The device/OS cases are terminal; the rest are things the user can fix,
            // and the UI phrases them as an action rather than a failure.
            switch reason {
            case .deviceNotEligible:
                return .unsupported("This device does not support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .notReady("Turn on Apple Intelligence in Settings.")
            case .modelNotReady:
                return .notReady("The model is still downloading. Try again shortly.")
            @unknown default:
                return .notReady("Apple Intelligence is unavailable.")
            }
        @unknown default:
            return .notReady("Apple Intelligence is unavailable.")
        }
    }

    /// Read from the framework rather than hardcoded, because it varies by machine and
    /// by OS. On macOS 27 this Mac reports `toolCalling`, `vision` and `guidedGeneration`
    /// — and not `reasoning`, despite iOS 27 shipping a whole reasoning surface.
    var capabilities: Set<KilnModelCapability> {
        let native = model.capabilities
        var result: Set<KilnModelCapability> = []
        if native.contains(.reasoning) { result.insert(.reasoning) }
        if native.contains(.toolCalling) { result.insert(.toolCalling) }
        if native.contains(.vision) { result.insert(.vision) }
        if native.contains(.guidedGeneration) { result.insert(.guidedGeneration) }
        return result
    }

    func run(_ prompt: String,
             instructions: String?,
             options: KilnRunOptions) async throws -> KilnRun {
        guard case .available = availability else {
            throw KilnModelError.unavailable(availability.reason ?? "unknown")
        }

        // Pre-flight the capability rather than letting the framework throw. The error it
        // raises is accurate but its `recoverySuggestion` is nil, and "you asked a model
        // without reasoning for a reasoning level" is exactly the kind of thing a lab
        // should say before spending a request on it.
        if options.reasoning != nil, !supports(.reasoning) {
            throw KilnModelError.generationFailed(
                issue: .unsupportedCapability,
                detail: "\(displayName) does not advertise the reasoning capability. "
                      + "Advertised: \(capabilities.map(\.rawValue).sorted().joined(separator: ", "))."
            )
        }

        if !options.tools.isEmpty, !supports(.toolCalling) {
            throw KilnModelError.generationFailed(
                issue: .unsupportedCapability,
                detail: "\(displayName) does not advertise the tool-calling capability, "
                      + "so the \(options.tools.count) offered tool(s) cannot be registered."
            )
        }

        // A session is created per call rather than held across calls. Multi-turn
        // context is a lab subject in its own right — sharing a session here would
        // silently make every run depend on the ones before it, which is exactly the
        // variable a lab needs to control rather than inherit.
        let session = LanguageModelSession(
            model: model,
            tools: Self.tools(for: options.tools),
            instructions: instructions
        )

        let clock = ContinuousClock()
        let started = clock.now

        do {
            let response = try await session.respond(
                to: prompt,
                options: Self.generationOptions(from: options),
                contextOptions: Self.contextOptions(from: options)
            )
            return KilnRun(
                content: response.content,
                usage: Self.usage(from: response.usage),
                entries: response.transcriptEntries.map(Self.kind(of:)),
                duration: clock.now - started
            )
        } catch let error as LanguageModelError {
            throw KilnModelError.generationFailed(
                issue: Self.issue(for: error),
                detail: Self.detail(for: error)
            )
        } catch {
            throw KilnModelError.generationFailed(
                issue: .other,
                detail: error.localizedDescription
            )
        }
    }

    // MARK: - Request mapping

    /// Neutral identifiers in, Apple's `Tool` values out. The switch is exhaustive on
    /// purpose: adding a `KilnToolID` should fail to compile here until this provider
    /// decides whether it can host it.
    static func tools(for ids: Set<KilnToolID>) -> [any Tool] {
        ids.sorted { $0.rawValue < $1.rawValue }.map { id in
            switch id {
            case .coneTemperature: ConeTemperatureTool()
            }
        }
    }

    static func generationOptions(from options: KilnRunOptions) -> GenerationOptions {
        GenerationOptions(
            temperature: options.temperature,
            maximumResponseTokens: options.maximumResponseTokens,
            toolCallingMode: options.toolCalling == .disallowed ? .disallowed : .allowed
        )
    }

    static func contextOptions(from options: KilnRunOptions) -> ContextOptions {
        ContextOptions(reasoningLevel: options.reasoning.map(Self.reasoningLevel(for:)))
    }

    static func reasoningLevel(for level: KilnReasoningLevel) -> ContextOptions.ReasoningLevel {
        switch level {
        case .light: .light
        case .moderate: .moderate
        case .deep: .deep
        }
    }

    // MARK: - Response mapping

    static func usage(from usage: LanguageModelSession.Usage) -> KilnTokenUsage {
        KilnTokenUsage(
            inputTokens: usage.input.totalTokenCount,
            cachedInputTokens: usage.input.cachedTokenCount,
            outputTokens: usage.output.totalTokenCount,
            reasoningTokens: usage.output.reasoningTokenCount
        )
    }

    /// `.reasoning` is the only entry kind iOS 27 added. Recording kinds rather than
    /// payloads keeps this total and provider-neutral — `Transcript.Reasoning` exposes an
    /// `Action` with no public members, so there is nothing else to carry anyway.
    static func kind(of entry: Transcript.Entry) -> KilnTranscriptEntryKind {
        switch entry {
        case .instructions: .instructions
        case .prompt: .prompt
        case .response: .response
        case .reasoning: .reasoning
        case .toolCalls: .toolCalls
        case .toolOutput: .toolOutput
        @unknown default: .unknown
        }
    }

    // MARK: - Error mapping

    /// Maps Apple's `LanguageModelError` onto Kiln's provider-neutral issues.
    ///
    /// This mapping is the whole reason `KilnGenerationIssue` exists. Flattening these
    /// to `localizedDescription` loses the one distinction that changes what you do
    /// next — `assetsUnavailable` (broken environment) reads identically to
    /// `guardrailViolation` (rephrase the prompt) once it is a string.
    ///
    /// iOS 27 deprecated `LanguageModelSession.GenerationError` in favour of this type,
    /// and the taxonomy genuinely shifted rather than merely being renamed:
    /// `assetsUnavailable` moved up to `SystemLanguageModel.Error` (a model-level, not
    /// generation-level, failure), `concurrentRequests` and `decodingFailure` are gone,
    /// and `timeout`, `unsupportedCapability` and `unsupportedTranscriptContent` arrived.
    /// Kiln keeps the departed cases: they still describe how a provider can fail, and
    /// an MLX provider will need them.
    static func issue(for error: LanguageModelError) -> KilnGenerationIssue {
        switch error {
        case .contextSizeExceeded: .contextWindowExceeded
        case .guardrailViolation: .guardrailViolation
        case .refusal: .refused
        case .rateLimited: .rateLimited
        case .unsupportedLanguageOrLocale: .unsupportedLanguageOrLocale
        case .unsupportedGenerationGuide: .decodingFailure
        case .unsupportedCapability: .unsupportedCapability
        case .unsupportedTranscriptContent: .unsupportedTranscriptContent
        case .timeout: .timedOut
        @unknown default: .other
        }
    }

    /// Every case carries a payload with the framework's own debug text. Surfacing it
    /// is not optional in a lab — the missing-asset failure names the exact asset
    /// (`com.apple.fm.language.instruct_300m.safety`), which is the difference between
    /// a diagnosis and a shrug.
    static func detail(for error: LanguageModelError) -> String? {
        switch error {
        case .contextSizeExceeded(let c): c.debugDescription
        case .guardrailViolation(let c): c.debugDescription
        case .refusal(let c): c.debugDescription
        case .rateLimited(let c): c.debugDescription
        case .unsupportedLanguageOrLocale(let c): c.debugDescription
        case .unsupportedGenerationGuide(let c): c.debugDescription
        case .unsupportedCapability(let c): c.debugDescription
        case .unsupportedTranscriptContent(let c): c.debugDescription
        case .timeout(let c): c.debugDescription
        @unknown default: nil
        }
    }
}

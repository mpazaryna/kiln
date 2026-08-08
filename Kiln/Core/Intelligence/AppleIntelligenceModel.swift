import Foundation
import FoundationModels

/// Apple Intelligence — the on-device system model, via `FoundationModels`.
///
/// The first `KilnModel` conformance, and the reason the protocol's surface is as small
/// as it is: everything here is available from a system framework with no package
/// dependency, no build-tool plugin, and no network access.
struct AppleIntelligenceModel: KilnModel {
    let identifier = "apple-intelligence"
    let displayName = "Apple Intelligence"

    var availability: KilnModelAvailability {
        switch SystemLanguageModel.default.availability {
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

    func respond(to prompt: String, instructions: String?) async throws -> String {
        guard case .available = availability else {
            throw KilnModelError.unavailable(availability.reason ?? "unknown")
        }

        // A session is created per call rather than held across calls. Multi-turn
        // context is a lab subject in its own right — sharing a session here would
        // silently make every run depend on the ones before it, which is exactly the
        // variable a lab needs to control rather than inherit.
        let session = if let instructions {
            LanguageModelSession(instructions: instructions)
        } else {
            LanguageModelSession()
        }

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
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

    /// Maps Apple's `GenerationError` onto Kiln's provider-neutral issues.
    ///
    /// This mapping is the whole reason `KilnGenerationIssue` exists. Flattening these
    /// to `localizedDescription` loses the one distinction that changes what you do
    /// next — `assetsUnavailable` (broken environment) reads identically to
    /// `guardrailViolation` (rephrase the prompt) once it is a string.
    static func issue(for error: LanguageModelSession.GenerationError) -> KilnGenerationIssue {
        switch error {
        case .assetsUnavailable: .assetsUnavailable
        case .exceededContextWindowSize: .contextWindowExceeded
        case .guardrailViolation: .guardrailViolation
        case .refusal: .refused
        case .rateLimited: .rateLimited
        case .concurrentRequests: .concurrentRequests
        case .unsupportedLanguageOrLocale: .unsupportedLanguageOrLocale
        case .decodingFailure, .unsupportedGuide: .decodingFailure
        @unknown default: .other
        }
    }

    /// Every case carries a `Context` with the framework's own debug text. Surfacing it
    /// is not optional in a lab — the missing-asset failure names the exact asset
    /// (`com.apple.fm.language.instruct_300m.safety`), which is the difference between
    /// a diagnosis and a shrug.
    static func detail(for error: LanguageModelSession.GenerationError) -> String? {
        let context: LanguageModelSession.GenerationError.Context? = switch error {
        case .assetsUnavailable(let c),
             .exceededContextWindowSize(let c),
             .guardrailViolation(let c),
             .rateLimited(let c),
             .concurrentRequests(let c),
             .unsupportedLanguageOrLocale(let c),
             .decodingFailure(let c),
             .unsupportedGuide(let c):
            c
        case .refusal(_, let c):
            c
        @unknown default:
            nil
        }
        return context?.debugDescription
    }
}

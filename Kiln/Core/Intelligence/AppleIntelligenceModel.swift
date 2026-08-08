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
        } catch {
            throw KilnModelError.generationFailed(error.localizedDescription)
        }
    }
}

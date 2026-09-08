import Foundation
import FoundationModels

/// `ConeTemperature` conformed to Apple's `Tool` protocol.
///
/// This file is where a provider-specific shape meets Kiln's neutral logic, and it is
/// deliberately thin: the table, the parsing and the phrasing all live in
/// `ConeTemperature`, which knows nothing about `FoundationModels`. Everything here is
/// the adapter.
///
/// `@Generable` on `Arguments` is what gives the model a schema to fill in — it is the
/// same guided-generation machinery `SystemLanguageModel` advertises as a capability,
/// reached through the tool-calling door rather than the structured-output one.
struct ConeTemperatureTool: Tool {
    let name = "coneTemperature"
    let description = """
        Look up the firing temperature of an Orton pyrometric cone. \
        Use this whenever a specific cone number is mentioned — the numbering is \
        counter-intuitive and must not be guessed.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The cone designation, such as \"06\", \"6\", or \"10\". Zero-prefixed cones are cooler than their unprefixed counterparts.")
        var cone: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let answer = ConeTemperature.describe(arguments.cone) else {
            // Returning a sentence rather than throwing: a tool failure the model can
            // read and recover from beats an error that aborts the whole generation.
            return "No cone matching \"\(arguments.cone)\" is in the table. "
                 + "Known cones: \(ConeTemperature.knownCones.joined(separator: ", "))."
        }
        return answer
    }
}

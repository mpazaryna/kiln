import Testing
import FoundationModels
@testable import Kiln

/// Covers the translation from Apple's `GenerationError` to Kiln's provider-neutral
/// issues. Deterministic — `GenerationError.Context` has a public initializer, so every
/// case can be constructed without a live model.
///
/// This suite exists because of a real failure: a Simulator run reported the model
/// `.available`, then failed generation because `com.apple.fm.language.instruct_300m.safety`
/// was missing. The original code flattened that to `localizedDescription`, which made
/// a broken environment indistinguishable from a rejected prompt.
@Suite("GenerationError mapping")
struct GenerationErrorMappingTests {
    private func context(_ text: String = "test") -> LanguageModelSession.GenerationError.Context {
        .init(debugDescription: text)
    }

    @Test("missing assets map to assetsUnavailable, not a generic failure")
    func assetsUnavailableMapsDistinctly() {
        let issue = AppleIntelligenceModel.issue(for: .assetsUnavailable(context()))

        #expect(issue == .assetsUnavailable)
        #expect(issue != .other)
    }

    @Test("each mapped case is distinct from the catch-all")
    func mappedCasesAreDistinct() {
        let pairs: [(LanguageModelSession.GenerationError, KilnGenerationIssue)] = [
            (.assetsUnavailable(context()), .assetsUnavailable),
            (.exceededContextWindowSize(context()), .contextWindowExceeded),
            (.guardrailViolation(context()), .guardrailViolation),
            (.rateLimited(context()), .rateLimited),
            (.concurrentRequests(context()), .concurrentRequests),
            (.unsupportedLanguageOrLocale(context()), .unsupportedLanguageOrLocale),
            (.decodingFailure(context()), .decodingFailure),
        ]

        for (error, expected) in pairs {
            #expect(AppleIntelligenceModel.issue(for: error) == expected)
        }
    }

    /// The framework's debug text names the specific missing asset. Losing it turns a
    /// diagnosis into a shrug, so the mapper must carry it through.
    @Test("the framework's debug description survives mapping")
    func detailIsPreserved() {
        let text = "Failed model manager query for model com.apple.fm.language.instruct_300m.safety"
        let detail = AppleIntelligenceModel.detail(for: .assetsUnavailable(context(text)))

        #expect(detail == text)
    }

    /// Missing assets are an environment problem with a concrete fix, so the issue must
    /// offer one. A guardrail rejection has a different fix, and a refusal has none —
    /// that difference is the reason these are separate cases.
    @Test("recovery advice is present where an action exists")
    func recoveryAdvicePresence() {
        #expect(KilnGenerationIssue.assetsUnavailable.recovery != nil)
        #expect(KilnGenerationIssue.contextWindowExceeded.recovery != nil)
        #expect(KilnGenerationIssue.guardrailViolation.recovery != nil)
        #expect(KilnGenerationIssue.refused.recovery == nil)
    }

    @Test("errors expose summary, recovery and raw detail separately")
    func errorSurfacesAllThree() {
        let error = KilnModelError.generationFailed(issue: .assetsUnavailable, detail: "raw text")

        #expect(error.errorDescription == KilnGenerationIssue.assetsUnavailable.summary)
        #expect(error.recoverySuggestion == KilnGenerationIssue.assetsUnavailable.recovery)
        #expect(error.detail == "raw text")
    }
}

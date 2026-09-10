import Testing
import Foundation
import FoundationModels
@testable import Kiln

/// Covers Kiln's provider-neutral failure taxonomy and the response mapping around it.
///
/// This suite exists because of a real failure: a Simulator run reported the model
/// `.available`, then failed generation because `com.apple.fm.language.instruct_300m.safety`
/// was missing. The original code flattened that to `localizedDescription`, which made
/// a broken environment indistinguishable from a rejected prompt.
///
/// **iOS 27 changed what can be tested here, and it is worth knowing why.** ADR-003
/// recorded the pattern "tests construct `GenerationError` cases directly — `Context` has
/// a public initializer — so the mapping is verified without a live model." That is no
/// longer possible: `LanguageModelSession.GenerationError` is deprecated, and the
/// replacement `LanguageModelError` payloads (`GuardrailViolation`, `Timeout`,
/// `UnsupportedCapability`, …) expose public properties but **no public initializer**.
/// A test cannot build one, so `AppleIntelligenceModel.issue(for:)` and `detail(for:)`
/// are no longer unit-testable by construction.
///
/// What is still deterministic — and is what this suite now covers — is everything on
/// Kiln's own side of the seam: the issue taxonomy's semantics, and the request/response
/// mapping, which `LanguageModelSession.Usage` does still allow us to construct.
@Suite("Generation mapping")
struct GenerationErrorMappingTests {

    // MARK: - Issue taxonomy

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

    /// The framework returns `nil` for `recoverySuggestion` on `unsupportedCapability` —
    /// verified live against macOS 27 — which is precisely the case where a human can
    /// most easily act. Kiln supplying its own advice here is the seam earning its keep.
    @Test("iOS 27's new issues carry Kiln's own recovery advice")
    func newIssuesHaveRecovery() {
        #expect(KilnGenerationIssue.unsupportedCapability.recovery != nil)
        #expect(KilnGenerationIssue.timedOut.recovery != nil)
        #expect(KilnGenerationIssue.unsupportedTranscriptContent.recovery == nil)
    }

    @Test("every issue has a non-empty summary")
    func everyIssueHasSummary() {
        let all: [KilnGenerationIssue] = [
            .assetsUnavailable, .contextWindowExceeded, .guardrailViolation, .refused,
            .rateLimited, .concurrentRequests, .unsupportedLanguageOrLocale,
            .decodingFailure, .unsupportedCapability, .unsupportedTranscriptContent,
            .timedOut, .other,
        ]
        for issue in all {
            #expect(!issue.summary.isEmpty, "\(issue) has an empty summary")
        }
    }

    @Test("errors expose summary, recovery and raw detail separately")
    func errorSurfacesAllThree() {
        let error = KilnModelError.generationFailed(issue: .assetsUnavailable, detail: "raw text")

        #expect(error.errorDescription == KilnGenerationIssue.assetsUnavailable.summary)
        #expect(error.recoverySuggestion == KilnGenerationIssue.assetsUnavailable.recovery)
        #expect(error.detail == "raw text")
    }

    // MARK: - Request mapping

    /// Kiln registers no tools, so `.disallowed` is the default. Issue #7 was a
    /// session with zero tools narrating a search for tools into its answer.
    @Test("tool calling defaults to disallowed")
    func toolCallingDefaultsToDisallowed() {
        #expect(KilnRunOptions.default.toolCalling == .disallowed)
        #expect(KilnRunOptions.default.reasoning == nil)
    }

    @Test("run options map onto GenerationOptions")
    func generationOptionsMapping() {
        var options = KilnRunOptions.default
        options.temperature = 0.5
        options.maximumResponseTokens = 128

        let mapped = AppleIntelligenceModel.generationOptions(from: options)

        #expect(mapped.temperature == 0.5)
        #expect(mapped.maximumResponseTokens == 128)
        #expect(mapped.toolCallingMode == .disallowed)
    }

    @Test("reasoning is absent from context options unless asked for")
    func contextOptionsMapping() {
        #expect(AppleIntelligenceModel.contextOptions(from: .default).reasoningLevel == nil)

        var options = KilnRunOptions.default
        options.reasoning = .deep
        #expect(AppleIntelligenceModel.contextOptions(from: options).reasoningLevel == .deep)
    }

    // MARK: - Response mapping

    /// `Usage` is one of the few iOS 27 types with a public initializer, so the token
    /// mapping stays deterministic. Reasoning tokens are carried even though the macOS 27
    /// system model reports zero — watching that stay zero is the point.
    @Test("usage maps every token count through")
    func usageMapping() {
        let native = LanguageModelSession.Usage(
            input: .init(totalTokenCount: 65, cachedTokenCount: 12),
            output: .init(totalTokenCount: 39, reasoningTokenCount: 0)
        )

        let mapped = AppleIntelligenceModel.usage(from: native)

        #expect(mapped.inputTokens == 65)
        #expect(mapped.cachedInputTokens == 12)
        #expect(mapped.outputTokens == 39)
        #expect(mapped.reasoningTokens == 0)
    }
}

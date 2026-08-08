import Foundation

/// The set of providers Kiln can run against, and which one is selected.
///
/// This is a *service*, injected through `@Environment` — not a ViewModel (ADR-001).
/// The distinction is not cosmetic: it holds no view state, has no knowledge of any
/// view, and would be equally usable from a test or a command-line harness.
///
/// It exists at commit 1 with a single provider because provider comparison is Kiln's
/// reason to exist. A registry with one entry costs nothing; a registry retrofitted
/// after twenty call sites hardcoded `AppleIntelligenceModel` costs a refactor.
@Observable
@MainActor
final class ModelRegistry {
    private(set) var models: [any KilnModel]
    var selectedIdentifier: String

    init(models: [any KilnModel] = [AppleIntelligenceModel()]) {
        precondition(!models.isEmpty, "ModelRegistry requires at least one model")
        self.models = models
        self.selectedIdentifier = models[0].identifier
    }

    /// Falls back to the first model rather than returning nil: a selection pointing at
    /// a provider that is no longer registered is a programming error, and degrading to
    /// "no model at all" would surface as an inexplicably dead Run button.
    var selected: any KilnModel {
        models.first { $0.identifier == selectedIdentifier } ?? models[0]
    }
}

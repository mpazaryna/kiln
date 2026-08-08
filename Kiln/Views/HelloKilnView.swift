import SwiftUI

/// Local layout config (ADR-000 / ADR-006). Flattens shared values from
/// `BasePlatformConfig` and adds the properties only this view needs, so the view body
/// reads named properties and never a literal.
///
/// `fileprivate` and local is the default pattern rather than the exception: it keeps
/// ownership next to the view and avoids the AttributeGraph cycles that shared configs
/// can trigger in split-view hierarchies.
private struct HelloLayoutConfig {
    // MARK: Flattened from BasePlatformConfig
    let screenPadding: CGFloat
    let sectionSpacing: CGFloat
    let cardPadding: CGFloat
    let cornerRadius: CGFloat
    let titleFont: Font
    let bodyFont: Font
    let captionFont: Font
    let controlSize: ControlSize

    // MARK: HelloKilnView-specific
    let promptMinHeight: CGFloat
    let resultMinHeight: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                screenPadding: base.screenPadding,
                sectionSpacing: base.sectionSpacing,
                cardPadding: base.cardPadding,
                cornerRadius: base.cornerRadius,
                titleFont: base.titleFont,
                bodyFont: base.bodyFont,
                captionFont: base.captionFont,
                controlSize: base.controlSize,
                promptMinHeight: 120,
                resultMinHeight: 200
            )
            : Self(  // iPhone
                screenPadding: base.screenPadding,
                sectionSpacing: base.sectionSpacing,
                cardPadding: base.cardPadding,
                cornerRadius: base.cornerRadius,
                titleFont: base.titleFont,
                bodyFont: base.bodyFont,
                captionFont: base.captionFont,
                controlSize: base.controlSize,
                promptMinHeight: 90,
                resultMinHeight: 140
            )
    }
    #else
    static var current: Self {
        let base = BasePlatformConfig.current
        return Self(
            screenPadding: base.screenPadding,
            sectionSpacing: base.sectionSpacing,
            cardPadding: base.cardPadding,
            cornerRadius: base.cornerRadius,
            titleFont: base.titleFont,
            bodyFont: base.bodyFont,
            captionFont: base.captionFont,
            controlSize: base.controlSize,
            promptMinHeight: 140,
            resultMinHeight: 240
        )
    }
    #endif
}

/// Kiln's first firing: one prompt, one provider, one response.
///
/// Deliberately the whole app for now. It establishes the three patterns everything
/// else inherits — config-driven layout, enum view state, and a provider reached
/// through `KilnModel` rather than named directly.
struct HelloKilnView: View {
    // MARK: - Platform Configuration
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: HelloLayoutConfig { HelloLayoutConfig.current(sizeClass) }
    #else
    private var config: HelloLayoutConfig { HelloLayoutConfig.current }
    #endif

    // MARK: - Environment Dependencies
    @Environment(ModelRegistry.self) private var registry

    // MARK: - View State
    /// Mutually exclusive states as an enum, so the view cannot render "running" and
    /// "failed" at once and no boolean pair can drift out of sync (ADR-001).
    /// A failure split into what happened, what to do, and the raw framework text.
    /// Keeping `detail` separate is what lets the UI show a one-line diagnosis without
    /// discarding the evidence underneath it.
    private struct Failure {
        let summary: String
        let recovery: String?
        let detail: String?
    }

    private enum RunState {
        case idle
        case running
        case success(String)
        case failed(Failure)
    }

    @State private var prompt = "Explain what a kiln does, in two sentences."
    @State private var state: RunState = .idle

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: config.sectionSpacing) {
            header
            promptEditor
            runButton
            result
            Spacer(minLength: 0)
        }
        .padding(config.screenPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text("Hello, Kiln")
                .font(config.titleFont)
            Text(registry.selected.displayName)
                .font(config.captionFont)
                .foregroundStyle(.secondary)
        }
    }

    private var promptEditor: some View {
        TextEditor(text: $prompt)
            .font(config.bodyFont)
            .frame(minHeight: config.promptMinHeight)
            .padding(config.cardPadding)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: config.cornerRadius))
            .scrollContentBackground(.hidden)
    }

    private var runButton: some View {
        Button {
            Task { await run() }
        } label: {
            if case .running = state {
                ProgressView()
            } else {
                Text("Fire")
            }
        }
        .controlSize(config.controlSize)
        .buttonStyle(.borderedProminent)
        .disabled(prompt.isEmpty || isRunning)
    }

    @ViewBuilder
    private var result: some View {
        switch state {
        case .idle:
            ContentUnavailableView(
                "Nothing fired yet",
                systemImage: "flame",
                description: Text(availabilityNote)
            )
            .frame(minHeight: config.resultMinHeight)

        case .running:
            ProgressView("Firing…")
                .frame(maxWidth: .infinity, minHeight: config.resultMinHeight)

        case .success(let text):
            ScrollView {
                Text(text)
                    .font(config.bodyFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: config.resultMinHeight)
            .padding(config.cardPadding)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: config.cornerRadius))

        case .failed(let failure):
            ScrollView {
                VStack(alignment: .leading, spacing: config.sectionSpacing) {
                    ContentUnavailableView(
                        failure.summary,
                        systemImage: "exclamationmark.triangle",
                        description: failure.recovery.map(Text.init)
                    )

                    if let detail = failure.detail {
                        // Shown, not hidden behind a disclosure. In a lab the raw
                        // framework text is the most valuable thing on screen — it is
                        // what names the missing asset or the offending guide.
                        Text(detail)
                            .font(config.captionFont)
                            .monospaced()
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(config.cardPadding)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: config.cornerRadius))
                    }
                }
            }
            .frame(minHeight: config.resultMinHeight)
        }
    }

    // MARK: - Private Methods
    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Surfaced on the idle screen rather than only on failure — an unavailable provider
    /// should be visible before you press the button, not discovered by pressing it.
    private var availabilityNote: String {
        registry.selected.availability.reason ?? "Ready to fire."
    }

    private func run() async {
        state = .running
        do {
            let text = try await registry.selected.respond(to: prompt, instructions: nil)
            state = .success(text)
        } catch let error as KilnModelError {
            state = .failed(Failure(
                summary: error.errorDescription ?? "Firing failed",
                recovery: error.recoverySuggestion,
                detail: error.detail
            ))
        } catch {
            state = .failed(Failure(
                summary: "Firing failed",
                recovery: nil,
                detail: error.localizedDescription
            ))
        }
    }
}

#Preview("Hello Kiln") {
    HelloKilnView()
        .environment(ModelRegistry())
}

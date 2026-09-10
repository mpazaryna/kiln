import SwiftUI
import UniformTypeIdentifiers

/// Local layout config (ADR-000). Flattens shared values from `BasePlatformConfig` and
/// adds the properties only this view needs, so the view body reads named properties and
/// never a literal.
///
/// `fileprivate` and local is the default pattern rather than the exception: it keeps
/// ownership next to the view and avoids the AttributeGraph cycles that shared configs
/// can trigger in split-view hierarchies.
fileprivate struct HelloLayoutConfig {
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
    let controlSpacing: CGFloat
    let metricSpacing: CGFloat
    let thumbnailSize: CGFloat

    /// Controls sit in a row where there is width for one and stack where there is not.
    /// The choice is made here, once, so the body renders a single set of children under
    /// either layout — no `sizeClass ==` in the view (ADR-000).
    let controlLayout: AnyLayout
    /// `.infinity` where a control should fill the width, `nil` for its natural size.
    let controlMaxWidth: CGFloat?
    let runButtonMaxWidth: CGFloat?

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
                resultMinHeight: 200,
                controlSpacing: 16,
                metricSpacing: 14,
                thumbnailSize: 56,
                controlLayout: AnyLayout(HStackLayout(spacing: 16)),
                controlMaxWidth: nil,
                runButtonMaxWidth: nil
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
                resultMinHeight: 140,
                controlSpacing: 12,
                metricSpacing: 10,
                thumbnailSize: 44,
                controlLayout: AnyLayout(VStackLayout(alignment: .leading, spacing: 12)),
                controlMaxWidth: .infinity,
                runButtonMaxWidth: .infinity
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
            resultMinHeight: 240,
            controlSpacing: 16,
            metricSpacing: 14,
            thumbnailSize: 56,
            controlLayout: AnyLayout(HStackLayout(spacing: 16)),
            controlMaxWidth: nil,
            runButtonMaxWidth: nil
        )
    }
    #endif
}

/// Kiln's first firing: one prompt, one provider, one response — and the evidence
/// around it.
///
/// Deliberately the whole app for now. It establishes the patterns everything else
/// inherits — config-driven layout, enum view state, a provider reached through
/// `KilnModel` rather than named directly, and controls gated on what the provider
/// actually advertises rather than on what the framework defines.
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
    /// A failure split into what happened, what to do, and the raw framework text.
    /// Keeping `detail` separate is what lets the UI show a one-line diagnosis without
    /// discarding the evidence underneath it.
    private struct Failure {
        let summary: String
        let recovery: String?
        let detail: String?
    }

    /// Mutually exclusive states as an enum, so the view cannot render "running" and
    /// "failed" at once and no boolean pair can drift out of sync (ADR-001).
    private enum RunState {
        case idle
        case running
        case success(KilnRun)
        case failed(Failure)
    }

    @State private var prompt = "Explain what a kiln does, in two sentences."
    @State private var state: RunState = .idle
    @State private var options = KilnRunOptions.default
    @State private var isChoosingImage = false

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: config.sectionSpacing) {
            header
            promptEditor
            controls
            attachments
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
            // What the provider says it can do, read from the framework at call time.
            // On macOS 27 this Mac advertises tool calling, vision and guided generation
            // — and not reasoning, which is why the reasoning control below is disabled.
            Text(capabilityNote)
                .font(config.captionFont)
                .foregroundStyle(.tertiary)
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

    /// Lab controls, each gated on a capability rather than on an OS version. A control
    /// the provider cannot honour is shown and disabled, not hidden — knowing the knob
    /// exists and this model ignores it is the comparison a lab is for.
    private var controls: some View {
        config.controlLayout {
            // LabeledContent, not a bare Picker: `.menu` style renders only the selected
            // value, so a Picker dropped into a stack loses its label entirely and floats
            // centred. LabeledContent puts the name leading and the value trailing, which
            // is the row shape iOS uses for settings everywhere.
            LabeledContent("Tools") {
                Picker("Tools", selection: $options.toolCalling) {
                    ForEach(KilnToolCalling.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .frame(maxWidth: config.controlMaxWidth)
            .disabled(!registry.selected.supports(.toolCalling))

            LabeledContent("Reasoning") {
                Picker("Reasoning", selection: $options.reasoning) {
                    Text("Off").tag(KilnReasoningLevel?.none)
                    ForEach(KilnReasoningLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(KilnReasoningLevel?.some(level))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .frame(maxWidth: config.controlMaxWidth)
            .disabled(!registry.selected.supports(.reasoning))

            Toggle("Cone tool", isOn: Binding(
                get: { options.tools.contains(.coneTemperature) },
                set: { isOn in
                    if isOn { options.tools.insert(.coneTemperature) }
                    else { options.tools.remove(.coneTemperature) }
                }
            ))
            .frame(maxWidth: config.controlMaxWidth)
            .disabled(!registry.selected.supports(.toolCalling))

            Button("Attach image", systemImage: "photo") { isChoosingImage = true }
                .frame(maxWidth: config.controlMaxWidth, alignment: .leading)
                .disabled(!registry.selected.supports(.vision))
        }
        .controlSize(config.controlSize)
        .padding(config.cardPadding)
        // Glass on the controls only. The prompt and response panels hold text that has to
        // read clearly, so they keep a flat `.quaternary` fill (#11).
        .glassEffect(in: RoundedRectangle(cornerRadius: config.cornerRadius))
        .fileImporter(
            isPresented: $isChoosingImage,
            allowedContentTypes: [.image]
        ) { result in
            // The picker is what grants a sandboxed app access to the file. The URL is
            // stored and the security scope is opened later, around the read itself —
            // see AppleIntelligenceModel.run.
            if case .success(let url) = result {
                options.attachments = [.image(url: url, label: url.lastPathComponent)]
            }
        }
    }

    /// What is going to the model besides the text. Shown rather than implied: an
    /// attachment silently riding along is the kind of hidden variable a lab exists to
    /// eliminate.
    @ViewBuilder
    private var attachments: some View {
        if !options.attachments.isEmpty {
            HStack(spacing: config.controlSpacing) {
                ForEach(options.attachments, id: \.label) { attachment in
                    AsyncImage(url: attachment.url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: config.cornerRadius).fill(.quaternary)
                    }
                    .frame(width: config.thumbnailSize, height: config.thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))

                    Text(attachment.label)
                        .font(config.captionFont)
                        .foregroundStyle(.secondary)
                }
                Button("Remove", systemImage: "xmark.circle.fill") {
                    options.attachments = []
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                Spacer()
            }
        }
    }

    /// The primary action, on its own row. It shared a line with four other controls
    /// until an iPhone showed what that looks like below 400 points.
    private var runButton: some View {
        Button {
            Task { await run() }
        } label: {
            Group {
                if case .running = state {
                    ProgressView()
                } else {
                    Text("Fire")
                }
            }
            .frame(maxWidth: config.runButtonMaxWidth)
        }
        .controlSize(config.controlSize)
        .buttonStyle(.borderedProminent)
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
    }

    @ViewBuilder
    private var result: some View {
        switch state {
        case .idle:
            // Full width, like every other state. The body stacks with leading alignment,
            // so a view that only sets a height shrinks to its content and hugs the left.
            ContentUnavailableView(
                "Nothing fired yet",
                systemImage: "flame",
                description: Text(availabilityNote)
            )
            .frame(maxWidth: .infinity, minHeight: config.resultMinHeight)

        case .running:
            ProgressView("Firing…")
                .frame(maxWidth: .infinity, minHeight: config.resultMinHeight)

        case .success(let run):
            VStack(alignment: .leading, spacing: config.metricSpacing) {
                ScrollView {
                    Text(run.content)
                        .font(config.bodyFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: config.resultMinHeight)
                .padding(config.cardPadding)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: config.cornerRadius))

                metrics(for: run)
            }

        case .failed(let failure):
            ScrollView {
                VStack(alignment: .leading, spacing: config.sectionSpacing) {
                    ContentUnavailableView(
                        failure.summary,
                        systemImage: "exclamationmark.triangle",
                        description: failure.recovery.map(Text.init)
                    )
                    .frame(maxWidth: .infinity)

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

    /// The evidence around the answer. `respond` used to return a bare `String`, which
    /// threw all of this away — in a lab it is half the point of running the prompt.
    private func metrics(for run: KilnRun) -> some View {
        VStack(alignment: .leading, spacing: config.metricSpacing) {
            HStack(spacing: config.controlSpacing) {
                if let usage = run.usage {
                    Label("\(usage.inputTokens) in", systemImage: "arrow.down")
                    Label("\(usage.outputTokens) out", systemImage: "arrow.up")
                    if usage.cachedInputTokens > 0 {
                        Label("\(usage.cachedInputTokens) cached", systemImage: "clock.arrow.circlepath")
                    }
                    // Always shown, including at zero. Watching it stay zero on a model
                    // that does not advertise reasoning is the lesson.
                    Label("\(usage.reasoningTokens) reasoning", systemImage: "brain")
                }
                Label(run.duration.formatted(.units(allowed: [.seconds, .milliseconds])),
                      systemImage: "timer")
            }
            if !run.entries.isEmpty {
                Text("transcript: " + run.entries.map(\.rawValue).joined(separator: " → "))
                    .monospaced()
            }
        }
        .font(config.captionFont)
        .foregroundStyle(.secondary)
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

    private var capabilityNote: String {
        let caps = registry.selected.capabilities
        guard !caps.isEmpty else { return "No capabilities advertised" }
        return caps.map(\.displayName).sorted().joined(separator: " · ")
    }

    private func run() async {
        state = .running
        do {
            let run = try await registry.selected.run(prompt, instructions: nil, options: options)
            state = .success(run)
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

// Both appearances, pinned, so the canvas shows them side by side. Contrast is checked here
// without switching the whole Mac, and the app itself still follows the system.
#Preview("Hello Kiln · Light") {
    HelloKilnView()
        .environment(ModelRegistry())
        .preferredColorScheme(.light)
}

#Preview("Hello Kiln · Dark") {
    HelloKilnView()
        .environment(ModelRegistry())
        .preferredColorScheme(.dark)
}

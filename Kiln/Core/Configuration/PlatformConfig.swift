import SwiftUI

/// Foundation primitives for platform-adaptive layout — the single source of truth
/// for values shared across more than one view (ADR-000).
///
/// View-specific configs **flatten** these values rather than nesting them, so views
/// read `config.cardPadding` and never `config.base.cardPadding`. Flattening is what
/// lets a property move between the base and a local config without touching any view.
///
/// Nothing here is a magic number at the point of use: views consume named properties,
/// so changing iPad spacing is one edit in one file rather than a search across the
/// codebase.
struct BasePlatformConfig {
    // MARK: Spacing
    let screenPadding: CGFloat
    let sectionSpacing: CGFloat
    let cardPadding: CGFloat
    let cardSpacing: CGFloat

    // MARK: Shape
    let cornerRadius: CGFloat

    // MARK: Typography
    let titleFont: Font
    let bodyFont: Font
    let captionFont: Font

    // MARK: Controls
    let controlSize: ControlSize

    #if os(iOS)
    /// iOS resolves iPad vs iPhone from the SwiftUI environment's horizontal size class
    /// rather than the idiom, so a Slide Over or split-screen iPad gets compact values —
    /// which is what the layout actually needs, not what the device nominally is.
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        sizeClass == .regular
            ? Self(  // iPad
                screenPadding: 32,
                sectionSpacing: 24,
                cardPadding: 20,
                cardSpacing: 16,
                cornerRadius: 12,
                titleFont: .largeTitle,
                bodyFont: .body,
                captionFont: .caption,
                controlSize: .large
            )
            : Self(  // iPhone
                screenPadding: 20,
                sectionSpacing: 16,
                cardPadding: 16,
                cardSpacing: 12,
                cornerRadius: 10,
                titleFont: .title,
                bodyFont: .body,
                captionFont: .caption,
                controlSize: .regular
            )
    }
    #else
    /// macOS has no size class — pointer precision and window space are a fixed
    /// assumption, so the config is a static property rather than a function.
    static var current: Self {
        Self(
            screenPadding: 40,
            sectionSpacing: 24,
            cardPadding: 20,
            cardSpacing: 16,
            cornerRadius: 10,
            titleFont: .largeTitle,
            bodyFont: .body,
            captionFont: .caption,
            controlSize: .large
        )
    }
    #endif
}

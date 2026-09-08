import Testing
import Foundation
@testable import Kiln

/// Attachments cross the seam as a URL and a label, never as a framework attachment
/// type — so everything about *which capability they need* is testable without a model.
@Suite("Attachments")
struct AttachmentTests {

    private let sample = URL(fileURLWithPath: "/tmp/kiln-sample.png")

    @Test("nothing is attached by default")
    func noneByDefault() {
        #expect(KilnRunOptions.default.attachments.isEmpty)
    }

    /// The attachment names the capability it needs, rather than the provider keeping a
    /// list of rules. Adding a future attachment kind extends the switch, not every
    /// provider's pre-flight.
    @Test("an image attachment requires vision")
    func imageRequiresVision() {
        let attachment = KilnAttachment.image(url: sample, label: "sample.png")

        #expect(attachment.requiredCapability == .vision)
        #expect(attachment.label == "sample.png")
        #expect(attachment.url == sample)
    }

    @Test("attachments preserve order")
    func orderPreserved() {
        var options = KilnRunOptions.default
        options.attachments = [
            .image(url: URL(fileURLWithPath: "/tmp/a.png"), label: "a"),
            .image(url: URL(fileURLWithPath: "/tmp/b.png"), label: "b"),
        ]

        #expect(options.attachments.map(\.label) == ["a", "b"])
    }

    /// A model that does not advertise vision must be refused before a request is spent.
    /// The on-device model *does* advertise it, so this is the branch a stub covers.
    @Test("a provider without vision cannot accept an image")
    func visionGating() {
        let sighted: Set<KilnModelCapability> = [.vision, .toolCalling]
        let blind: Set<KilnModelCapability> = [.toolCalling]
        let attachment = KilnAttachment.image(url: sample, label: "sample.png")

        #expect(sighted.contains(attachment.requiredCapability))
        #expect(!blind.contains(attachment.requiredCapability))
    }

    @Test("equality distinguishes url and label")
    func equality() {
        let a = KilnAttachment.image(url: sample, label: "one")
        let b = KilnAttachment.image(url: sample, label: "two")

        #expect(a == KilnAttachment.image(url: sample, label: "one"))
        #expect(a != b)
    }
}

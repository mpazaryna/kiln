import Testing
import Foundation
@testable import Kiln

/// The tool's logic is a pure lookup with no framework types, so it is fully
/// deterministic — no model, no network, no Apple Intelligence. That split is deliberate:
/// `ConeTemperature` is Kiln's, `ConeTemperatureTool` is the adapter onto Apple's `Tool`
/// protocol, and only the former needs covering here.
@Suite("Cone temperature")
struct ConeTemperatureTests {

    /// The trap this tool exists to stop a model falling into. Zero-prefixed cones run
    /// *cooler* as the number climbs, so 06 is far cooler than 6 — and a model asked
    /// without the tool gets it wrong (observed: it answered 1,100 °F for cone 06, which
    /// is 728 °F low).
    @Test("zero-prefixed cones are cooler than their unprefixed counterparts")
    func zeroPrefixedAreCooler() throws {
        let cone06 = try #require(ConeTemperature.table["06"])
        let cone6 = try #require(ConeTemperature.table["6"])

        #expect(cone06.celsius < cone6.celsius)
        #expect(cone06.fahrenheit == 1828)
        #expect(cone6.fahrenheit == 2269)
    }

    @Test("cone designations are normalised from how people write them")
    func normalisation() {
        #expect(ConeTemperature.normalise("cone 6") == "6")
        #expect(ConeTemperature.normalise("△6") == "6")
        #expect(ConeTemperature.normalise("  06 ") == "06")
        #expect(ConeTemperature.normalise("Cone 010") == "010")
        #expect(ConeTemperature.normalise("cone") == nil)
        #expect(ConeTemperature.normalise("   ") == nil)
    }

    @Test("a known cone describes both scales")
    func describeKnown() throws {
        let text = try #require(ConeTemperature.describe("cone 06"))

        #expect(text.contains("998"))
        #expect(text.contains("1828"))
    }

    @Test("an unknown cone describes nothing rather than guessing")
    func describeUnknown() {
        #expect(ConeTemperature.describe("42") == nil)
        #expect(ConeTemperature.describe("") == nil)
    }

    @Test("known cones are listed coolest first")
    func orderingIsPotterReadable() throws {
        let cones = ConeTemperature.knownCones

        let index022 = try #require(cones.firstIndex(of: "022"))
        let index06 = try #require(cones.firstIndex(of: "06"))
        let index6 = try #require(cones.firstIndex(of: "6"))

        #expect(index022 < index06, "022 is cooler than 06")
        #expect(index06 < index6, "06 is cooler than 6")
    }

    /// The tool answers rather than throwing on a miss. A tool failure the model can read
    /// and recover from beats an error that aborts the generation.
    @Test("an unknown cone returns a readable miss, not a throw")
    func toolHandlesMissGracefully() async throws {
        let tool = ConeTemperatureTool()

        let output = try await tool.call(arguments: .init(cone: "999"))

        #expect(output.contains("999"))
        #expect(output.contains("Known cones"))
    }

    @Test("the tool answers a known cone from the table")
    func toolAnswersKnownCone() async throws {
        let tool = ConeTemperatureTool()

        let output = try await tool.call(arguments: .init(cone: "cone 10"))

        #expect(output.contains("1305"))
    }
}

/// Tools cross the seam as neutral identifiers, not as Apple's `Tool` values.
@Suite("Tool registration")
struct ToolRegistrationTests {
    @Test("no tools are offered by default")
    func noneByDefault() {
        #expect(KilnRunOptions.default.tools.isEmpty)
        #expect(AppleIntelligenceModel.tools(for: []).isEmpty)
    }

    @Test("identifiers map to provider tools")
    func identifiersMap() {
        let tools = AppleIntelligenceModel.tools(for: [.coneTemperature])

        #expect(tools.count == 1)
        #expect(tools.first?.name == "coneTemperature")
    }

    /// Offering a tool and forbidding calls is a legitimate experiment, not a
    /// contradiction to be normalised away — the observable difference between the two is
    /// the comparison the lab is for.
    @Test("offering a tool is independent of permitting calls")
    func offeringIsIndependentOfCalling() {
        var options = KilnRunOptions.default
        options.tools = [.coneTemperature]

        #expect(options.toolCalling == .disallowed)
        #expect(!options.tools.isEmpty)
    }
}

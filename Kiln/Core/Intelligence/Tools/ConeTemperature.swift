import Foundation

/// Orton pyrometric cone → firing temperature.
///
/// The lookup itself is deliberately provider-neutral and pure: no framework types, no
/// I/O, no async. That split is the point — the *logic* a tool performs is Kiln's, while
/// conforming it to a particular framework's tool protocol is the provider's job. An MLX
/// provider will wrap this same table in whatever shape it needs.
///
/// Values are Orton self-supporting cones at 108 °F/hour. They are approximate by nature:
/// a cone measures heat *work*, not temperature, so a slower ramp bends the same cone
/// cooler. Good enough for a lab, and the ambiguity is itself worth showing a model.
enum ConeTemperature {
    /// Cone designations are not ordered the way they look. The `0`-prefixed cones run
    /// *cooler* as the number climbs — 06 is much cooler than 6 — which makes this a
    /// genuinely useful thing to hand a model, and an easy thing to get wrong.
    static let table: [String: (celsius: Int, fahrenheit: Int)] = [
        "022": (586, 1087),
        "018": (715, 1319),
        "010": (887, 1629),
        "06": (998, 1828),
        "05": (1031, 1888),
        "04": (1063, 1945),
        "03": (1086, 1987),
        "02": (1102, 2016),
        "01": (1119, 2046),
        "1": (1137, 2079),
        "5": (1207, 2205),
        "6": (1241, 2269),
        "8": (1271, 2320),
        "10": (1305, 2381),
    ]

    /// Normalises the many ways a person (or a model) writes a cone: "cone 6", "△6",
    /// "6", " 06 ". Returns nil when nothing usable is left.
    static func normalise(_ raw: String) -> String? {
        let stripped = raw
            .lowercased()
            .replacingOccurrences(of: "cone", with: "")
            .replacingOccurrences(of: "△", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }

    /// A sentence a model can drop straight into an answer, or nil when the cone is not
    /// in the table. Returning prose rather than a number is deliberate: the tool output
    /// goes back into the transcript as text the model reads.
    static func describe(_ raw: String) -> String? {
        guard let key = normalise(raw), let match = table[key] else { return nil }
        return "Cone \(key) matures at approximately \(match.celsius) °C "
             + "(\(match.fahrenheit) °F) at a 108 °F/hour ramp."
    }

    static var knownCones: [String] {
        // Sorted the way a potter reads them: coolest first, so the 0-prefixed run
        // descends before the plain numbers ascend.
        //
        // The 0-prefixed group must sort on the number *after* the zero, descending —
        // 022 is cooler than 06. Sorting these as strings looks right and is wrong:
        // "06" > "022" lexically, which puts the hottest of the group first.
        let zeroPrefixed = table.keys
            .filter { $0.hasPrefix("0") }
            .sorted { (Int($0.dropFirst()) ?? 0) > (Int($1.dropFirst()) ?? 0) }
        let plain = table.keys
            .filter { !$0.hasPrefix("0") }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
        return zeroPrefixed + plain
    }
}

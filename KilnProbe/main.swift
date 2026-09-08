import Foundation
import FoundationModels

// A command-line probe for Kiln's Intelligence layer.
//
// It links `Kiln/Core/Intelligence` rather than reimplementing it, so what this prints is
// what the app does. The point is to answer questions about the framework — what does
// this machine advertise, what does that error really map to, does the model call the
// tool — without launching a GUI and without adding a sandbox to every answer.

func heading(_ text: String) { print("\n\u{001B}[1m=== \(text) ===\u{001B}[0m") }

func describe(_ model: some KilnModel) {
    print("provider:     \(model.displayName)  (\(model.identifier))")
    print("availability: ", terminator: "")
    switch model.availability {
    case .available: print("available")
    case .unsupported(let why): print("unsupported — \(why)")
    case .notReady(let why): print("not ready — \(why)")
    }
    let caps = model.capabilities
    for capability in KilnModelCapability.allCases {
        print("  \(caps.contains(capability) ? "✓" : "·") \(capability.displayName)")
    }
}

func report(_ run: KilnRun) {
    print("\n\(run.content)\n")
    if let usage = run.usage {
        print("tokens:     in \(usage.inputTokens) (cached \(usage.cachedInputTokens))"
            + " · out \(usage.outputTokens) · reasoning \(usage.reasoningTokens)")
    }
    print("duration:   \(run.duration.formatted(.units(allowed: [.seconds, .milliseconds])))")
    print("transcript: \(run.entries.map(\.rawValue).joined(separator: " → "))")
}

func fire(_ prompt: String, options: KilnRunOptions) async {
    let model = AppleIntelligenceModel()
    do {
        report(try await model.run(prompt, instructions: nil, options: options))
    } catch let error as KilnModelError {
        print("\nFAILED: \(error.errorDescription ?? "unknown")")
        if let recovery = error.recoverySuggestion { print("recovery: \(recovery)") }
        if let detail = error.detail { print("detail:   \(detail)") }
    } catch {
        // Worth keeping distinct: an error arriving here rather than above means it did
        // not map to a KilnModelError, which is the flattening ADR-003 exists to prevent.
        print("\nUNMAPPED (\(type(of: error))): \(error)")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "capabilities"
let rest = args.dropFirst().joined(separator: " ")
let defaultPrompt = "Explain what a kiln does, in two sentences."

switch command {
case "capabilities":
    heading("On-device — SystemLanguageModel")
    describe(AppleIntelligenceModel())

    heading("Private Cloud Compute")
    let pcc = PrivateCloudComputeLanguageModel()
    print("isAvailable:  \(pcc.isAvailable)")
    print("quota:        \(pcc.quotaUsage.status)")
    print("capabilities: ", terminator: "")
    print(pcc.capabilities.contains(.reasoning) ? "includes reasoning" : "no reasoning")

case "run":
    heading("Run — tools off")
    await fire(rest.isEmpty ? defaultPrompt : rest, options: .default)

case "tool":
    // Offer the tool AND permit calls. Compare with `notool` to see the difference the
    // tool makes, and with `offered` to see a tool offered but forbidden.
    heading("Run — cone tool offered, calling allowed")
    var options = KilnRunOptions.default
    options.tools = [.coneTemperature]
    options.toolCalling = .allowed
    await fire(rest.isEmpty ? "What temperature does cone 06 mature at?" : rest, options: options)

case "offered":
    heading("Run — cone tool offered, calling DISALLOWED")
    var options = KilnRunOptions.default
    options.tools = [.coneTemperature]
    options.toolCalling = .disallowed
    await fire(rest.isEmpty ? "What temperature does cone 06 mature at?" : rest, options: options)

case "reasoning":
    heading("Run — reasoning requested (expected to fail on-device)")
    var options = KilnRunOptions.default
    options.reasoning = .deep
    await fire(rest.isEmpty ? defaultPrompt : rest, options: options)

case "errors":
    // Does a real framework failure survive the trip through Kiln's mapper, or does it
    // arrive as a bridged NSError and flatten to `.other`? That flattening is exactly
    // what ADR-003 exists to prevent, so it is worth provoking rather than assuming.
    let oversized = String(repeating: "kiln ", count: 200_000)

    heading("1. Oversized prompt through Kiln's seam")
    await fire(oversized, options: .default)

    heading("2. Same failure, raw — does it bridge to LanguageModelError?")
    do {
        let session = LanguageModelSession(model: SystemLanguageModel.default)
        _ = try await session.respond(to: oversized)
        print("unexpectedly succeeded")
    } catch let error as LanguageModelError {
        print("bridges ✓  → maps to .\(AppleIntelligenceModel.issue(for: error))")
    } catch {
        print("does NOT bridge ✗  type: \(type(of: error))")
        print("value: \(error)")
    }

    heading("3. Coherent long prompt — which limit fires first?")
    // Repeated filler trips the guardrail before the context check, which tells us
    // nothing about the context limit. Coherent prose is the fairer probe.
    let sentence = "The kiln reached temperature slowly and the potter watched the cone bend. "
    for count in [2_000, 20_000] {
        let prompt = String(repeating: sentence, count: count)
        print("\n-- \(count) sentences (~\(prompt.count / 4) tokens) --")
        await fire(prompt, options: .default)
    }

    print("\n(PCC is deliberately not exercised here — it traps. See `probe.sh pcc`.)")

case "vision":
    // Goes through Kiln's seam, not the raw framework — the point is to exercise the
    // mapping and the sandbox-scope handling, not just prove the API exists.
    heading("Vision — image attached through KilnRunOptions")
    let imagePath = rest.isEmpty
        ? "Kiln/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
        : rest
    let url = URL(fileURLWithPath: imagePath).standardizedFileURL
    guard FileManager.default.fileExists(atPath: url.path) else {
        print("no such image: \(url.path)")
        break
    }
    print("image:      \(url.lastPathComponent)")
    print("vision cap: \(AppleIntelligenceModel().supports(.vision))")

    var visionOptions = KilnRunOptions.default
    visionOptions.attachments = [.image(url: url, label: "image")]
    await fire("Describe this image in one sentence.", options: visionOptions)

case "pcc":
    // WARNING: this will terminate the process unless the managed entitlement
    // `com.apple.developer.private-cloud-compute` has been granted by Apple. The
    // framework calls `fatalError` in ErrorConversion.swift rather than throwing, so it
    // cannot be caught, guarded, or degraded around — the only safe pre-check is not
    // calling it. Kept in its own command so it cannot take the rest of the probe down.
    //
    // Note what this costs: `isAvailable` returns true and `capabilities` advertises
    // reasoning, both before any entitlement exists. Availability and capability both
    // say yes and the call still kills the process.
    heading("Private Cloud Compute — WILL TRAP without the managed entitlement")
    let pcc = PrivateCloudComputeLanguageModel()
    print("isAvailable:  \(pcc.isAvailable)")
    print("reasoning:    \(pcc.capabilities.contains(.reasoning))")
    print("\nattempting a session — expect a fatalError if unentitled...\n")
    fflush(stdout)
    do {
        let session = LanguageModelSession(model: pcc)
        let r = try await session.respond(
            to: "Explain what a kiln does, in two sentences.",
            contextOptions: ContextOptions(reasoningLevel: .deep))
        print("succeeded — reasoning IS reachable")
        print("out.total=\(r.usage.output.totalTokenCount) reasoning=\(r.usage.output.reasoningTokenCount)")
    } catch let error as LanguageModelError {
        print("threw (did not trap) → maps to .\(AppleIntelligenceModel.issue(for: error))")
    } catch {
        print("threw \(type(of: error)): \(error)")
    }

default:
    print("""
    usage: KilnProbe <command> [prompt]

      capabilities   what this machine advertises, on-device and via PCC
      run [prompt]   fire a prompt with default options
      tool [prompt]  fire with the cone tool offered and calling allowed
      offered        fire with the tool offered but calling disallowed
      reasoning      request a reasoning level (fails on-device by design)
      errors         provoke real failures and check they survive the mapper
      vision [path]  attach an image to the prompt (defaults to the app icon)
      pcc            Private Cloud Compute — TRAPS without Apple's managed entitlement
    """)
}

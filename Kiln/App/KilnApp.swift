import SwiftUI

@main
struct KilnApp: App {
    // Services are owned here and injected downward (ADR-001). @State on the App is
    // what keeps the registry alive for the process lifetime without a singleton.
    @State private var registry = ModelRegistry()

    var body: some Scene {
        WindowGroup {
            HelloKilnView()
                .environment(registry)
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 560)
        #endif
    }
}

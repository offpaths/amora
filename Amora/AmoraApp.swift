import PostHog
import SwiftUI

@main
struct AmoraApp: App {
    init() {
        let config = PostHogConfig(
            apiKey: "phc_x2dxDBocYg96HNCHysDTxbMuGYdKW4NM7TonMDqcwSa3",
            host: "https://eu.i.posthog.com"
        )
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

import PostHog
import SwiftUI

@MainActor
protocol AnalyticsTracking {
    func capture(_ event: String, properties: [String: Any])
}

extension AnalyticsTracking {
    func capture(_ event: String) {
        capture(event, properties: [:])
    }
}

@MainActor
struct PostHogAnalytics: AnalyticsTracking {
    static let shared = PostHogAnalytics()

    func capture(_ event: String, properties: [String: Any]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
}

@main
struct AmoraApp: App {
    init() {
        let config = PostHogConfig(
            projectToken: "phc_x2dxDBocYg96HNCHysDTxbMuGYdKW4NM7TonMDqcwSa3",
            host: "https://eu.i.posthog.com"
        )
        config.errorTrackingConfig.autoCapture = false
        config.personProfiles = .never
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

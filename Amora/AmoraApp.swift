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
    typealias CaptureEvent = (String, [String: Any]) -> Void

    static let shared = PostHogAnalytics()

    private let captureEvent: CaptureEvent

    init(
        captureEvent: @escaping CaptureEvent = { event, properties in
            PostHogSDK.shared.capture(event, properties: properties)
        }
    ) {
        self.captureEvent = captureEvent
    }

    func capture(_ event: String, properties: [String: Any]) {
        var privacyLimitedProperties = properties
        privacyLimitedProperties["$geoip_disable"] = true
        captureEvent(event, privacyLimitedProperties)
    }
}

@main
struct AmoraApp: App {
    init() {
        let config = PostHogConfig(
            projectToken: "phc_x2dxDBocYg96HNCHysDTxbMuGYdKW4NM7TonMDqcwSa3",
            host: "https://eu.i.posthog.com"
        )
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.errorTrackingConfig.autoCapture = false
        config.personProfiles = .never
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

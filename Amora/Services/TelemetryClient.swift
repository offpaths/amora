import Foundation

struct TelemetryClient: Sendable {
    static let analyticsEnabledKey = "isAnalyticsEnabled"

    var baseURL: URL
    var session: URLSession = .shared
    var isEnabled: @Sendable () -> Bool = {
        UserDefaults.standard.object(forKey: TelemetryClient.analyticsEnabledKey) as? Bool ?? true
    }

    static let live = TelemetryClient(baseURL: AppConfig.backendBaseURL)
    static let disabled = TelemetryClient(baseURL: AppConfig.backendBaseURL, isEnabled: { false })

    func track(_ event: TelemetryEvent) async {
        guard isEnabled() else { return }

        var request = URLRequest(url: baseURL.appendingPathComponent("telemetry"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(event.payload)
            _ = try await session.data(for: request)
        } catch {
            return
        }
    }
}

enum TelemetryEvent: Sendable {
    case aiDisclosureAccepted
    case intakeStepViewed(Int)
    case planningAreaSelected(source: String, countryCode: String)
    case previewGenerationStarted(countryCode: String, budgetAmount: Int, vibe: DateVibe, durationMinutes: Int, noDrinking: Bool, hasActiveSubscription: Bool)
    case previewGenerationSucceeded(countryCode: String, budgetAmount: Int, vibe: DateVibe, durationMinutes: Int, noDrinking: Bool, hasActiveSubscription: Bool)
    case previewGenerationFailed(countryCode: String, reason: String)
    case regenerateStarted(hasActiveSubscription: Bool)
    case regenerateSucceeded(hasActiveSubscription: Bool)
    case regenerateFailed(hasActiveSubscription: Bool)
    case paywallViewed(hasActiveSubscription: Bool)
    case purchaseStarted(productType: String)
    case purchaseCompleted(productType: String, success: Bool)
    case planUnlocked(productType: String)
    case subscriptionStatusChanged(isActive: Bool)
    case newDateStarted

    var payload: TelemetryPayload {
        switch self {
        case .aiDisclosureAccepted:
            return TelemetryPayload(eventName: "ai_disclosure_accepted")
        case .intakeStepViewed(let step):
            return TelemetryPayload(eventName: "intake_step_viewed", properties: ["step": .int(step)])
        case .planningAreaSelected(let source, let countryCode):
            return TelemetryPayload(
                eventName: "planning_area_selected",
                properties: ["source": .string(source), "countryCode": .string(countryCode)]
            )
        case .previewGenerationStarted(let countryCode, let budgetAmount, let vibe, let durationMinutes, let noDrinking, let hasActiveSubscription):
            return TelemetryPayload(
                eventName: "preview_generation_started",
                properties: planProperties(countryCode: countryCode, budgetAmount: budgetAmount, vibe: vibe, durationMinutes: durationMinutes, noDrinking: noDrinking, hasActiveSubscription: hasActiveSubscription)
            )
        case .previewGenerationSucceeded(let countryCode, let budgetAmount, let vibe, let durationMinutes, let noDrinking, let hasActiveSubscription):
            return TelemetryPayload(
                eventName: "preview_generation_succeeded",
                properties: planProperties(countryCode: countryCode, budgetAmount: budgetAmount, vibe: vibe, durationMinutes: durationMinutes, noDrinking: noDrinking, hasActiveSubscription: hasActiveSubscription)
            )
        case .previewGenerationFailed(let countryCode, let reason):
            return TelemetryPayload(
                eventName: "preview_generation_failed",
                properties: ["countryCode": .string(countryCode), "reason": .string(reason)]
            )
        case .regenerateStarted(let hasActiveSubscription):
            return TelemetryPayload(eventName: "regenerate_started", properties: ["hasActiveSubscription": .bool(hasActiveSubscription)])
        case .regenerateSucceeded(let hasActiveSubscription):
            return TelemetryPayload(eventName: "regenerate_succeeded", properties: ["hasActiveSubscription": .bool(hasActiveSubscription)])
        case .regenerateFailed(let hasActiveSubscription):
            return TelemetryPayload(eventName: "regenerate_failed", properties: ["hasActiveSubscription": .bool(hasActiveSubscription)])
        case .paywallViewed(let hasActiveSubscription):
            return TelemetryPayload(eventName: "paywall_viewed", properties: ["hasActiveSubscription": .bool(hasActiveSubscription)])
        case .purchaseStarted(let productType):
            return TelemetryPayload(eventName: "purchase_started", properties: ["productType": .string(productType)])
        case .purchaseCompleted(let productType, let success):
            return TelemetryPayload(
                eventName: "purchase_completed",
                properties: ["productType": .string(productType), "success": .bool(success)]
            )
        case .planUnlocked(let productType):
            return TelemetryPayload(eventName: "plan_unlocked", properties: ["productType": .string(productType)])
        case .subscriptionStatusChanged(let isActive):
            return TelemetryPayload(eventName: "subscription_status_changed", properties: ["isActive": .bool(isActive)])
        case .newDateStarted:
            return TelemetryPayload(eventName: "new_date_started")
        }
    }

    private func planProperties(
        countryCode: String,
        budgetAmount: Int,
        vibe: DateVibe,
        durationMinutes: Int,
        noDrinking: Bool,
        hasActiveSubscription: Bool
    ) -> [String: TelemetryValue] {
        [
            "countryCode": .string(countryCode),
            "budgetAmount": .int(budgetAmount),
            "vibe": .string(vibe.rawValue),
            "durationMinutes": .int(durationMinutes),
            "noDrinking": .bool(noDrinking),
            "hasActiveSubscription": .bool(hasActiveSubscription)
        ]
    }
}

struct TelemetryPayload: Encodable, Sendable {
    let eventName: String
    let occurredAt: String
    let properties: [String: TelemetryValue]

    init(eventName: String, properties: [String: TelemetryValue] = [:]) {
        self.eventName = eventName
        occurredAt = ISO8601DateFormatter().string(from: Date())
        self.properties = properties
    }
}

enum TelemetryValue: Encodable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

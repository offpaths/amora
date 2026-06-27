import Combine
import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var locationLabel = ""
    @Published var planningAreaCountryCode = ""
    @Published var budgetAmount = 100
    @Published var vibe: DateVibe = .cozy
    @Published var noDrinking = true
    @Published var durationMinutes = 120
    @Published var partnerLikes = ""
    @Published var currentPlan: DatePlanResponse?
    @Published var isUnlocked = false
    @Published var hasActiveSubscription = false
    @Published var hasAcceptedAIDisclosure: Bool {
        didSet {
            UserDefaults.standard.set(hasAcceptedAIDisclosure, forKey: Self.aiDisclosureConsentKey)
        }
    }
    @Published var remainingUnlockedRegenerates = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private static let aiDisclosureConsentKey = "hasAcceptedAIDisclosure"
    private let generate: (GeneratePlanRequest) async throws -> DatePlanResponse
    private let telemetry: TelemetryClient
    private var regenerationAttempt = 0

    init(
        generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
            try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
        },
        telemetry: TelemetryClient = .disabled
    ) {
        hasAcceptedAIDisclosure = UserDefaults.standard.bool(forKey: Self.aiDisclosureConsentKey)
        self.generate = generate
        self.telemetry = telemetry
    }

    var canRegenerateUnlockedPlan: Bool {
        isUnlocked && (hasActiveSubscription || remainingUnlockedRegenerates > 0)
    }

    var budgetOptions: [BudgetOption] {
        BudgetCatalog.options(for: planningAreaCountryCode)
    }

    var refinePlanButtonTitle: String {
        if hasActiveSubscription {
            return "Refine This Plan (Unlimited)"
        }
        return "Refine This Plan (\(remainingUnlockedRegenerates))"
    }

    var isRefinePlanDisabled: Bool {
        !canRegenerateUnlockedPlan
    }

    var isCreatePlanDisabled: Bool {
        !hasAcceptedAIDisclosure
    }

    func generatePreview() async {
        guard hasAcceptedAIDisclosure else {
            errorMessage = "Accept the AI disclosure to create your plan."
            record(.previewGenerationFailed(countryCode: planningAreaCountryCode, reason: "ai_disclosure_required"))
            return
        }

        guard !planningAreaCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Choose a suggested area or enter a more specific city and country."
            record(.previewGenerationFailed(countryCode: planningAreaCountryCode, reason: "country_code_required"))
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            record(makePreviewEvent(started: true))
            currentPlan = try await generate(makeRequest())
            isUnlocked = hasActiveSubscription
            remainingUnlockedRegenerates = hasActiveSubscription ? remainingUnlockedRegenerates : 0
            record(makePreviewEvent(started: false))
        } catch {
            errorMessage = "We could not generate a plan. Try again."
            record(.previewGenerationFailed(countryCode: planningAreaCountryCode, reason: "generation_failed"))
        }
    }

    func unlockCurrentPlan() {
        guard currentPlan != nil else { return }
        isUnlocked = true
        remainingUnlockedRegenerates = 1
    }

    func completePurchase(success: Bool) {
        record(.purchaseCompleted(productType: "one_plan", success: success))
        if success {
            unlockCurrentPlan()
            record(.planUnlocked(productType: "one_plan"))
        }
    }

    func completeSubscriptionPurchase(success: Bool) {
        record(.purchaseCompleted(productType: "subscription", success: success))
        guard success else { return }
        hasActiveSubscription = true
        unlockCurrentPlan()
        record(.planUnlocked(productType: "subscription"))
    }

    func setSubscriptionActive(_ isActive: Bool) {
        hasActiveSubscription = isActive
        if isActive, currentPlan != nil {
            isUnlocked = true
        }
        record(.subscriptionStatusChanged(isActive: isActive))
    }

    func startNewDate() {
        currentPlan = nil
        isUnlocked = false
        remainingUnlockedRegenerates = 0
        regenerationAttempt = 0
        errorMessage = nil
        record(.newDateStarted)
    }

    func setPlanningArea(label: String, countryCode: String, source: String = "typed") {
        locationLabel = label
        planningAreaCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !budgetOptions.contains(where: { $0.amount == budgetAmount }) {
            budgetAmount = budgetOptions.min { lhs, rhs in
                abs(lhs.amount - budgetAmount) < abs(rhs.amount - budgetAmount)
            }?.amount ?? budgetAmount
        }
        if !planningAreaCountryCode.isEmpty {
            record(.planningAreaSelected(source: source, countryCode: planningAreaCountryCode))
        }
    }

    func regenerateUnlockedPlan() async {
        guard canRegenerateUnlockedPlan else { return }
        record(.regenerateStarted(hasActiveSubscription: hasActiveSubscription))
        if !hasActiveSubscription {
            remainingUnlockedRegenerates -= 1
        }
        regenerationAttempt += 1
        await generatePreview()
        isUnlocked = true
        if currentPlan == nil || errorMessage != nil {
            record(.regenerateFailed(hasActiveSubscription: hasActiveSubscription))
        } else {
            record(.regenerateSucceeded(hasActiveSubscription: hasActiveSubscription))
        }
    }

    func acceptAIDisclosure() {
        hasAcceptedAIDisclosure = true
        record(.aiDisclosureAccepted)
    }

    func recordIntakeStepViewed(_ step: Int) {
        record(.intakeStepViewed(step))
    }

    func recordPaywallViewed() {
        record(.paywallViewed(hasActiveSubscription: hasActiveSubscription))
    }

    func recordPurchaseStarted(productType: String) {
        record(.purchaseStarted(productType: productType))
    }

    private func makeRequest() -> GeneratePlanRequest {
        GeneratePlanRequest(
            locationLabel: locationLabel,
            countryCode: planningAreaCountryCode,
            budgetAmount: budgetAmount,
            vibe: vibe,
            noDrinking: noDrinking,
            durationMinutes: durationMinutes,
            partnerLikes: partnerLikes,
            regenerationAttempt: regenerationAttempt
        )
    }

    private func makePreviewEvent(started: Bool) -> TelemetryEvent {
        if started {
            return .previewGenerationStarted(
                countryCode: planningAreaCountryCode,
                budgetAmount: budgetAmount,
                vibe: vibe,
                durationMinutes: durationMinutes,
                noDrinking: noDrinking,
                hasActiveSubscription: hasActiveSubscription
            )
        }

        return .previewGenerationSucceeded(
            countryCode: planningAreaCountryCode,
            budgetAmount: budgetAmount,
            vibe: vibe,
            durationMinutes: durationMinutes,
            noDrinking: noDrinking,
            hasActiveSubscription: hasActiveSubscription
        )
    }

    private func record(_ event: TelemetryEvent) {
        Task {
            await telemetry.track(event)
        }
    }
}

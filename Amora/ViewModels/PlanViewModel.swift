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
    @Published var hasAcceptedAIDisclosure = false
    @Published var remainingUnlockedRegenerates = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let generate: (GeneratePlanRequest) async throws -> DatePlanResponse
    private var regenerationAttempt = 0

    init(generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
        try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
    }) {
        self.generate = generate
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
            return
        }

        guard !planningAreaCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Choose a suggested area or enter a more specific city and country."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentPlan = try await generate(makeRequest())
            isUnlocked = hasActiveSubscription
            remainingUnlockedRegenerates = hasActiveSubscription ? remainingUnlockedRegenerates : 0
        } catch {
            errorMessage = "We could not generate a plan. Try again."
        }
    }

    func unlockCurrentPlan() {
        guard currentPlan != nil else { return }
        isUnlocked = true
        remainingUnlockedRegenerates = 1
    }

    func completePurchase(success: Bool) {
        if success {
            unlockCurrentPlan()
        }
    }

    func completeSubscriptionPurchase(success: Bool) {
        guard success else { return }
        hasActiveSubscription = true
        unlockCurrentPlan()
    }

    func setSubscriptionActive(_ isActive: Bool) {
        hasActiveSubscription = isActive
        if isActive, currentPlan != nil {
            isUnlocked = true
        }
    }

    func startNewDate() {
        currentPlan = nil
        isUnlocked = false
        remainingUnlockedRegenerates = 0
        regenerationAttempt = 0
        errorMessage = nil
    }

    func setPlanningArea(label: String, countryCode: String) {
        locationLabel = label
        planningAreaCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !budgetOptions.contains(where: { $0.amount == budgetAmount }) {
            budgetAmount = budgetOptions.min { lhs, rhs in
                abs(lhs.amount - budgetAmount) < abs(rhs.amount - budgetAmount)
            }?.amount ?? budgetAmount
        }
    }

    func regenerateUnlockedPlan() async {
        guard canRegenerateUnlockedPlan else { return }
        if !hasActiveSubscription {
            remainingUnlockedRegenerates -= 1
        }
        regenerationAttempt += 1
        await generatePreview()
        isUnlocked = true
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
}

import Combine
import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var locationLabel = ""
    @Published var planningAreaCountryCode = ""
    @Published var budgetAmount = 100
    @Published var vibe: DateVibe = .cozy
    @Published var noDrinking = false
    @Published var durationMinutes = 120
    @Published var partnerLikes = ""
    @Published var currentPlan: DatePlanResponse?
    @Published var isUnlocked = false
    @Published private(set) var savedUnlockedPlan: SavedUnlockedPlan?
    @Published private(set) var isShowingSavedUnlockedPlan = false
    @Published var hasActiveSubscription = false
    @Published var hasAcceptedAIDisclosure: Bool {
        didSet {
            UserDefaults.standard.set(hasAcceptedAIDisclosure, forKey: Self.aiDisclosureConsentKey)
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    private static let aiDisclosureConsentKey = "hasAcceptedAIDisclosure"
    private let generate: (GeneratePlanRequest) async throws -> DatePlanResponse
    private let unlockedPlanStore: UnlockedPlanStore
    private var regenerationAttempt = 0

    init(
        generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
            try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
        },
        unlockedPlanStore: UnlockedPlanStore = UnlockedPlanStore()
    ) {
        hasAcceptedAIDisclosure = UserDefaults.standard.bool(forKey: Self.aiDisclosureConsentKey)
        self.generate = generate
        self.unlockedPlanStore = unlockedPlanStore
        savedUnlockedPlan = unlockedPlanStore.load()
    }

    var canRegenerateUnlockedPlan: Bool {
        isUnlocked && hasActiveSubscription
    }

    var budgetOptions: [BudgetOption] {
        BudgetCatalog.options(for: planningAreaCountryCode)
    }

    var hasSavedUnlockedPlan: Bool {
        savedUnlockedPlan != nil
    }

    var shouldShowRefinePlanAction: Bool {
        canRegenerateUnlockedPlan && !isShowingSavedUnlockedPlan
    }

    var shouldShowPlanNewDateAction: Bool {
        !isShowingSavedUnlockedPlan
    }

    var refinePlanButtonTitle: String {
        if hasActiveSubscription {
            return "Refine This Plan (Unlimited)"
        }
        return "Refine This Plan"
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
            isShowingSavedUnlockedPlan = false
            if hasActiveSubscription, let currentPlan {
                saveLatestUnlockedPlan(currentPlan)
            }
        } catch {
            errorMessage = "We could not generate a plan. Try again."
        }
    }

    func unlockCurrentPlan() {
        guard let currentPlan else { return }
        isUnlocked = true
        isShowingSavedUnlockedPlan = false
        saveLatestUnlockedPlan(currentPlan)
    }

    func completeSubscriptionPurchase(success: Bool) {
        guard success else { return }
        hasActiveSubscription = true
        unlockCurrentPlan()
    }

    func setSubscriptionActive(_ isActive: Bool) {
        hasActiveSubscription = isActive
        if isActive, let currentPlan {
            isUnlocked = true
            saveLatestUnlockedPlan(currentPlan)
        }
    }

    func startNewDate() {
        currentPlan = nil
        isUnlocked = false
        isShowingSavedUnlockedPlan = false
        regenerationAttempt = 0
        errorMessage = nil
    }

    func returnToSavedUnlockedPlan() {
        guard let savedUnlockedPlan else { return }
        currentPlan = savedUnlockedPlan.plan
        isUnlocked = true
        isShowingSavedUnlockedPlan = true
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
        regenerationAttempt += 1
        await generatePreview()
        isUnlocked = true
    }

    func acceptAIDisclosure() {
        hasAcceptedAIDisclosure = true
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

    private func saveLatestUnlockedPlan(_ plan: DatePlanResponse) {
        unlockedPlanStore.save(plan: plan)
        savedUnlockedPlan = unlockedPlanStore.load()
    }
}

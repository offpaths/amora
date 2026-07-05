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
    private let unlock: (String, String) async throws -> UnlockedPlanResponse
    private let unlockedPlanStore: UnlockedPlanStore
    private var regenerationAttempt = 0
    private var activeSignedTransactionInfo: String?

    init(
        generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
            try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
        },
        unlock: @escaping (String, String) async throws -> UnlockedPlanResponse = {
            try await DatePlanClient(baseURL: AppConfig.backendBaseURL).unlockPlan(
                planToken: $0,
                signedTransactionInfo: $1
            )
        },
        unlockedPlanStore: UnlockedPlanStore = UnlockedPlanStore()
    ) {
        hasAcceptedAIDisclosure = UserDefaults.standard.bool(forKey: Self.aiDisclosureConsentKey)
        self.generate = generate
        self.unlock = unlock
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
            isUnlocked = false
            isShowingSavedUnlockedPlan = false
            if hasActiveSubscription, let activeSignedTransactionInfo {
                await unlockCurrentPlan(signedTransactionInfo: activeSignedTransactionInfo)
            }
        } catch {
            errorMessage = "We could not generate a plan. Try again."
        }
    }

    func unlockCurrentPlan(signedTransactionInfo: String?) async {
        guard var currentPlan else { return }
        guard let planToken = currentPlan.planToken, !planToken.isEmpty else {
            errorMessage = "We could not unlock this plan. Create a fresh preview and try again."
            return
        }
        guard let signedTransactionInfo, !signedTransactionInfo.isEmpty else {
            errorMessage = "We could not verify your subscription. Try restoring your purchase."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let unlockedPlan = try await unlock(planToken, signedTransactionInfo)
            currentPlan.id = unlockedPlan.id
            currentPlan.lockedPlan = unlockedPlan.lockedPlan
            self.currentPlan = currentPlan
            isUnlocked = true
            isShowingSavedUnlockedPlan = false
            activeSignedTransactionInfo = signedTransactionInfo
            saveLatestUnlockedPlan(currentPlan)
        } catch {
            isUnlocked = false
            errorMessage = "We could not unlock this plan. Try restoring your purchase or try again."
        }
    }

    func completeSubscriptionPurchase(success: Bool, signedTransactionInfo: String?) async {
        guard success else { return }
        hasActiveSubscription = true
        activeSignedTransactionInfo = signedTransactionInfo
        await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
    }

    func setSubscriptionActive(_ isActive: Bool, signedTransactionInfo: String? = nil) async {
        hasActiveSubscription = isActive
        if isActive {
            activeSignedTransactionInfo = signedTransactionInfo ?? activeSignedTransactionInfo
            if !isUnlocked, currentPlan != nil, let activeSignedTransactionInfo {
                await unlockCurrentPlan(signedTransactionInfo: activeSignedTransactionInfo)
            }
        } else {
            activeSignedTransactionInfo = nil
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
        let signedTransactionInfo = activeSignedTransactionInfo
        let previousPlanID = currentPlan?.id
        regenerationAttempt += 1
        await generatePreview()
        if currentPlan?.id != previousPlanID, !isUnlocked {
            await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
        }
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

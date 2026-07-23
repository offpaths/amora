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
    private let analytics: any AnalyticsTracking
    private let maximumRegenerationAttempt = 20
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
        unlockedPlanStore: UnlockedPlanStore = UnlockedPlanStore(),
        analytics: any AnalyticsTracking = PostHogAnalytics.shared
    ) {
        hasAcceptedAIDisclosure = UserDefaults.standard.bool(forKey: Self.aiDisclosureConsentKey)
        self.generate = generate
        self.unlock = unlock
        self.unlockedPlanStore = unlockedPlanStore
        self.analytics = analytics
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

        if hasActiveSubscription && activeSignedTransactionInfo == nil {
            errorMessage = "We could not verify your subscription. Try restoring your purchase."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentPlan = try await generate(makeRequest())
            isUnlocked = hasActiveSubscription && currentPlan?.lockedPlan != nil
            isShowingSavedUnlockedPlan = false
            if isUnlocked, let currentPlan {
                saveLatestUnlockedPlan(currentPlan)
            }
            analytics.capture("date_plan_generated", properties: [
                "vibe": vibe.rawValue,
                "budget_amount": budgetAmount,
                "duration_minutes": durationMinutes,
                "no_drinking": noDrinking,
                "has_partner_likes": !partnerLikes.isEmpty,
                "stop_count": currentPlan?.preview.stops.count ?? 0,
                "is_unlocked": isUnlocked,
                "regeneration_attempt": regenerationAttempt
            ])
        } catch let error as DatePlanClientError {
            if error.isSubscriptionRequiredGenerationFailure {
                hasActiveSubscription = false
                activeSignedTransactionInfo = nil
                do {
                    currentPlan = try await generate(makeRequest())
                    isUnlocked = false
                    isShowingSavedUnlockedPlan = false
                    errorMessage = nil
                    analytics.capture("date_plan_generated", properties: [
                        "vibe": vibe.rawValue,
                        "budget_amount": budgetAmount,
                        "duration_minutes": durationMinutes,
                        "no_drinking": noDrinking,
                        "has_partner_likes": !partnerLikes.isEmpty,
                        "stop_count": currentPlan?.preview.stops.count ?? 0,
                        "is_unlocked": false,
                        "regeneration_attempt": regenerationAttempt
                    ])
                } catch {
                    errorMessage = generationErrorMessage(for: error)
                    analytics.capture("date_plan_generation_failed", properties: ["error_type": generationErrorType(for: error)])
                }
            } else {
                errorMessage = generationErrorMessage(for: error)
                analytics.capture("date_plan_generation_failed", properties: ["error_type": generationErrorType(for: error)])
            }
        } catch {
            errorMessage = generationErrorMessage(for: error)
            analytics.capture("date_plan_generation_failed", properties: ["error_type": generationErrorType(for: error)])
        }
    }

    @discardableResult
    func unlockCurrentPlan(signedTransactionInfo: String?) async -> Bool {
        guard var currentPlan else { return false }
        guard let planToken = currentPlan.planToken, !planToken.isEmpty else {
            errorMessage = "We could not unlock this plan. Create a fresh preview and try again."
            return false
        }
        guard let signedTransactionInfo, !signedTransactionInfo.isEmpty else {
            errorMessage = "We could not verify your subscription. Try restoring your purchase."
            return false
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
            analytics.capture("plan_unlocked")
            return true
        } catch {
            isUnlocked = false
            errorMessage = "We could not unlock this plan. Try restoring your purchase or try again."
            return false
        }
    }

    @discardableResult
    func completeSubscriptionPurchase(success: Bool, signedTransactionInfo: String?) async -> Bool {
        guard success else { return false }
        hasActiveSubscription = true
        activeSignedTransactionInfo = signedTransactionInfo
        return await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
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
        analytics.capture("new_date_started")
    }

    func returnToSavedUnlockedPlan() {
        guard let savedUnlockedPlan else { return }
        currentPlan = savedUnlockedPlan.plan
        isUnlocked = true
        isShowingSavedUnlockedPlan = true
        errorMessage = nil
        analytics.capture("previous_plan_restored")
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
        incrementRegenerationAttempt()
        analytics.capture("unlocked_plan_regenerated", properties: ["regeneration_attempt": regenerationAttempt])
        await generatePreview()
        if currentPlan?.id != previousPlanID, !isUnlocked {
            await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
        }
    }

    func regeneratePreview() async {
        incrementRegenerationAttempt()
        analytics.capture("plan_preview_regenerated", properties: ["regeneration_attempt": regenerationAttempt])
        await generatePreview()
    }

    func acceptAIDisclosure() {
        hasAcceptedAIDisclosure = true
        analytics.capture("ai_consent_accepted")
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
            regenerationAttempt: regenerationAttempt,
            signedTransactionInfo: hasActiveSubscription ? activeSignedTransactionInfo : nil
        )
    }

    private func saveLatestUnlockedPlan(_ plan: DatePlanResponse) {
        unlockedPlanStore.save(plan: plan)
        savedUnlockedPlan = unlockedPlanStore.load()
    }

    private func incrementRegenerationAttempt() {
        regenerationAttempt = min(regenerationAttempt + 1, maximumRegenerationAttempt)
    }

    private func generationErrorMessage(for error: Error) -> String {
        if case .generationFailed(let statusCode, _) = error as? DatePlanClientError {
            switch statusCode {
            case 429:
                return "Too many plans were requested from this connection. Wait a few minutes, then try again."
            case 400:
                return "Check your planning area and preferences, then try again."
            default:
                break
            }
        }

        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return "You appear to be offline. Reconnect, then try creating your plan again."
        }

        return "We could not create your plan. Try again in a moment."
    }

    private func generationErrorType(for error: Error) -> String {
        if case .generationFailed(let statusCode, _) = error as? DatePlanClientError {
            switch statusCode {
            case 429: return "rate_limited"
            case 400: return "bad_request"
            default: return "api_error"
            }
        }
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return "offline"
        }
        return "unknown"
    }
}

private extension DatePlanClientError {
    var isSubscriptionRequiredGenerationFailure: Bool {
        if case .generationFailed(let statusCode, let body) = self {
            return statusCode == 403 && body.contains("subscription_required")
        }
        return false
    }
}

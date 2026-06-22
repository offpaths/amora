import Combine
import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var locationLabel = ""
    @Published var budgetTier: BudgetTier = .medium
    @Published var vibe: DateVibe = .cozy
    @Published var noDrinking = true
    @Published var durationMinutes = 120
    @Published var partnerLikes = ""
    @Published var currentPlan: DatePlanResponse?
    @Published var isUnlocked = false
    @Published var remainingUnlockedRegenerates = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let generate: (GeneratePlanRequest) async throws -> DatePlanResponse

    init(generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
        try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
    }) {
        self.generate = generate
    }

    var canRegenerateUnlockedPlan: Bool {
        isUnlocked && remainingUnlockedRegenerates > 0
    }

    func generatePreview() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentPlan = try await generate(makeRequest())
            isUnlocked = false
            remainingUnlockedRegenerates = 0
        } catch {
            errorMessage = "We could not generate a plan. Try again."
        }
    }

    func unlockCurrentPlan() {
        guard currentPlan != nil else { return }
        isUnlocked = true
        remainingUnlockedRegenerates = 1
    }

    func regenerateUnlockedPlan() async {
        guard canRegenerateUnlockedPlan else { return }
        remainingUnlockedRegenerates -= 1
        await generatePreview()
        isUnlocked = true
    }

    private func makeRequest() -> GeneratePlanRequest {
        GeneratePlanRequest(
            locationLabel: locationLabel,
            budgetTier: budgetTier,
            vibe: vibe,
            noDrinking: noDrinking,
            durationMinutes: durationMinutes,
            partnerLikes: partnerLikes
        )
    }
}

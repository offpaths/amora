import XCTest
@testable import Amora

@MainActor
final class PlanViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hasAcceptedAIDisclosure")
        UserDefaults.standard.removeObject(forKey: TelemetryClient.analyticsEnabledKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hasAcceptedAIDisclosure")
        UserDefaults.standard.removeObject(forKey: TelemetryClient.analyticsEnabledKey)
        super.tearDown()
    }

    func testDefaultInputsMatchMVPDefaults() {
        let viewModel = PlanViewModel()

        XCTAssertEqual(viewModel.budgetAmount, 100)
        XCTAssertEqual(viewModel.vibe, .cozy)
        XCTAssertTrue(viewModel.noDrinking)
        XCTAssertEqual(viewModel.durationMinutes, 120)
        XCTAssertFalse(viewModel.hasAcceptedAIDisclosure)
        XCTAssertTrue(viewModel.isCreatePlanDisabled)
    }

    func testSetPlanningAreaKeepsBudgetValidForCountry() {
        let viewModel = PlanViewModel()
        viewModel.budgetAmount = 300

        viewModel.setPlanningArea(label: "Shoreditch, London", countryCode: "GB")

        XCTAssertEqual(viewModel.planningAreaCountryCode, "GB")
        XCTAssertEqual(viewModel.budgetAmount, 250)
    }

    func testGeneratePreviewStoresPlan() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_one")
        XCTAssertFalse(viewModel.isUnlocked)
    }

    func testUnlockCurrentPlanEnablesOneRegenerate() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()

        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
    }

    func testRegenerateUnlockedPlanConsumesOneRegenerate() async {
        var count = 0
        var requests: [GeneratePlanRequest] = []
        let viewModel = PlanViewModel(generate: { request in
            requests.append(request)
            count += 1
            return Self.samplePlan(id: "plan_\(count)")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertEqual(requests.map(\.regenerationAttempt), [0, 1])
        XCTAssertEqual(requests.map(\.countryCode), ["US", "US"])
        XCTAssertEqual(requests.map(\.budgetAmount), [100, 100])
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan (0)")
        XCTAssertTrue(viewModel.isRefinePlanDisabled)
    }

    func testUnlockedPlanShowsOneRefineBeforeUse() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()

        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan (1)")
        XCTAssertFalse(viewModel.isRefinePlanDisabled)
    }

    func testGeneratePreviewRequiresCountryCode() async {
        var didGenerate = false
        let viewModel = PlanViewModel(generate: { _ in
            didGenerate = true
            return Self.samplePlan(id: "plan_one")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertFalse(didGenerate)
        XCTAssertNil(viewModel.currentPlan)
        XCTAssertEqual(viewModel.errorMessage, "Choose a suggested area or enter a more specific city and country.")
    }

    func testGeneratePreviewRequiresAIDisclosureAcceptance() async {
        var didGenerate = false
        let viewModel = PlanViewModel(generate: { _ in
            didGenerate = true
            return Self.samplePlan(id: "plan_one")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"

        await viewModel.generatePreview()

        XCTAssertFalse(didGenerate)
        XCTAssertNil(viewModel.currentPlan)
        XCTAssertEqual(viewModel.errorMessage, "Accept the AI disclosure to create your plan.")
        XCTAssertTrue(viewModel.isCreatePlanDisabled)
    }

    func testAcceptingAIDisclosureEnablesCreatePlan() {
        let viewModel = PlanViewModel()

        viewModel.hasAcceptedAIDisclosure = true

        XCTAssertFalse(viewModel.isCreatePlanDisabled)
    }

    func testSubscriptionPurchaseUnlocksCurrentPlan() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.completeSubscriptionPurchase(success: true)

        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
    }

    func testSubscribedPreviewGeneratesUnlockedPlan() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.setSubscriptionActive(true)
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertTrue(viewModel.isUnlocked)
    }

    func testSubscribedRegenerateDoesNotConsumeOneTimeRegenerate() async {
        var count = 0
        let viewModel = PlanViewModel(generate: { _ in
            count += 1
            return Self.samplePlan(id: "plan_\(count)")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.completeSubscriptionPurchase(success: true)
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertEqual(viewModel.remainingUnlockedRegenerates, 1)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan (Unlimited)")
        XCTAssertFalse(viewModel.isRefinePlanDisabled)
    }

    func testStartNewDateClearsPlanButKeepsPreferences() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.partnerLikes = "bookstores and matcha"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()
        viewModel.startNewDate()

        XCTAssertNil(viewModel.currentPlan)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.locationLabel, "Williamsburg, Brooklyn")
        XCTAssertEqual(viewModel.planningAreaCountryCode, "US")
        XCTAssertEqual(viewModel.partnerLikes, "bookstores and matcha")
    }

    private static func samplePlan(id: String) -> DatePlanResponse {
        DatePlanResponse(
            id: id,
            preview: PlanPreview(
                title: "A cozy 2-hour plan near Williamsburg",
                summaryBadges: ["$$", "2 hours", "No bars"],
                stops: [
                    PreviewStop(
                        order: 1,
                        concept: "A cozy conversation starter",
                        vibe: "Calm and warm",
                        reason: "A low-pressure first stop gives the date room to settle in.",
                        personalizationSignal: "Matches her interest in quiet places."
                    ),
                    PreviewStop(
                        order: 2,
                        concept: "A personal activity",
                        vibe: "Playful and personal",
                        reason: "A shared activity creates easy momentum.",
                        personalizationSignal: "Connects to her creative side."
                    ),
                    PreviewStop(
                        order: 3,
                        concept: "A relaxed dessert finish",
                        vibe: "Sweet and unhurried",
                        reason: "A gentle final stop leaves space to linger.",
                        personalizationSignal: "Fits the requested cozy ending."
                    )
                ]
            ),
            lockedPlan: LockedPlan(
                totalEstimatedCost: "$60-$90",
                stops: [
                    LockedStop(order: 1, venueName: "A", address: "1 St", appleMapsQuery: "A 1 St", durationMinutes: 35, reason: "A thoughtful first stop.", estimatedCost: "$20-$30"),
                    LockedStop(order: 2, venueName: "B", address: "2 St", appleMapsQuery: "B 2 St", durationMinutes: 50, reason: "A thoughtful second stop.", estimatedCost: "$10-$25"),
                    LockedStop(order: 3, venueName: "C", address: "3 St", appleMapsQuery: "C 3 St", durationMinutes: 35, reason: "A thoughtful final stop.", estimatedCost: "$30-$35")
                ]
            )
        )
    }
}

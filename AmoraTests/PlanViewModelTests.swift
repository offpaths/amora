import XCTest
@testable import Amora

@MainActor
final class PlanViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hasAcceptedAIDisclosure")
        UserDefaults.standard.removeObject(forKey: "latestUnlockedPlan")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hasAcceptedAIDisclosure")
        UserDefaults.standard.removeObject(forKey: "latestUnlockedPlan")
        super.tearDown()
    }

    func testDefaultInputsMatchMVPDefaults() {
        let viewModel = PlanViewModel()

        XCTAssertEqual(viewModel.budgetAmount, 100)
        XCTAssertEqual(viewModel.vibe, .cozy)
        XCTAssertFalse(viewModel.noDrinking)
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

    func testRegeneratePreviewRequestsAMeaningfullyDifferentPlan() async {
        var requests: [GeneratePlanRequest] = []
        var count = 0
        let viewModel = PlanViewModel(generate: { request in
            requests.append(request)
            count += 1
            return Self.samplePlan(id: "plan_\(count)")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.regeneratePreview()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertEqual(requests.map(\.regenerationAttempt), [0, 1])
    }

    func testUnlockCurrentPlanUsesBackendProofWithoutSubscriptionRegenerateAccess() async {
        var unlockCalls: [(planToken: String, signedTransactionInfo: String)] = []
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { planToken, signedTransactionInfo in
                unlockCalls.append((planToken, signedTransactionInfo))
                return Self.sampleUnlockedResponse(id: "plan_one")
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.unlockCurrentPlan(signedTransactionInfo: "signed-proof")

        XCTAssertEqual(unlockCalls.map(\.planToken), ["token-plan_one"])
        XCTAssertEqual(unlockCalls.map(\.signedTransactionInfo), ["signed-proof"])
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
    }

    func testRegenerateUnlockedPlanRequiresActiveSubscription() async {
        var count = 0
        var requests: [GeneratePlanRequest] = []
        let viewModel = PlanViewModel(
            generate: { request in
                requests.append(request)
                count += 1
                return Self.samplePlan(id: "plan_\(count)")
            },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_1") }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.unlockCurrentPlan(signedTransactionInfo: "signed-proof")
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_1")
        XCTAssertEqual(requests.map(\.regenerationAttempt), [0])
        XCTAssertEqual(requests.map(\.countryCode), ["US"])
        XCTAssertEqual(requests.map(\.budgetAmount), [100])
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan")
        XCTAssertTrue(viewModel.isRefinePlanDisabled)
    }

    func testUnlockedPlanWithoutActiveSubscriptionCannotRefine() async {
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.unlockCurrentPlan(signedTransactionInfo: "signed-proof")

        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan")
        XCTAssertTrue(viewModel.isRefinePlanDisabled)
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

    func testGeneratePreviewExplainsRateLimitRecovery() async {
        let viewModel = PlanViewModel(generate: { _ in
            throw DatePlanClientError.generationFailed(statusCode: 429, body: #"{"error":"rate_limited"}"#)
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(viewModel.errorMessage, "Too many plans were requested from this connection. Wait a few minutes, then try again.")
    }

    func testAcceptingAIDisclosureEnablesCreatePlan() {
        let analytics = AnalyticsMock()
        let viewModel = PlanViewModel(analytics: analytics)

        viewModel.acceptAIDisclosure()

        XCTAssertFalse(viewModel.isCreatePlanDisabled)
        XCTAssertEqual(analytics.events.map(\.name), ["ai_consent_accepted"])
        XCTAssertTrue(analytics.events[0].properties.isEmpty)
    }

    func testGeneratingPreviewCapturesCompactFunnelEvent() async {
        let analytics = AnalyticsMock()
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            analytics: analytics
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(analytics.events.map(\.name), ["date_plan_generated"])
        XCTAssertNil(analytics.events[0].properties["location_label"])
        XCTAssertNil(analytics.events[0].properties["country_code"])
        XCTAssertNil(analytics.events[0].properties["partner_likes"])
    }

    func testGenerationFailureCapturesOnlyErrorCategory() async {
        let analytics = AnalyticsMock()
        let viewModel = PlanViewModel(
            generate: { _ in throw URLError(.notConnectedToInternet) },
            analytics: analytics
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(analytics.events.map(\.name), ["date_plan_generation_failed"])
        XCTAssertEqual(analytics.events[0].properties["error_type"] as? String, "offline")
    }

    func testSubscriptionPurchaseUnlocksCurrentPlanThroughBackend() async {
        var unlockCalls: [(planToken: String, signedTransactionInfo: String)] = []
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { planToken, signedTransactionInfo in
                unlockCalls.append((planToken, signedTransactionInfo))
                return Self.sampleUnlockedResponse(id: "plan_one")
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        let didUnlock = await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")

        XCTAssertTrue(didUnlock)
        XCTAssertEqual(unlockCalls.map(\.planToken), ["token-plan_one"])
        XCTAssertEqual(unlockCalls.map(\.signedTransactionInfo), ["signed-proof"])
        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.currentPlan?.lockedPlan?.totalEstimatedCost, "$60-$90")
    }

    func testSubscriptionPurchaseWithoutSignedProofDoesNotUnlockCurrentPlan() async {
        var didCallUnlockBackend = false
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in
                didCallUnlockBackend = true
                return Self.sampleUnlockedResponse(id: "plan_one")
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        let didUnlock = await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: nil)

        XCTAssertFalse(didUnlock)
        XCTAssertFalse(didCallUnlockBackend)
        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertEqual(viewModel.errorMessage, "We could not verify your subscription. Try restoring your purchase.")
    }

    func testSubscriptionPurchaseUnlockFailureDoesNotUnlockCurrentPlan() async {
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in throw DatePlanClientError.unlockFailed }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")

        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertEqual(viewModel.errorMessage, "We could not unlock this plan. Try restoring your purchase or try again.")
    }

    func testActiveSubscriptionWithoutProofDoesNotUnlockPreview() async {
        var didGenerate = false
        let viewModel = PlanViewModel(generate: { _ in
            didGenerate = true
            return Self.samplePlan(id: "plan_one")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        await viewModel.setSubscriptionActive(true)
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertFalse(didGenerate)
        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertNil(viewModel.currentPlan)
        XCTAssertEqual(viewModel.errorMessage, "We could not verify your subscription. Try restoring your purchase.")
    }

    func testActiveSubscriptionWithProofGeneratesUnlockedPlanDirectly() async {
        var generateRequests: [GeneratePlanRequest] = []
        var didCallUnlockBackend = false
        let viewModel = PlanViewModel(
            generate: { request in
                generateRequests.append(request)
                return Self.samplePlan(id: "plan_one")
            },
            unlock: { _, _ in
                didCallUnlockBackend = true
                return Self.sampleUnlockedResponse(id: "plan_one")
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        await viewModel.setSubscriptionActive(true, signedTransactionInfo: "signed-proof")
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(generateRequests.map(\.signedTransactionInfo), ["signed-proof"])
        XCTAssertFalse(didCallUnlockBackend)
        XCTAssertTrue(viewModel.hasActiveSubscription)
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertEqual(viewModel.currentPlan?.lockedPlan?.totalEstimatedCost, "$60-$90")
    }

    func testSubscriptionRequiredGenerationFailureRetriesAsNonSubscriberPreview() async {
        var generateRequests: [GeneratePlanRequest] = []
        let viewModel = PlanViewModel(
            generate: { request in
                generateRequests.append(request)
                if generateRequests.count == 1 {
                    throw DatePlanClientError.generationFailed(
                        statusCode: 403,
                        body: #"{"error":"subscription_required"}"#
                    )
                }
                return Self.samplePlan(id: "plan_one", includeLockedPlan: false)
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        await viewModel.setSubscriptionActive(true, signedTransactionInfo: "signed-proof")
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()

        XCTAssertEqual(generateRequests.map(\.signedTransactionInfo), ["signed-proof", nil])
        XCTAssertFalse(viewModel.hasActiveSubscription)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertEqual(viewModel.currentPlan?.id, "plan_one")
        XCTAssertNotNil(viewModel.currentPlan?.planToken)
        XCTAssertNil(viewModel.currentPlan?.lockedPlan)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRestoredSubscriptionUnlocksExistingPreviewThroughBackend() async {
        var unlockCalls: [(planToken: String, signedTransactionInfo: String)] = []
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { planToken, signedTransactionInfo in
                unlockCalls.append((planToken, signedTransactionInfo))
                return Self.sampleUnlockedResponse(id: "plan_one")
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.setSubscriptionActive(true, signedTransactionInfo: "signed-proof")

        XCTAssertEqual(unlockCalls.map(\.planToken), ["token-plan_one"])
        XCTAssertEqual(unlockCalls.map(\.signedTransactionInfo), ["signed-proof"])
        XCTAssertTrue(viewModel.isUnlocked)
    }

    func testSubscribedRegenerateKeepsUnlimitedRefineAccess() async {
        var count = 0
        var generateRequests: [GeneratePlanRequest] = []
        var unlockCalls: [(planToken: String, signedTransactionInfo: String)] = []
        let viewModel = PlanViewModel(
            generate: { request in
                generateRequests.append(request)
                count += 1
                return Self.samplePlan(id: "plan_\(count)")
            },
            unlock: { planToken, signedTransactionInfo in
                unlockCalls.append((planToken, signedTransactionInfo))
                return Self.sampleUnlockedResponse(id: planToken.replacingOccurrences(of: "token-", with: ""))
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertEqual(generateRequests.map(\.signedTransactionInfo), [nil, "signed-proof"])
        XCTAssertEqual(unlockCalls.map(\.planToken), ["token-plan_1"])
        XCTAssertEqual(unlockCalls.map(\.signedTransactionInfo), ["signed-proof"])
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.refinePlanButtonTitle, "Refine This Plan (Unlimited)")
        XCTAssertFalse(viewModel.isRefinePlanDisabled)
    }

    func testSubscribedRegenerateGenerationFailureDoesNotReunlockStalePlan() async {
        var count = 0
        var unlockCalls: [(planToken: String, signedTransactionInfo: String)] = []
        let viewModel = PlanViewModel(
            generate: { _ in
                count += 1
                if count == 2 {
                    throw DatePlanClientError.generationFailed(statusCode: 502, body: #"{"error":"generation_failed"}"#)
                }
                return Self.samplePlan(id: "plan_\(count)")
            },
            unlock: { planToken, signedTransactionInfo in
                unlockCalls.append((planToken, signedTransactionInfo))
                return Self.sampleUnlockedResponse(id: planToken.replacingOccurrences(of: "token-", with: ""))
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_1")
        XCTAssertEqual(unlockCalls.map(\.planToken), ["token-plan_1"])
        XCTAssertEqual(viewModel.errorMessage, "We could not create your plan. Try again in a moment.")
        XCTAssertTrue(viewModel.isUnlocked)
    }

    func testCurrentUnlockedSubscriberPlanShowsRefineAction() async {
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")

        XCTAssertTrue(viewModel.shouldShowRefinePlanAction)
    }

    func testCurrentUnlockedPlanShowsNewDateAction() async {
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")

        XCTAssertTrue(viewModel.shouldShowPlanNewDateAction)
    }

    func testInactiveSubscriptionCannotRegenerateUnlockedPlan() async {
        var count = 0
        let viewModel = PlanViewModel(
            generate: { _ in
                count += 1
                return Self.samplePlan(id: "plan_\(count)")
            },
            unlock: { planToken, _ in
                Self.sampleUnlockedResponse(id: planToken.replacingOccurrences(of: "token-", with: ""))
            }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")
        await viewModel.setSubscriptionActive(false)
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_1")
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
        XCTAssertTrue(viewModel.isRefinePlanDisabled)
    }

    func testSubscriptionPurchaseSavesLatestUnlockedPlanOnDevice() async {
        let store = makeUnlockedPlanStore()
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") },
            unlockedPlanStore: store
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")

        XCTAssertEqual(store.load()?.plan.id, "plan_one")
        XCTAssertEqual(viewModel.savedUnlockedPlan?.plan.id, "plan_one")
        XCTAssertTrue(viewModel.hasSavedUnlockedPlan)
    }

    func testViewModelLoadsSavedUnlockedPlanWithoutOpeningItImmediately() {
        let store = makeUnlockedPlanStore()
        store.save(plan: Self.samplePlan(id: "saved_plan"))

        let viewModel = PlanViewModel(unlockedPlanStore: store)

        XCTAssertNil(viewModel.currentPlan)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertEqual(viewModel.savedUnlockedPlan?.plan.id, "saved_plan")
        XCTAssertTrue(viewModel.hasSavedUnlockedPlan)
    }

    func testUnlockedPlanStoreIgnoresPreviewOnlyPlan() {
        let store = makeUnlockedPlanStore()
        var previewOnlyPlan = Self.samplePlan(id: "preview_plan")
        previewOnlyPlan.lockedPlan = nil

        store.save(plan: previewOnlyPlan)

        XCTAssertNil(store.load())
    }

    func testReturnToSavedUnlockedPlanShowsLatestPlan() {
        let store = makeUnlockedPlanStore()
        store.save(plan: Self.samplePlan(id: "saved_plan"))
        let viewModel = PlanViewModel(unlockedPlanStore: store)

        viewModel.returnToSavedUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "saved_plan")
        XCTAssertTrue(viewModel.isUnlocked)
    }

    func testRestoredSavedPlanDoesNotShowRefineAction() async {
        let store = makeUnlockedPlanStore()
        store.save(plan: Self.samplePlan(id: "saved_plan"))
        let viewModel = PlanViewModel(unlockedPlanStore: store)
        await viewModel.setSubscriptionActive(true)

        viewModel.returnToSavedUnlockedPlan()

        XCTAssertFalse(viewModel.shouldShowRefinePlanAction)
        XCTAssertFalse(viewModel.isRefinePlanDisabled)
    }

    func testRestoredSavedPlanDoesNotShowNewDateAction() {
        let store = makeUnlockedPlanStore()
        store.save(plan: Self.samplePlan(id: "saved_plan"))
        let viewModel = PlanViewModel(unlockedPlanStore: store)

        viewModel.returnToSavedUnlockedPlan()

        XCTAssertFalse(viewModel.shouldShowPlanNewDateAction)
    }

    func testStartingNewDateKeepsSavedUnlockedPlan() async {
        let store = makeUnlockedPlanStore()
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") },
            unlockedPlanStore: store
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "signed-proof")
        viewModel.startNewDate()

        XCTAssertNil(viewModel.currentPlan)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertEqual(store.load()?.plan.id, "plan_one")
        XCTAssertEqual(viewModel.savedUnlockedPlan?.plan.id, "plan_one")
    }

    func testStartNewDateClearsPlanButKeepsPreferences() async {
        let viewModel = PlanViewModel(
            generate: { _ in Self.samplePlan(id: "plan_one") },
            unlock: { _, _ in Self.sampleUnlockedResponse(id: "plan_one") }
        )
        viewModel.locationLabel = "Williamsburg, Brooklyn"
        viewModel.planningAreaCountryCode = "US"
        viewModel.partnerLikes = "bookstores and matcha"
        viewModel.hasAcceptedAIDisclosure = true

        await viewModel.generatePreview()
        await viewModel.unlockCurrentPlan(signedTransactionInfo: "signed-proof")
        viewModel.startNewDate()

        XCTAssertNil(viewModel.currentPlan)
        XCTAssertFalse(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
        XCTAssertEqual(viewModel.locationLabel, "Williamsburg, Brooklyn")
        XCTAssertEqual(viewModel.planningAreaCountryCode, "US")
        XCTAssertEqual(viewModel.partnerLikes, "bookstores and matcha")
    }

    private func makeUnlockedPlanStore() -> UnlockedPlanStore {
        let suiteName = "PlanViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return UnlockedPlanStore(defaults: defaults)
    }

    private static func samplePlan(id: String, includeLockedPlan: Bool = true) -> DatePlanResponse {
        DatePlanResponse(
            id: id,
            planToken: "token-\(id)",
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
            lockedPlan: includeLockedPlan ? LockedPlan(
                totalEstimatedCost: "$60-$90",
                stops: [
                    LockedStop(order: 1, venueName: "A", address: "1 St", appleMapsQuery: "A 1 St", durationMinutes: 35, reason: "A thoughtful first stop.", estimatedCost: "$20-$30"),
                    LockedStop(order: 2, venueName: "B", address: "2 St", appleMapsQuery: "B 2 St", durationMinutes: 50, reason: "A thoughtful second stop.", estimatedCost: "$10-$25"),
                    LockedStop(order: 3, venueName: "C", address: "3 St", appleMapsQuery: "C 3 St", durationMinutes: 35, reason: "A thoughtful final stop.", estimatedCost: "$30-$35")
                ]
            ) : nil
        )
    }

    private static func sampleUnlockedResponse(id: String) -> UnlockedPlanResponse {
        UnlockedPlanResponse(
            id: id,
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

@MainActor
private final class AnalyticsMock: AnalyticsTracking {
    struct Event {
        let name: String
        let properties: [String: Any]
    }

    private(set) var events: [Event] = []

    func capture(_ event: String, properties: [String: Any]) {
        events.append(Event(name: event, properties: properties))
    }
}

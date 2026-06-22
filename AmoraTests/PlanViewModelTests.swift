import XCTest
@testable import Amora

@MainActor
final class PlanViewModelTests: XCTestCase {
    func testDefaultInputsMatchMVPDefaults() {
        let viewModel = PlanViewModel()

        XCTAssertEqual(viewModel.budgetTier, .medium)
        XCTAssertEqual(viewModel.vibe, .cozy)
        XCTAssertTrue(viewModel.noDrinking)
        XCTAssertEqual(viewModel.durationMinutes, 120)
    }

    func testGeneratePreviewStoresPlan() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_one")
        XCTAssertFalse(viewModel.isUnlocked)
    }

    func testUnlockCurrentPlanEnablesOneRegenerate() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()

        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
    }

    func testRegenerateUnlockedPlanConsumesOneRegenerate() async {
        var count = 0
        let viewModel = PlanViewModel(generate: { _ in
            count += 1
            return Self.samplePlan(id: "plan_\(count)")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
    }

    private static func samplePlan(id: String) -> DatePlanResponse {
        DatePlanResponse(
            id: id,
            preview: PlanPreview(
                title: "A cozy 2-hour plan near Williamsburg",
                summaryBadges: ["$$", "2 hours", "No bars"],
                stops: [
                    PreviewStop(order: 1, concept: "A cozy conversation starter"),
                    PreviewStop(order: 2, concept: "A personal activity"),
                    PreviewStop(order: 3, concept: "A relaxed dessert finish")
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

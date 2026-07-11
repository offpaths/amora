import XCTest
@testable import Amora

final class PaywallViewTests: XCTestCase {
    func testContentRouteShowsPreviewWhenActiveSubscriberUnlockIsNotInProgress() {
        XCTAssertEqual(
            ContentRoute.resolve(
                isShowingOpeningLoading: false,
                hasAcceptedAIDisclosure: true,
                isLoading: false,
                hasCurrentPlan: true,
                isEditingPreferences: false,
                isUnlocked: false
            ),
            .previewPlan
        )
    }

    func testContentRouteShowsPreviewForGeneratedPlanWhenUserIsNotSubscribed() {
        XCTAssertEqual(
            ContentRoute.resolve(
                isShowingOpeningLoading: false,
                hasAcceptedAIDisclosure: true,
                isLoading: false,
                hasCurrentPlan: true,
                isEditingPreferences: false,
                isUnlocked: false
            ),
            .previewPlan
        )
    }

    func testContentRouteShowsUnlockedPlanForSubscriberAfterUnlockCompletes() {
        XCTAssertEqual(
            ContentRoute.resolve(
                isShowingOpeningLoading: false,
                hasAcceptedAIDisclosure: true,
                isLoading: false,
                hasCurrentPlan: true,
                isEditingPreferences: false,
                isUnlocked: true
            ),
            .unlockedPlan
        )
    }

}

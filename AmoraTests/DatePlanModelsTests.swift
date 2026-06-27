import XCTest
@testable import Amora

final class DatePlanModelsTests: XCTestCase {
    func testBudgetOptionsUseCountryCurrency() {
        let usOptions = BudgetCatalog.options(for: "US")
        XCTAssertEqual(usOptions.map(\.label), ["Free", "USD 50", "USD 100", "USD 150", "USD 200", "USD 300+"])
        XCTAssertEqual(usOptions.map(\.amount), [0, 50, 100, 150, 200, 300])

        let thailandOptions = BudgetCatalog.options(for: "TH")
        XCTAssertEqual(thailandOptions.map(\.label), ["Free", "THB 1000", "THB 2000", "THB 3500", "THB 5000", "THB 8000+"])
        XCTAssertEqual(thailandOptions.map(\.amount), [0, 1000, 2000, 3500, 5000, 8000])
    }

    func testBudgetOptionsFallbackToUSD() {
        let options = BudgetCatalog.options(for: "")

        XCTAssertEqual(options.first?.currencyCode, "USD")
        XCTAssertEqual(options.first?.amount, 0)
    }

    func testBudgetOptionsFallbackToUSDWhenCurrencyHasNoLocalSteps() {
        let options = BudgetCatalog.options(for: "JP")

        XCTAssertEqual(options.map(\.label), ["Free", "USD 50", "USD 100", "USD 150", "USD 200", "USD 300+"])
        XCTAssertEqual(options.map(\.currencyCode), ["USD", "USD", "USD", "USD", "USD", "USD"])
    }

    func testGeneratePlanRequestEncodesBudgetAmount() throws {
        let request = GeneratePlanRequest(
            locationLabel: "Williamsburg, Brooklyn",
            countryCode: "US",
            budgetAmount: 100,
            vibe: .cozy,
            noDrinking: true,
            durationMinutes: 120,
            partnerLikes: "bookstores"
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["budgetAmount"] as? Int, 100)
        XCTAssertNil(object["budgetTier"])
    }

    @MainActor
    func testLoadingPlanViewStatusMessagesDescribeGenerationSteps() {
        XCTAssertEqual(
            LoadingPlanView.statusMessages,
            [
                "Learning her preferences",
                "Scouting nearby locations",
                "Matching to your constraints",
                "Finalising your plan"
            ]
        )
    }

    @MainActor
    func testLoadingPlanViewUsesReadableTimingAndHoldsFinalStatus() {
        XCTAssertEqual(LoadingPlanView.statusMessageIntervalNanoseconds, 3_000_000_000)
        XCTAssertEqual(LoadingPlanView.nextStatusMessageIndex(after: 0), 1)
        XCTAssertEqual(LoadingPlanView.nextStatusMessageIndex(after: 2), 3)
        XCTAssertEqual(LoadingPlanView.nextStatusMessageIndex(after: 3), 3)
    }

    func testDecodeValidPlanResponse() throws {
        let json = """
        {
          "id": "plan_test_123",
          "preview": {
            "title": "A cozy 2-hour plan near Williamsburg",
            "summaryBadges": ["$$", "2 hours", "No bars"],
            "stops": [
              { "order": 1, "concept": "A cozy conversation starter", "vibe": "Calm and warm", "reason": "A low-pressure first stop gives the date room to settle in.", "personalizationSignal": "Matches her interest in quiet places." },
              { "order": 2, "concept": "A personal activity", "vibe": "Playful and personal", "reason": "A shared activity creates easy momentum.", "personalizationSignal": "Connects to her creative side." },
              { "order": 3, "concept": "A relaxed dessert finish", "vibe": "Sweet and unhurried", "reason": "A gentle final stop leaves space to linger.", "personalizationSignal": "Fits the requested cozy ending." }
            ]
          },
          "lockedPlan": {
            "totalEstimatedCost": "USD 60-90",
            "stops": [
              { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "USD 20-30" },
              { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "Free" },
              { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "USD 30-35" }
            ]
          }
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(DatePlanResponse.self, from: json)

        XCTAssertEqual(plan.preview.stops.count, 3)
        XCTAssertEqual(plan.preview.stops[0].vibe, "Calm and warm")
        XCTAssertEqual(plan.preview.stops[0].reason, "A low-pressure first stop gives the date room to settle in.")
        XCTAssertEqual(plan.preview.stops[0].personalizationSignal, "Matches her interest in quiet places.")
        XCTAssertEqual(plan.lockedPlan.stops.count, 3)
        XCTAssertEqual(plan.lockedPlan.totalEstimatedCost, "USD 60-90")
        XCTAssertEqual(plan.lockedPlan.stops[1].estimatedCost, "Free")
    }
}

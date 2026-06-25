import XCTest
@testable import Amora

final class DatePlanModelsTests: XCTestCase {
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
            "totalEstimatedCost": "$60-$90",
            "stops": [
              { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "$20-$30" },
              { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "$10-$25" },
              { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "$30-$35" }
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
        XCTAssertEqual(plan.lockedPlan.totalEstimatedCost, "$60-$90")
    }
}

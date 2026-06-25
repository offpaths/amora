import Foundation

enum BudgetTier: String, Codable, CaseIterable, Identifiable {
    case low = "$"
    case medium = "$$"
    case high = "$$$"

    var id: String { rawValue }
}

enum DateVibe: String, Codable, CaseIterable, Identifiable {
    case cozy
    case adventurous
    case romantic
    case lowKey = "low-key"
    case foodie
    case outdoorsy

    var id: String { rawValue }
}

struct GeneratePlanRequest: Codable, Equatable {
    var locationLabel: String
    var budgetTier: BudgetTier
    var vibe: DateVibe
    var noDrinking: Bool
    var durationMinutes: Int
    var partnerLikes: String
}

struct DatePlanResponse: Codable, Equatable, Identifiable {
    var id: String
    var preview: PlanPreview
    var lockedPlan: LockedPlan
}

struct PlanPreview: Codable, Equatable {
    var title: String
    var summaryBadges: [String]
    var stops: [PreviewStop]
}

struct PreviewStop: Codable, Equatable, Identifiable {
    var order: Int
    var concept: String
    var vibe: String
    var reason: String
    var personalizationSignal: String
    var id: Int { order }

    init(order: Int, concept: String, vibe: String, reason: String, personalizationSignal: String) {
        self.order = order
        self.concept = concept
        self.vibe = vibe
        self.reason = reason
        self.personalizationSignal = personalizationSignal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decode(Int.self, forKey: .order)
        concept = try container.decode(String.self, forKey: .concept)
        vibe = try container.decodeIfPresent(String.self, forKey: .vibe) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        personalizationSignal = try container.decodeIfPresent(String.self, forKey: .personalizationSignal) ?? ""
    }
}

struct LockedPlan: Codable, Equatable {
    var totalEstimatedCost: String
    var stops: [LockedStop]
}

struct LockedStop: Codable, Equatable, Identifiable {
    var order: Int
    var venueName: String
    var address: String
    var appleMapsQuery: String
    var durationMinutes: Int
    var reason: String
    var estimatedCost: String
    var id: Int { order }
}

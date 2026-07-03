import Foundation

struct BudgetOption: Equatable, Identifiable {
    var amount: Int
    var currencyCode: String
    var isOpenEnded: Bool

    var id: String { "\(currencyCode)-\(amount)" }

    var label: String {
        if amount == 0 {
            return "Free"
        }
        return "\(currencyCode) \(amount)\(isOpenEnded ? "+" : "")"
    }
}

enum BudgetCatalog {
    static func currencyCode(for countryCode: String) -> String {
        countryCurrencyMap[countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()] ?? "USD"
    }

    static func options(for countryCode: String) -> [BudgetOption] {
        let resolvedCurrencyCode = currencyCode(for: countryCode)
        let currencyCode = budgetSteps[resolvedCurrencyCode] == nil ? "USD" : resolvedCurrencyCode
        let amounts = budgetSteps[currencyCode]!
        return amounts.enumerated().map { index, amount in
            BudgetOption(amount: amount, currencyCode: currencyCode, isOpenEnded: index == amounts.count - 1)
        }
    }

    private static let budgetSteps: [String: [Int]] = [
        "USD": [0, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300],
        "GBP": [0, 20, 40, 60, 80, 100, 120, 150, 180, 215, 250],
        "EUR": [0, 25, 50, 70, 90, 115, 140, 170, 200, 250, 300],
        "THB": [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 5000, 6500, 8000]
    ]

    private static let countryCurrencyMap: [String: String] = [
        "AD": "EUR", "AE": "AED", "AT": "EUR", "AU": "AUD", "BE": "EUR", "BR": "BRL",
        "CA": "CAD", "CH": "CHF", "CN": "CNY", "CY": "EUR", "CZ": "CZK", "DE": "EUR",
        "DK": "DKK", "EE": "EUR", "ES": "EUR", "FI": "EUR", "FR": "EUR", "GB": "GBP",
        "GR": "EUR", "HK": "HKD", "HR": "EUR", "HU": "HUF", "IE": "EUR", "IL": "ILS",
        "IN": "INR", "IT": "EUR", "JP": "JPY", "KR": "KRW", "LT": "EUR", "LU": "EUR",
        "LV": "EUR", "MC": "EUR", "MT": "EUR", "MX": "MXN", "MY": "MYR", "NL": "EUR",
        "NO": "NOK", "NZ": "NZD", "PH": "PHP", "PL": "PLN", "PT": "EUR", "SA": "SAR",
        "SE": "SEK", "SG": "SGD", "SI": "EUR", "SK": "EUR", "TH": "THB", "TR": "TRY",
        "TW": "TWD", "US": "USD", "VN": "VND", "ZA": "ZAR"
    ]
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
    var countryCode: String
    var budgetAmount: Int
    var vibe: DateVibe
    var noDrinking: Bool
    var durationMinutes: Int
    var partnerLikes: String
    var regenerationAttempt: Int = 0
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

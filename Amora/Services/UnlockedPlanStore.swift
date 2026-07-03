import Foundation

struct SavedUnlockedPlan: Codable, Equatable {
    var plan: DatePlanResponse
    var savedAt: Date
}

struct UnlockedPlanStore {
    private static let storageKey = "latestUnlockedPlan"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> SavedUnlockedPlan? {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return nil
        }
        return try? decoder.decode(SavedUnlockedPlan.self, from: data)
    }

    func save(plan: DatePlanResponse, savedAt: Date = Date()) {
        let savedPlan = SavedUnlockedPlan(plan: plan, savedAt: savedAt)
        guard let data = try? encoder.encode(savedPlan) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}

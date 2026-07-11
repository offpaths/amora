import Foundation

enum AppConfig {
    static let backendBaseURL = URL(string: "https://api.planwithamora.com")!
    static let plusMonthlyProductID = "amora_plus_monthly"
    static let storeKitProductIDs = [plusMonthlyProductID]
    static let privacyPolicyURL = URL(string: "https://planwithamora.com/privacy")!
    static let termsOfUseURL = URL(string: "https://planwithamora.com/terms")!
}

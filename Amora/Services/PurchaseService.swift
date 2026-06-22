import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var product: Product?

    func loadProduct() async {
        do {
            product = try await Product.products(for: [AppConfig.unlockProductID]).first
        } catch {
            product = nil
        }
    }

    func purchaseUnlock() async -> Bool {
        guard let product else { return false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified = verification {
                return true
            }
            return false
        } catch {
            return false
        }
    }
}

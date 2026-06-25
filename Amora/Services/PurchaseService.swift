import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var unlockProduct: Product?
    @Published private(set) var plusMonthlyProduct: Product?
    @Published private(set) var hasActiveSubscription = false

    func loadProduct() async {
        await loadProducts()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [AppConfig.unlockProductID, AppConfig.plusMonthlyProductID])
            unlockProduct = products.first { $0.id == AppConfig.unlockProductID }
            plusMonthlyProduct = products.first { $0.id == AppConfig.plusMonthlyProductID }
            await refreshSubscriptionStatus()
        } catch {
            unlockProduct = nil
            plusMonthlyProduct = nil
        }
    }

    func purchaseUnlock() async -> Bool {
        if unlockProduct == nil {
            await loadProducts()
        }
        guard let unlockProduct else { return false }
        return await purchase(unlockProduct)
    }

    func purchasePlusMonthly() async -> Bool {
        if plusMonthlyProduct == nil {
            await loadProducts()
        }
        guard let plusMonthlyProduct else { return false }
        let success = await purchase(plusMonthlyProduct)
        if success {
            hasActiveSubscription = true
        }
        return success
    }

    func refreshSubscriptionStatus() async {
        var isActive = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else {
                continue
            }

            if transaction.productID == AppConfig.plusMonthlyProductID {
                isActive = true
                break
            }
        }

        hasActiveSubscription = isActive
    }

    private func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified(let transaction) = verification {
                await transaction.finish()
                return true
            }
            return false
        } catch {
            return false
        }
    }
}

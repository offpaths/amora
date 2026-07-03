import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var plusMonthlyProduct: Product?
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var didLoadProducts = false
    @Published private(set) var isRestoringPurchases = false

    func loadProduct() async {
        await loadProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer {
            didLoadProducts = true
            isLoadingProducts = false
        }

        do {
            let products = try await Product.products(for: AppConfig.storeKitProductIDs)
            plusMonthlyProduct = products.first { $0.id == AppConfig.plusMonthlyProductID }
            await refreshSubscriptionStatus()
        } catch {
            plusMonthlyProduct = nil
        }
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

    func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
        } catch {
            // Keep restore user-driven and non-fatal; entitlement refresh below reflects final state.
        }

        await refreshSubscriptionStatus()
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

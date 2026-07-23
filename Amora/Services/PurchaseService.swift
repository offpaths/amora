import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var plusMonthlyProduct: Product?
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var activeSignedTransactionInfo: String?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var didLoadProducts = false
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var purchaseMessage: String?
    private var transactionUpdatesTask: Task<Void, Never>?
    private let analytics: any AnalyticsTracking

    init(analytics: any AnalyticsTracking = PostHogAnalytics.shared) {
        self.analytics = analytics
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshSubscriptionStatus()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
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
            purchaseMessage = plusMonthlyProduct == nil ? "Amora Plus is unavailable right now. Try again in a moment." : nil
            await refreshSubscriptionStatus()
        } catch {
            plusMonthlyProduct = nil
            purchaseMessage = "Amora Plus is unavailable right now. Check your connection and try again."
        }
    }

    func purchasePlusMonthly() async -> Bool {
        if plusMonthlyProduct == nil {
            await loadProducts()
        }
        guard let plusMonthlyProduct else { return false }
        let success = await purchase(plusMonthlyProduct)
        if success {
            await refreshSubscriptionStatus()
        }
        return success
    }

    func refreshSubscriptionStatus() async {
        var isActive = false
        var activeSignedTransactionInfo: String?

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else {
                continue
            }

            if transaction.productID == AppConfig.plusMonthlyProductID {
                isActive = true
                activeSignedTransactionInfo = entitlement.jwsRepresentation
                break
            }
        }

        hasActiveSubscription = isActive
        self.activeSignedTransactionInfo = activeSignedTransactionInfo
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
        analytics.capture("purchases_restored", properties: ["success": hasActiveSubscription])
        if !hasActiveSubscription {
            purchaseMessage = "No active Amora Plus subscription was found. Try the Apple Account used for the purchase."
        } else {
            purchaseMessage = nil
        }
    }

    private func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified(let transaction) = verification {
                await transaction.finish()
                purchaseMessage = nil
                analytics.capture("subscription_purchased")
                return true
            }
            if case .userCancelled = result {
                purchaseMessage = "Purchase cancelled. Your preview is still here when you are ready."
                analytics.capture("subscription_purchase_cancelled")
            } else if case .pending = result {
                purchaseMessage = "Your purchase is waiting for approval. We will unlock the plan once Apple confirms it."
            } else {
                purchaseMessage = "We could not verify that purchase. Try restoring your purchases."
                analytics.capture("subscription_purchase_failed")
            }
            return false
        } catch {
            purchaseMessage = "We could not start the purchase. Check your connection and try again."
            analytics.capture("subscription_purchase_failed")
            return false
        }
    }
}

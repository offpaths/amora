import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlanViewModel()
    @StateObject private var purchaseService = PurchaseService()
    @State private var showingPaywall = false

    var body: some View {
        Group {
            if viewModel.currentPlan == nil {
                InputView(viewModel: viewModel)
            } else if viewModel.isUnlocked {
                UnlockedPlanView(viewModel: viewModel)
            } else {
                PreviewPlanView(viewModel: viewModel) {
                    showingPaywall = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(purchaseService: purchaseService) { purchase in
                switch purchase {
                case .subscription(let success):
                    viewModel.completeSubscriptionPurchase(success: success)
                case .onePlan(let success):
                    viewModel.completePurchase(success: success)
                }
                showingPaywall = false
            }
        }
        .task {
            await purchaseService.loadProducts()
            viewModel.setSubscriptionActive(purchaseService.hasActiveSubscription)
        }
        .onChange(of: purchaseService.hasActiveSubscription) { _, isActive in
            viewModel.setSubscriptionActive(isActive)
        }
    }
}

#Preview {
    ContentView()
}

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
            PaywallView(purchaseService: purchaseService) { success in
                viewModel.completePurchase(success: success)
                showingPaywall = false
            }
        }
    }
}

#Preview {
    ContentView()
}

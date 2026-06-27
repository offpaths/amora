import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlanViewModel(telemetry: .live)
    @StateObject private var purchaseService = PurchaseService()
    @State private var showingPaywall = false
    @State private var isEditingPreferences = false
    @State private var isShowingOpeningLoading = true
    @State private var hasStartedOpeningTask = false

    var body: some View {
        Group {
            if isShowingOpeningLoading {
                OpeningLoadingView()
            } else if !viewModel.hasAcceptedAIDisclosure {
                AIConsentView {
                    viewModel.acceptAIDisclosure()
                }
            } else if viewModel.isLoading {
                LoadingPlanView()
            } else if viewModel.currentPlan == nil || isEditingPreferences {
                InputView(viewModel: viewModel, initialStep: viewModel.currentPlan == nil ? 1 : 2) {
                    isEditingPreferences = false
                } onReturnToExistingPlan: {
                    isEditingPreferences = false
                }
            } else if viewModel.isUnlocked {
                UnlockedPlanView(viewModel: viewModel) {
                    viewModel.startNewDate()
                }
            } else {
                PreviewPlanView(viewModel: viewModel) {
                    viewModel.recordPaywallViewed()
                    showingPaywall = true
                } onEditPreferences: {
                    isEditingPreferences = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(purchaseService: purchaseService) { productType in
                viewModel.recordPurchaseStarted(productType: productType)
            } onPurchased: { purchase in
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
            guard !hasStartedOpeningTask else { return }
            hasStartedOpeningTask = true
            async let products: Void = purchaseService.loadProducts()
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                isShowingOpeningLoading = false
            }
            await products
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

private struct AIConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A better plan needs context")
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text("Amora uses your planning area, preferences, and personal details to build a date plan that feels specific instead of generic.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Used to create your plan", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmoraTheme.ink)

                        Text("To make the plan thoughtful, Amora sends the details you provide to our AI provider for generation. Share only what you are comfortable using for this date plan.")
                            .font(.subheadline)
                            .foregroundStyle(AmoraTheme.muted)

                        HStack(spacing: 14) {
                            Link("Privacy", destination: AppConfig.privacyPolicyURL)
                            Link("Terms", destination: AppConfig.termsOfUseURL)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.oxblood)
                    }
                }

                AnalyticsPrivacyToggle()

                PrimaryButton(title: "Agree and Continue", isLoading: false, action: onAccept)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .amoraScreen()
    }
}

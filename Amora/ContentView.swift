import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlanViewModel()
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
                    showingPaywall = true
                } onEditPreferences: {
                    isEditingPreferences = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(purchaseService: purchaseService) { _ in
            } onPurchased: { success in
                Task {
                    await viewModel.completeSubscriptionPurchase(
                        success: success,
                        signedTransactionInfo: purchaseService.activeSignedTransactionInfo
                    )
                    showingPaywall = false
                }
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
            await viewModel.setSubscriptionActive(
                purchaseService.hasActiveSubscription,
                signedTransactionInfo: purchaseService.activeSignedTransactionInfo
            )
        }
        .onChange(of: purchaseService.hasActiveSubscription) { _, isActive in
            Task {
                await viewModel.setSubscriptionActive(
                    isActive,
                    signedTransactionInfo: purchaseService.activeSignedTransactionInfo
                )
            }
        }
        .onChange(of: purchaseService.activeSignedTransactionInfo) { _, signedTransactionInfo in
            Task {
                await viewModel.setSubscriptionActive(
                    purchaseService.hasActiveSubscription,
                    signedTransactionInfo: signedTransactionInfo
                )
            }
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
                    Text("A quick note before we plan")
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text("Share the context that would help the date feel personal. Leave out anything you would not want processed for planning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Used only to shape this date plan", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmoraTheme.ink)

                        Text("Amora sends your planning area, preferences, and any personal context you provide to our AI provider to generate a thoughtful, specific plan.")
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
                PrimaryButton(title: "Continue", isLoading: false, action: onAccept)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .amoraScreen()
    }
}

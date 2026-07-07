import SwiftUI

enum ContentRoute: Equatable {
    case openingLoading
    case aiConsent
    case loadingPlan
    case input
    case unlockedPlan
    case previewPlan

    static func resolve(
        isShowingOpeningLoading: Bool,
        hasAcceptedAIDisclosure: Bool,
        isLoading: Bool,
        hasCurrentPlan: Bool,
        isEditingPreferences: Bool,
        isUnlocked: Bool,
        hasActiveSubscription: Bool
    ) -> ContentRoute {
        if isShowingOpeningLoading {
            return .openingLoading
        }
        if !hasAcceptedAIDisclosure {
            return .aiConsent
        }
        if isLoading {
            return .loadingPlan
        }
        if !hasCurrentPlan || isEditingPreferences {
            return .input
        }
        if isUnlocked {
            return .unlockedPlan
        }
        return .previewPlan
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PlanViewModel()
    @StateObject private var purchaseService = PurchaseService()
    @State private var showingPaywall = false
    @State private var isEditingPreferences = false
    @State private var isShowingOpeningLoading = true
    @State private var hasStartedOpeningTask = false
    @State private var isCompletingPaywallPurchase = false

    var body: some View {
        let route = ContentRoute.resolve(
            isShowingOpeningLoading: isShowingOpeningLoading,
            hasAcceptedAIDisclosure: viewModel.hasAcceptedAIDisclosure,
            isLoading: viewModel.isLoading,
            hasCurrentPlan: viewModel.currentPlan != nil,
            isEditingPreferences: isEditingPreferences,
            isUnlocked: viewModel.isUnlocked,
            hasActiveSubscription: viewModel.hasActiveSubscription
        )

        return Group {
            if route == .openingLoading {
                OpeningLoadingView()
            } else if route == .aiConsent {
                AIConsentView {
                    viewModel.acceptAIDisclosure()
                }
            } else if route == .loadingPlan {
                LoadingPlanView()
            } else if route == .input {
                InputView(viewModel: viewModel, initialStep: viewModel.currentPlan == nil ? 1 : 2) {
                    isEditingPreferences = false
                } onReturnToExistingPlan: {
                    isEditingPreferences = false
                }
            } else if route == .unlockedPlan {
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
                    guard success else { return }
                    isCompletingPaywallPurchase = true
                    defer { isCompletingPaywallPurchase = false }
                    let didUnlock = await viewModel.completeSubscriptionPurchase(
                        success: success,
                        signedTransactionInfo: purchaseService.activeSignedTransactionInfo
                    )
                    if didUnlock {
                        showingPaywall = false
                    }
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
                guard !isCompletingPaywallPurchase else { return }
                await viewModel.setSubscriptionActive(
                    isActive,
                    signedTransactionInfo: purchaseService.activeSignedTransactionInfo
                )
                if viewModel.isUnlocked {
                    showingPaywall = false
                }
            }
        }
        .onChange(of: purchaseService.activeSignedTransactionInfo) { _, signedTransactionInfo in
            Task {
                guard !isCompletingPaywallPurchase else { return }
                await viewModel.setSubscriptionActive(
                    purchaseService.hasActiveSubscription,
                    signedTransactionInfo: signedTransactionInfo
                )
                if viewModel.isUnlocked {
                    showingPaywall = false
                }
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

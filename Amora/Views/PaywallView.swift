import SwiftUI
import StoreKit

enum PaywallPurchaseResult {
    case subscription(Bool)
    case onePlan(Bool)
}

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchaseStarted: (String) -> Void
    let onPurchased: (PaywallPurchaseResult) -> Void
    @State private var isShowingManageSubscriptions = false

    private var isPreparingPurchase: Bool {
        purchaseService.isLoadingProducts || !purchaseService.didLoadProducts
    }

    private var canPurchaseSubscription: Bool {
        !isPreparingPurchase && purchaseService.plusMonthlyProduct != nil
    }

    private var canPurchaseOnePlan: Bool {
        !isPreparingPurchase && purchaseService.unlockProduct != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                PillLabel(text: "Full itinerary", tint: AmoraTheme.brass)
                Text("Reveal Your Full Date Plan")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(AmoraTheme.ink)
            }

            Text.amoraBrand("Walk in with more confidence and less guesswork. Amora Plus unlocks unlimited thoughtful date plans with exact venues, timing, and reasons built around what would make her feel seen.", baseColor: AmoraTheme.muted)
                .font(.body)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    PaywallFeature(title: Text.amoraBrand("Unlimited fresh date plans with Amora Plus", baseColor: AmoraTheme.ink), systemImage: "infinity")
                    PaywallFeature(title: "Exact venues", systemImage: "mappin.and.ellipse")
                    PaywallFeature(title: "Timing per stop", systemImage: "clock")
                    PaywallFeature(title: "Reasons tied to what she likes", systemImage: "heart")
                    PaywallFeature(title: "Estimated local costs", systemImage: "dollarsign.circle")
                    PaywallFeature(title: "Apple Maps actions", systemImage: "map")
                    PaywallFeature(title: "One-time unlock available for tonight", systemImage: "seal")
                }
            }

            Spacer()

            PrimaryButton(title: primaryButtonTitle, isLoading: isPreparingPurchase) {
                Task {
                    onPurchaseStarted("subscription")
                    let success = await purchaseService.purchasePlusMonthly()
                    onPurchased(.subscription(success))
                }
            }
            .disabled(!canPurchaseSubscription)

            Button {
                Task {
                    onPurchaseStarted("one_plan")
                    let success = await purchaseService.purchaseUnlock()
                    onPurchased(.onePlan(success))
                }
            } label: {
                Text("Just need this one? Unlock once for \(purchaseService.unlockProduct?.displayPrice ?? "$4.99")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AmoraTheme.oxblood)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .disabled(!canPurchaseOnePlan)
            .opacity(canPurchaseOnePlan ? 1 : 0.55)

            VStack(spacing: 12) {
                Button {
                    Task {
                        await purchaseService.restorePurchases()
                    }
                } label: {
                    Text(purchaseService.isRestoringPurchases ? "Restoring Purchases..." : "Restore Purchases")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AmoraTheme.oxblood)
                        .frame(maxWidth: .infinity)
                }
                .disabled(purchaseService.isRestoringPurchases)

                if purchaseService.hasActiveSubscription {
                    Button {
                        isShowingManageSubscriptions = true
                    } label: {
                        Text("Manage Subscription")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AmoraTheme.oxblood)
                            .frame(maxWidth: .infinity)
                    }
                }

                complianceFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .amoraScreen()
        .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
        .task {
            await purchaseService.loadProducts()
        }
    }

    private var primaryButtonTitle: String {
        guard !isPreparingPurchase else { return "Preparing Amora Plus" }
        guard canPurchaseSubscription else { return "Amora Plus Unavailable" }
        return "Start Amora Plus \(purchaseService.plusMonthlyProduct?.displayPrice ?? "$9.99/month")"
    }

    private var complianceFooter: some View {
        VStack(spacing: 6) {
            Text("Amora Plus Monthly is \(purchaseService.plusMonthlyProduct?.displayPrice ?? "$9.99") per month and renews automatically until canceled. Payment is billed to your Apple Account. Manage or cancel anytime in App Store account settings.")
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link("Privacy", destination: AppConfig.privacyPolicyURL)
                Text("|")
                Link("Terms", destination: AppConfig.termsOfUseURL)
            }
        }
        .font(.caption2)
        .foregroundStyle(AmoraTheme.muted)
        .frame(maxWidth: .infinity)
    }
}

private struct PaywallFeature: View {
    let title: Text
    let systemImage: String

    init(title: String, systemImage: String) {
        self.title = Text(title)
            .foregroundStyle(AmoraTheme.ink)
        self.systemImage = systemImage
    }

    init(title: Text, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            title
                .font(.subheadline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AmoraTheme.oxblood)
        }
    }
}

import SwiftUI

enum PaywallPurchaseResult {
    case subscription(Bool)
    case onePlan(Bool)
}

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchased: (PaywallPurchaseResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                PillLabel(text: "Sealed itinerary", tint: AmoraTheme.brass)
                Text("Reveal Your Full Date Plan")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(AmoraTheme.ink)
            }

            Text("Walk in with more confidence and less guesswork. Amora Plus unlocks unlimited thoughtful date plans with exact venues, timing, and reasons built around what would make her feel seen.")
                .font(.body)
                .foregroundStyle(AmoraTheme.muted)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    PaywallFeature(title: "Unlimited fresh date plans with Amora Plus", systemImage: "infinity")
                    PaywallFeature(title: "Exact venues", systemImage: "mappin.and.ellipse")
                    PaywallFeature(title: "Timing per stop", systemImage: "clock")
                    PaywallFeature(title: "Reasons tied to what she likes", systemImage: "heart")
                    PaywallFeature(title: "Estimated local costs", systemImage: "dollarsign.circle")
                    PaywallFeature(title: "Apple Maps actions", systemImage: "map")
                    PaywallFeature(title: "One-time unlock available for tonight", systemImage: "seal")
                }
            }

            Spacer()

            PrimaryButton(title: "Start Amora Plus \(purchaseService.plusMonthlyProduct?.displayPrice ?? "$9.99/month")", isLoading: false) {
                Task {
                    let success = await purchaseService.purchasePlusMonthly()
                    onPurchased(.subscription(success))
                }
            }

            Button {
                Task {
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .amoraScreen()
        .task {
            await purchaseService.loadProducts()
        }
    }
}

private struct PaywallFeature: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AmoraTheme.ink)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AmoraTheme.oxblood)
        }
    }
}

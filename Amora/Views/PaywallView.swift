import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchased: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                PillLabel(text: "Sealed itinerary", tint: AmoraTheme.brass)
                Text("Reveal Your Full Date Plan")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(AmoraTheme.ink)
            }

            Text("Walk in with more confidence and less guesswork. Reveal the exact venues, timing, and reasons behind a plan built to feel considered.")
                .font(.body)
                .foregroundStyle(AmoraTheme.muted)

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    PaywallFeature(title: "More confidence going into the date", systemImage: "checkmark.seal")
                    PaywallFeature(title: "A smoother night with less guesswork", systemImage: "sparkles")
                    PaywallFeature(title: "Exact venues", systemImage: "mappin.and.ellipse")
                    PaywallFeature(title: "Timing per stop", systemImage: "clock")
                    PaywallFeature(title: "Reasons tied to what she likes", systemImage: "heart")
                    PaywallFeature(title: "Estimated cost", systemImage: "dollarsign.circle")
                    PaywallFeature(title: "Apple Maps actions", systemImage: "map")
                }
            }

            Spacer()

            PrimaryButton(title: purchaseService.product?.displayPrice ?? "$4.99", isLoading: false) {
                Task {
                    let success = await purchaseService.purchaseUnlock()
                    onPurchased(success)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .amoraScreen()
        .task {
            await purchaseService.loadProduct()
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

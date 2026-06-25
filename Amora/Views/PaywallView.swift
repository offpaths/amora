import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchased: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Reveal Your Full Date Plan")
                .font(.largeTitle.bold())

            Text("Walk in with more confidence and less guesswork. Reveal the exact venues, timing, and reasons behind a plan built to feel considered.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label("More confidence going into the date", systemImage: "checkmark.seal")
                Label("A smoother night with less guesswork", systemImage: "sparkles")
                Label("Exact venues", systemImage: "mappin.and.ellipse")
                Label("Timing per stop", systemImage: "clock")
                Label("Reasons tied to what she likes", systemImage: "heart")
                Label("Estimated cost", systemImage: "dollarsign.circle")
                Label("Apple Maps actions", systemImage: "map")
            }

            Spacer()

            Button(purchaseService.product?.displayPrice ?? "$4.99") {
                Task {
                    let success = await purchaseService.purchaseUnlock()
                    onPurchased(success)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .task {
            await purchaseService.loadProduct()
        }
    }
}

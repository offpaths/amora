import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchased: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Unlock 1 Thoughtful Date Plan")
                .font(.largeTitle.bold())

            Text("Make the money you are already spending on the date worth it with a plan built around this person, not a copy-pasted night out.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label("Exact venues", systemImage: "mappin.and.ellipse")
                Label("Timing per stop", systemImage: "clock")
                Label("Reasons that match their interests", systemImage: "heart")
                Label("Fresh plan for this person and moment", systemImage: "sparkles")
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

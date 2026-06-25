import SwiftUI

struct PreviewPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    let onUnlock: () -> Void

    var body: some View {
        if let plan = viewModel.currentPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(plan.preview.title)
                        .font(.largeTitle.bold())

                    FlowBadges(badges: plan.preview.summaryBadges)

                    Text("Your sealed itinerary is ready. Exact venues, timing, costs, and maps unlock when you reveal the full plan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        ForEach(plan.preview.stops) { stop in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Stop \(stop.order)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(stop.concept)
                                    .font(.headline)
                                PillLabel(text: stop.vibe)
                                Text(stop.reason)
                                    .font(.subheadline)
                                Text(stop.personalizationSignal)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Label("Exact venue, timing, cost, and maps unlock after purchase", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Button("Reveal Full Plan", action: onUnlock)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                    Button("Make It Feel Different") {
                        Task { await viewModel.generatePreview() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isLoading)
                }
                .padding()
            }
        } else {
            InputView(viewModel: viewModel)
        }
    }
}

import SwiftUI

struct UnlockedPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let plan = viewModel.currentPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your thoughtful plan")
                        .font(.largeTitle.bold())
                    PillLabel(text: "Estimated total \(plan.lockedPlan.totalEstimatedCost)")

                    ForEach(plan.lockedPlan.stops) { stop in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stop \(stop.order)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(stop.venueName)
                                .font(.title3.bold())
                            Text(stop.reason)
                            HStack {
                                PillLabel(text: "\(stop.durationMinutes) min")
                                PillLabel(text: stop.estimatedCost)
                            }
                            Button {
                                openURL(appleMapsURL(for: stop))
                            } label: {
                                Label("Open in Apple Maps", systemImage: "map")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if viewModel.canRegenerateUnlockedPlan {
                        Button("Regenerate Once") {
                            Task { await viewModel.regenerateUnlockedPlan() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        } else {
            InputView(viewModel: viewModel)
        }
    }

    private func appleMapsURL(for stop: LockedStop) -> URL {
        var components = URLComponents(string: "http://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: stop.appleMapsQuery)]
        return components.url!
    }
}

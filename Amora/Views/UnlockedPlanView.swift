import SwiftUI

struct UnlockedPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let plan = viewModel.currentPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your thoughtful plan")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(AmoraTheme.ink)
                    PillLabel(text: "Estimated total \(plan.lockedPlan.totalEstimatedCost)", tint: AmoraTheme.olive)

                    VStack(spacing: 12) {
                        ForEach(plan.lockedPlan.stops) { stop in
                            SurfaceCard {
                                HStack(alignment: .top, spacing: 14) {
                                    ItineraryNumber(value: stop.order)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(stop.venueName)
                                            .font(.title3.weight(.bold))
                                        Text(stop.address)
                                            .font(.caption)
                                            .foregroundStyle(AmoraTheme.muted)
                                        Text(stop.reason)
                                            .font(.subheadline)
                                        HStack {
                                            PillLabel(text: "\(stop.durationMinutes) min", tint: AmoraTheme.brass)
                                            PillLabel(text: stop.estimatedCost, tint: AmoraTheme.olive)
                                        }
                                        Button {
                                            openURL(appleMapsURL(for: stop))
                                        } label: {
                                            Label("Open in Apple Maps", systemImage: "map")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AmoraTheme.oxblood)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(AmoraTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(AmoraTheme.border, lineWidth: 1)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if viewModel.canRegenerateUnlockedPlan {
                        PrimaryButton(title: "Regenerate Once", isLoading: viewModel.isLoading) {
                            Task { await viewModel.regenerateUnlockedPlan() }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .amoraScreen()
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

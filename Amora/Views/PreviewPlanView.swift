import SwiftUI

struct PreviewPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    let onUnlock: () -> Void

    var body: some View {
        if let plan = viewModel.currentPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(plan.preview.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(AmoraTheme.ink)

                    FlowBadges(badges: plan.preview.summaryBadges)

                    Text("Your sealed itinerary is ready. Exact venues, timing, costs, and maps unlock when you reveal the full plan.")
                        .font(.subheadline)
                        .foregroundStyle(AmoraTheme.muted)

                    VStack(spacing: 12) {
                        ForEach(plan.preview.stops) { stop in
                            SurfaceCard {
                                HStack(alignment: .top, spacing: 14) {
                                    ItineraryNumber(value: stop.order)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(stop.concept)
                                            .font(.headline)
                                        if !stop.vibe.isEmpty {
                                            PillLabel(text: stop.vibe, tint: AmoraTheme.brass)
                                        }
                                        if !stop.reason.isEmpty {
                                            Text(stop.reason)
                                                .font(.subheadline)
                                                .foregroundStyle(AmoraTheme.ink)
                                        }
                                        if !stop.personalizationSignal.isEmpty {
                                            Text(stop.personalizationSignal)
                                                .font(.caption)
                                                .foregroundStyle(AmoraTheme.muted)
                                        }
                                        Label("Exact venue, timing, cost, and maps unlock after purchase", systemImage: "lock.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AmoraTheme.oxblood)
                                    }
                                }
                            }
                        }
                    }

                    PrimaryButton(title: "Reveal Full Plan", isLoading: false, action: onUnlock)

                    SecondaryButton("Make It Feel Different", systemImage: "arrow.clockwise") {
                        Task { await viewModel.generatePreview() }
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .amoraScreen()
        } else {
            InputView(viewModel: viewModel)
        }
    }
}

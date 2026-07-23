import PostHog
import SwiftUI

struct UnlockedPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    let onPlanNewDate: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let plan = viewModel.currentPlan, let lockedPlan = plan.lockedPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if viewModel.isShowingSavedUnlockedPlan {
                        Button(action: onPlanNewDate) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AmoraTheme.oxblood)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(plan.preview.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(AmoraTheme.ink)
                    PillLabel(text: "Estimated total \(lockedPlan.totalEstimatedCost)", tint: AmoraTheme.olive)

                    VStack(spacing: 12) {
                        ForEach(lockedPlan.stops) { stop in
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    StopIllustrationPanel(systemImage: illustrationSystemName(for: stop))

                                    HStack(alignment: .top, spacing: 14) {
                                        ItineraryNumber(value: stop.order)
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(stop.venueName)
                                                .font(.title3.weight(.bold))
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(stop.address)
                                                .font(.caption)
                                                .foregroundStyle(AmoraTheme.muted)
                                                .fixedSize(horizontal: false, vertical: true)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Why this fits")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(AmoraTheme.olive)
                                                Text(stop.reason)
                                                    .font(.subheadline)
                                                    .foregroundStyle(AmoraTheme.ink)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            ViewThatFits(in: .horizontal) {
                                                HStack {
                                                    PillLabel(text: "\(stop.durationMinutes) min", tint: AmoraTheme.brass)
                                                    PillLabel(text: stop.estimatedCost, tint: AmoraTheme.olive)
                                                }

                                                VStack(alignment: .leading, spacing: 8) {
                                                    PillLabel(text: "\(stop.durationMinutes) min", tint: AmoraTheme.brass)
                                                    PillLabel(text: stop.estimatedCost, tint: AmoraTheme.olive)
                                                }
                                            }
                                            Button {
                                                PostHogSDK.shared.capture("venue_opened_in_maps", properties: ["stop_order": stop.order])
                                                openURL(appleMapsURL(for: stop))
                                            } label: {
                                                Label("Open in Apple Maps", systemImage: "map")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AmoraTheme.oxblood)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(minHeight: 44)
                                                    .background(AmoraTheme.surface)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(AmoraTheme.border, lineWidth: 1)
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }

                    if viewModel.isUnlocked {
                        if viewModel.shouldShowRefinePlanAction {
                            PrimaryButton(
                                title: viewModel.refinePlanButtonTitle,
                                isLoading: viewModel.isLoading,
                                isDisabled: viewModel.isRefinePlanDisabled
                            ) {
                                Task { await viewModel.regenerateUnlockedPlan() }
                            }
                        }
                        if viewModel.shouldShowPlanNewDateAction {
                            SecondaryButton("Plan a New Date", systemImage: "plus", action: onPlanNewDate)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
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

    private func illustrationSystemName(for stop: LockedStop) -> String {
        let searchableText = [
            stop.venueName,
            stop.address,
            stop.appleMapsQuery,
            stop.reason
        ]
        .joined(separator: " ")
        .lowercased()

        if searchableText.containsAny(of: ["coffee", "cafe", "café", "espresso", "matcha", "tea", "bakery"]) {
            return "cup.and.saucer.fill"
        }
        if searchableText.containsAny(of: ["book", "library", "bookstore"]) {
            return "books.vertical.fill"
        }
        if searchableText.containsAny(of: ["museum", "gallery", "art", "exhibit"]) {
            return "photo.artframe"
        }
        if searchableText.containsAny(of: ["dessert", "cake", "ice cream", "gelato", "pastry"]) {
            return "birthday.cake.fill"
        }
        if searchableText.containsAny(of: ["park", "garden", "trail", "waterfall", "beach", "walk", "outdoor"]) {
            return "leaf.fill"
        }
        if searchableText.containsAny(of: ["music", "jazz", "concert", "vinyl", "listening"]) {
            return "music.note"
        }
        if searchableText.containsAny(of: ["restaurant", "dinner", "sushi", "taco", "pizza", "bistro", "food"]) {
            return "fork.knife"
        }
        return "sparkles"
    }
}

private extension String {
    func containsAny(of keywords: [String]) -> Bool {
        keywords.contains { contains($0) }
    }
}

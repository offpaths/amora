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
                                VStack(alignment: .leading, spacing: 14) {
                                    StopIllustrationPanel(systemImage: illustrationSystemName(for: stop))

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
                    }

                    if viewModel.canRegenerateUnlockedPlan {
                        PrimaryButton(title: viewModel.hasActiveSubscription ? "Regenerate Plan" : "Regenerate Once", isLoading: viewModel.isLoading) {
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

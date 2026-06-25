import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: PlanViewModel
    @State private var locationService = LocationLabelService()
    @State private var isDetectingLocation = false
    @State private var step = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if step == 1 {
                        personalAnchorStep
                    } else {
                        shapeTheNightStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(step == 1 ? "Plan with Amora" : "Shape the night")
            .toolbarBackground(AmoraTheme.background, for: .navigationBar)
        }
        .amoraScreen()
    }

    private var personalAnchorStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What would make her feel seen?")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text("Tell us what she likes, notices, avoids, or paste a message or note you want us to consider.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal anchor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    TextField("She mentioned matcha, art books, quiet places...", text: $viewModel.partnerLikes, axis: .vertical)
                        .lineLimit(5...8)
                        .textFieldStyle(.plain)
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan near")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    TextField("Neighborhood or city", text: $viewModel.locationLabel)
                        .textFieldStyle(.plain)

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label(isDetectingLocation ? "Finding your area" : "Use Current Location", systemImage: "location")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmoraTheme.oxblood)
                    }
                    .disabled(isDetectingLocation)
                }
            }

            errorMessageView

            PrimaryButton(title: "Continue", isLoading: false) {
                step = 2
            }
        }
    }

    private var shapeTheNightStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                step = 1
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AmoraTheme.oxblood)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Shape the night")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text("Set the mood and constraints around what would make this feel considered.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Vibe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    Picker("Vibe", selection: $viewModel.vibe) {
                        ForEach(DateVibe.allCases) { vibe in
                            Text(vibe.rawValue.capitalized).tag(vibe)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AmoraTheme.oxblood)
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Budget")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    Picker("Budget", selection: $viewModel.budgetTier) {
                        ForEach(BudgetTier.allCases) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            SurfaceCard {
                Toggle("No drinking", isOn: $viewModel.noDrinking)
                    .tint(AmoraTheme.oxblood)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Duration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    Picker("Duration", selection: $viewModel.durationMinutes) {
                        Text("1.5h").tag(90)
                        Text("2h").tag(120)
                        Text("3h").tag(180)
                        Text("4h").tag(240)
                    }
                    .pickerStyle(.segmented)
                }
            }

            errorMessageView

            PrimaryButton(title: "Build My Sealed Preview", isLoading: viewModel.isLoading) {
                Task { await viewModel.generatePreview() }
            }
        }
    }

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AmoraTheme.oxblood)
        }
    }

    private func useCurrentLocation() async {
        isDetectingLocation = true
        defer { isDetectingLocation = false }

        locationService.requestPermission()
        do {
            let label = try await locationService.currentAreaLabel()
            if !label.isEmpty {
                viewModel.locationLabel = label
            }
        } catch {
            viewModel.errorMessage = "We could not detect your area. Enter it manually."
        }
    }
}

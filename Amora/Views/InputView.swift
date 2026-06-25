import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: PlanViewModel
    @State private var locationService = LocationLabelService()
    @State private var isDetectingLocation = false
    @State private var step = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if step == 1 {
                        personalAnchorStep
                    } else {
                        shapeTheNightStep
                    }
                }
                .padding()
            }
            .navigationTitle(step == 1 ? "Plan with Amora" : "Shape the night")
        }
    }

    private var personalAnchorStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What would make her feel seen?")
                    .font(.title2.weight(.bold))
                Text("Tell us what she likes, notices, avoids, or paste a message or note you want us to consider.")
                    .foregroundStyle(.secondary)
            }

            TextField("She mentioned matcha, art books, quiet places...", text: $viewModel.partnerLikes, axis: .vertical)
                .lineLimit(5...8)
                .textFieldStyle(.roundedBorder)

            Text("Plan near")
                .font(.headline)

            TextField("Neighborhood or city", text: $viewModel.locationLabel)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await useCurrentLocation() }
            } label: {
                Label("Use Current Location", systemImage: "location")
            }
            .disabled(isDetectingLocation)

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
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Shape the night")
                    .font(.title2.weight(.bold))
                Text("Set the mood and constraints around what would make this feel considered.")
                    .foregroundStyle(.secondary)
            }

            Picker("Vibe", selection: $viewModel.vibe) {
                ForEach(DateVibe.allCases) { vibe in
                    Text(vibe.rawValue.capitalized).tag(vibe)
                }
            }
            .pickerStyle(.menu)

            Picker("Budget", selection: $viewModel.budgetTier) {
                ForEach(BudgetTier.allCases) { tier in
                    Text(tier.rawValue).tag(tier)
                }
            }
            .pickerStyle(.segmented)

            Toggle("No drinking", isOn: $viewModel.noDrinking)

            Picker("Duration", selection: $viewModel.durationMinutes) {
                Text("1.5h").tag(90)
                Text("2h").tag(120)
                Text("3h").tag(180)
                Text("4h").tag(240)
            }
            .pickerStyle(.segmented)

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
                .foregroundStyle(.red)
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

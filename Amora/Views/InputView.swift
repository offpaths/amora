import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: PlanViewModel
    @State private var locationService = LocationLabelService()
    @State private var isDetectingLocation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan near") {
                    TextField("Neighborhood or city", text: $viewModel.locationLabel)
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label("Use Current Location", systemImage: "location")
                    }
                    .disabled(isDetectingLocation)
                }

                Section("Budget") {
                    Picker("Budget", selection: $viewModel.budgetTier) {
                        ForEach(BudgetTier.allCases) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Vibe") {
                    Picker("Vibe", selection: $viewModel.vibe) {
                        ForEach(DateVibe.allCases) { vibe in
                            Text(vibe.rawValue.capitalized).tag(vibe)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Date details") {
                    Toggle("No drinking", isOn: $viewModel.noDrinking)
                    Picker("Duration", selection: $viewModel.durationMinutes) {
                        Text("1.5h").tag(90)
                        Text("2h").tag(120)
                        Text("3h").tag(180)
                        Text("4h").tag(240)
                    }
                    .pickerStyle(.segmented)
                }

                Section("What would make this feel personal?") {
                    TextField("She mentioned matcha, art books, quiet places...", text: $viewModel.partnerLikes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                PrimaryButton(title: "Generate Preview", isLoading: viewModel.isLoading) {
                    Task { await viewModel.generatePreview() }
                }
            }
            .navigationTitle("Plan with Amora")
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

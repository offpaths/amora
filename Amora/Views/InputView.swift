import MapKit
import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: PlanViewModel
    let initialStep: Int
    let onPreviewGenerated: () -> Void
    let onReturnToExistingPlan: () -> Void
    @State private var locationService = LocationLabelService()
    @StateObject private var locationSuggestionService = LocationSuggestionService()
    @State private var isDetectingLocation = false
    @State private var step: Int

    init(
        viewModel: PlanViewModel,
        initialStep: Int = 1,
        onPreviewGenerated: @escaping () -> Void = {},
        onReturnToExistingPlan: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.initialStep = initialStep
        self.onPreviewGenerated = onPreviewGenerated
        self.onReturnToExistingPlan = onReturnToExistingPlan
        _step = State(initialValue: initialStep)
    }

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
            .navigationTitle(step == 1 ? "" : "Shape the night")
            .toolbarBackground(AmoraTheme.background, for: .navigationBar)
            .toolbar {
                if step == 1 {
                    ToolbarItem(placement: .principal) {
                        Text.amoraBrand("Plan with Amora", baseColor: AmoraTheme.ink)
                            .font(.headline.weight(.semibold))
                    }
                }
            }
            .onChange(of: initialStep) { _, newStep in
                step = newStep
            }
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
                    TextField("Neighborhood or city", text: locationText)
                        .textFieldStyle(.plain)

                    if !locationSuggestionService.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(locationSuggestionService.suggestions, id: \.self) { suggestion in
                                Button {
                                    Task { await useSuggestion(suggestion) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AmoraTheme.ink)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(AmoraTheme.muted)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 9)
                                }
                                .buttonStyle(.plain)

                                if suggestion != locationSuggestionService.suggestions.last {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(AmoraTheme.background.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AmoraTheme.border, lineWidth: 1)
                        }
                    }

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label(isDetectingLocation ? "Finding your area" : "Detect my area", systemImage: "location")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmoraTheme.oxblood)
                    }
                    .disabled(isDetectingLocation)
                }
            }

            errorMessageView

            returnToExistingPlanButton

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
                    HStack {
                        Text("Budget for two")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AmoraTheme.muted)
                        Spacer()
                        Text(selectedBudgetLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmoraTheme.oxblood)
                    }

                    Slider(
                        value: budgetSliderValue,
                        in: 0...Double(max(viewModel.budgetOptions.count - 1, 0)),
                        step: 1
                    )
                    .tint(AmoraTheme.oxblood)

                    Text("Amora will plan around this amount, not spend it for the sake of it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

            aiDisclosureCard

            errorMessageView

            returnToExistingPlanButton

            PrimaryButton(title: "Create My Date Plan", isLoading: viewModel.isLoading, isDisabled: viewModel.isCreatePlanDisabled) {
                Task {
                    await resolveTypedPlanningAreaIfNeeded()
                    guard viewModel.errorMessage == nil else { return }
                    await viewModel.generatePreview()
                    if viewModel.currentPlan != nil {
                        onPreviewGenerated()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var returnToExistingPlanButton: some View {
        if viewModel.currentPlan != nil {
            SecondaryButton("Back to Plan", systemImage: "chevron.left", action: onReturnToExistingPlan)
        }
    }

    private var aiDisclosureCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.hasAcceptedAIDisclosure) {
                    Text("Amora uses AI to create your plan. Your planning area, preferences, and personal context are sent to our AI provider to generate the result.")
                        .font(.subheadline)
                        .foregroundStyle(AmoraTheme.ink)
                }
                .tint(AmoraTheme.oxblood)

                HStack(spacing: 14) {
                    Link("Privacy", destination: AppConfig.privacyPolicyURL)
                    Link("Terms", destination: AppConfig.termsOfUseURL)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AmoraTheme.oxblood)
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

    private var locationText: Binding<String> {
        Binding(
            get: { viewModel.locationLabel },
            set: { query in
                viewModel.locationLabel = query
                viewModel.planningAreaCountryCode = ""
                locationSuggestionService.update(query: query)
            }
        )
    }

    private var selectedBudgetLabel: String {
        viewModel.budgetOptions.first(where: { $0.amount == viewModel.budgetAmount })?.label
            ?? viewModel.budgetOptions.first?.label
            ?? "USD 100"
    }

    private var budgetSliderValue: Binding<Double> {
        Binding(
            get: {
                Double(viewModel.budgetOptions.firstIndex(where: { $0.amount == viewModel.budgetAmount }) ?? 1)
            },
            set: { newValue in
                let options = viewModel.budgetOptions
                guard !options.isEmpty else { return }
                let index = min(max(Int(newValue.rounded()), 0), options.count - 1)
                viewModel.budgetAmount = options[index].amount
            }
        )
    }

    private func useCurrentLocation() async {
        isDetectingLocation = true
        defer { isDetectingLocation = false }

        locationService.requestPermission()
        do {
            if let area = try await locationService.currentPlanningArea(), !area.label.isEmpty {
                viewModel.setPlanningArea(label: area.label, countryCode: area.countryCode)
            }
        } catch {
            viewModel.errorMessage = "We could not detect your area. Enter it manually."
        }
    }

    private func useSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        do {
            if let area = try await locationSuggestionService.planningArea(for: suggestion) {
                viewModel.setPlanningArea(label: area.label, countryCode: area.countryCode)
            } else {
                viewModel.setPlanningArea(label: locationSuggestionService.label(for: suggestion), countryCode: "")
                viewModel.errorMessage = "Choose a suggested area or enter a more specific city and country."
            }
            locationSuggestionService.clear()
        } catch {
            viewModel.errorMessage = "Choose a suggested area or enter a more specific city and country."
        }
    }

    private func resolveTypedPlanningAreaIfNeeded() async {
        guard viewModel.planningAreaCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.errorMessage = nil
            return
        }

        do {
            if let area = try await locationService.planningArea(for: viewModel.locationLabel) {
                viewModel.setPlanningArea(label: area.label, countryCode: area.countryCode)
                viewModel.errorMessage = nil
            } else {
                viewModel.errorMessage = "Choose a suggested area or enter a more specific city and country."
            }
        } catch {
            viewModel.errorMessage = "Choose a suggested area or enter a more specific city and country."
        }
    }
}

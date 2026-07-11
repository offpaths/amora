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
            .background(AmoraTheme.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AmoraTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .background(AmoraTheme.background.ignoresSafeArea())
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
                        .accessibilityLabel("Personal anchor")
                        .accessibilityHint("Optional details about what would make the date feel personal.")
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan near")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AmoraTheme.muted)
                    TextField("Neighborhood or city", text: locationText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Plan near")
                        .accessibilityHint("Enter a neighborhood or city, or detect your current area.")

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
                            .frame(minHeight: 44)
                    }
                    .disabled(isDetectingLocation)
                }
            }

            errorMessageView

            previousPlanCard

            returnToExistingPlanButton

            PrimaryButton(title: "Continue", isLoading: false) {
                step = 2
            }
        }
    }

    @ViewBuilder
    private var previousPlanCard: some View {
        if viewModel.currentPlan == nil, viewModel.hasSavedUnlockedPlan {
            Button {
                viewModel.returnToSavedUnlockedPlan()
                onReturnToExistingPlan()
            } label: {
                SurfaceCard {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AmoraTheme.oxblood)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Previous plan")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AmoraTheme.ink)
                            Text("Open your latest unlocked plan saved on this device.")
                                .font(.caption)
                                .foregroundStyle(AmoraTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AmoraTheme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
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
                    .frame(minHeight: 44)
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
                    .accessibilityLabel("Budget for two")
                    .accessibilityValue(selectedBudgetLabel)
                    .accessibilityHint("Adjust the approximate spend comfort for the full date.")

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

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AmoraTheme.oxblood)
        }
    }

    private var navigationTitle: String {
        switch step {
        case 1:
            return ""
        default:
            return "Plan with Amora"
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
            } else {
                viewModel.errorMessage = "We could not detect your area. Enter a neighborhood or city instead."
            }
        } catch {
            viewModel.errorMessage = "We could not detect your area. Enter a neighborhood or city instead."
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

# Premium Reveal App Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Amora's two-step premium reveal flow with a stronger personal-anchor prompt and richer preview-stop fields.

**Architecture:** Extend the backend plan schema first so preview stops include `vibe`, `reason`, and `personalizationSignal`. Then update Swift models and tests to decode/render those fields. Finally replace the one-form input screen with a two-step SwiftUI intake while preserving the existing `PlanViewModel` generation and purchase flow.

**Tech Stack:** SwiftUI, XCTest, TypeScript, Zod, Vitest, Cloudflare Worker.

---

## File Structure

- Modify `worker/src/schema.ts`: add required preview stop fields.
- Modify `worker/src/openai.ts`: update prompt contract and pasted-context guidance.
- Modify `worker/test/schema.test.ts`: update valid fixtures and add missing-field rejection checks.
- Modify `worker/test/openai.test.ts`: update fixtures and prompt expectations.
- Modify `Amora/Models/DatePlanModels.swift`: add preview stop properties.
- Modify `AmoraTests/DatePlanModelsTests.swift`: verify decoding new preview fields.
- Modify `AmoraTests/PlanViewModelTests.swift`: update sample plan fixtures.
- Modify `Amora/Views/InputView.swift`: convert current form into two-step intake.
- Modify `Amora/Views/PreviewPlanView.swift`: render sealed itinerary preview fields.
- Modify `Amora/Views/PaywallView.swift`: align paywall copy with reveal/confidence positioning.
- Modify `Amora/Views/Components.swift`: add small reusable UI pieces only if needed by the screens.

## Task 1: Backend Preview Stop Contract

**Files:**
- Modify: `worker/src/schema.ts`
- Modify: `worker/test/schema.test.ts`

- [ ] **Step 1: Update schema tests to require richer preview stops**

In `worker/test/schema.test.ts`, update every `preview.stops` fixture item to include the new fields:

```ts
{ order: 1, concept: "A cozy conversation starter", vibe: "Calm and warm", reason: "A low-pressure first stop gives the date room to settle in.", personalizationSignal: "Matches her interest in quiet places." }
```

Add this test inside `describe("DatePlanResponseSchema", () => { ... })`:

```ts
it("rejects preview stops missing reveal-proof fields", () => {
  const result = DatePlanResponseSchema.safeParse({
    ...validDatePlanResponse,
    preview: {
      ...validDatePlanResponse.preview,
      stops: [
        { order: 1, concept: "A cozy conversation starter" },
        validDatePlanResponse.preview.stops[1],
        validDatePlanResponse.preview.stops[2]
      ]
    }
  });

  expect(result.success).toBe(false);
});
```

- [ ] **Step 2: Run schema tests and verify failure**

Run:

```bash
cd worker
npm test -- schema.test.ts
```

Expected: FAIL because `PreviewStopSchema` does not require `vibe`, `reason`, or `personalizationSignal`.

- [ ] **Step 3: Implement schema change**

In `worker/src/schema.ts`, change `PreviewStopSchema` to:

```ts
export const PreviewStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  concept: z.string().trim().min(8).max(160),
  vibe: z.string().trim().min(4).max(80),
  reason: z.string().trim().min(12).max(220),
  personalizationSignal: z.string().trim().min(8).max(220)
});
```

- [ ] **Step 4: Run schema tests and verify pass**

Run:

```bash
cd worker
npm test -- schema.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit backend schema contract**

```bash
git add worker/src/schema.ts worker/test/schema.test.ts
git commit -m "feat: require richer preview stop fields"
```

## Task 2: Backend Prompt Guidance

**Files:**
- Modify: `worker/src/openai.ts`
- Modify: `worker/test/openai.test.ts`

- [ ] **Step 1: Update OpenAI tests for new fields and prompt requirements**

In `worker/test/openai.test.ts`, update all `validPlan.preview.stops` items to include the same fields as Task 1.

In `it("sends a prompt to the Responses API and parses raw output text", ...)`, replace:

```ts
expect(body.input).toContain("preview.stops: exactly 3 objects with order 1, 2, 3 and concept");
```

with:

```ts
expect(body.input).toContain("preview.stops: exactly 3 objects with order 1, 2, 3, concept, vibe, reason, personalizationSignal");
expect(body.input).toContain("The partner likes field may contain a clean summary or pasted chat/note context.");
expect(body.input).toContain("Extract only date-planning signals that are clearly supported by the provided text.");
expect(body.input).toContain("Do not psychoanalyze, infer sensitive traits, or make claims about the person beyond the provided context.");
```

- [ ] **Step 2: Run OpenAI tests and verify failure**

Run:

```bash
cd worker
npm test -- openai.test.ts
```

Expected: FAIL because prompt text still references only `concept` and lacks pasted-context guardrails.

- [ ] **Step 3: Update prompt**

In `worker/src/openai.ts`, replace the partner-likes lines in `buildPrompt` with:

```ts
`Partner likes or pasted context: ${input.partnerLikes || "not provided"}.`,
"The partner likes field may contain a clean summary or pasted chat/note context.",
"If pasted chat or notes are provided, extract only date-planning signals that are clearly supported by the provided text.",
"Useful signals include likes, dislikes, food or drink preferences, vibe clues, activities or places mentioned, timing clues, comfort constraints, and personal details that can make the plan feel considered.",
"Do not psychoanalyze, infer sensitive traits, or make claims about the person beyond the provided context.",
"Separate strong signals from weak guesses internally; only use weak guesses when phrased cautiously."
```

Replace the schema contract preview line with:

```ts
"preview.stops: exactly 3 objects with order 1, 2, 3, concept, vibe, reason, personalizationSignal",
```

Replace:

```ts
"Use partner likes in the preview concepts and locked-stop reasons when provided.",
```

with:

```ts
"Use the personal context in preview concepts, preview reasons, preview personalization signals, and locked-stop reasons when provided.",
```

- [ ] **Step 4: Run OpenAI tests and verify pass**

Run:

```bash
cd worker
npm test -- openai.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit prompt update**

```bash
git add worker/src/openai.ts worker/test/openai.test.ts
git commit -m "feat: guide pasted context extraction"
```

## Task 3: iOS Model Contract

**Files:**
- Modify: `Amora/Models/DatePlanModels.swift`
- Modify: `AmoraTests/DatePlanModelsTests.swift`
- Modify: `AmoraTests/PlanViewModelTests.swift`

- [ ] **Step 1: Update Swift decoding tests and fixtures**

In `AmoraTests/DatePlanModelsTests.swift`, update preview stops in the JSON fixture:

```json
{ "order": 1, "concept": "A cozy conversation starter", "vibe": "Calm and warm", "reason": "A low-pressure first stop gives the date room to settle in.", "personalizationSignal": "Matches her interest in quiet places." }
```

After decoding, add:

```swift
XCTAssertEqual(plan.preview.stops[0].vibe, "Calm and warm")
XCTAssertEqual(plan.preview.stops[0].reason, "A low-pressure first stop gives the date room to settle in.")
XCTAssertEqual(plan.preview.stops[0].personalizationSignal, "Matches her interest in quiet places.")
```

In `AmoraTests/PlanViewModelTests.swift`, update each `PreviewStop(...)` sample to:

```swift
PreviewStop(
    order: 1,
    concept: "A cozy conversation starter",
    vibe: "Calm and warm",
    reason: "A low-pressure first stop gives the date room to settle in.",
    personalizationSignal: "Matches her interest in quiet places."
)
```

- [ ] **Step 2: Run iOS tests and verify failure**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL because `PreviewStop` does not define the new fields.

- [ ] **Step 3: Implement Swift model fields**

In `Amora/Models/DatePlanModels.swift`, change `PreviewStop` to:

```swift
struct PreviewStop: Codable, Equatable, Identifiable {
    var order: Int
    var concept: String
    var vibe: String
    var reason: String
    var personalizationSignal: String
    var id: Int { order }
}
```

- [ ] **Step 4: Run iOS tests and verify pass**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 5: Commit iOS model contract**

```bash
git add Amora/Models/DatePlanModels.swift AmoraTests/DatePlanModelsTests.swift AmoraTests/PlanViewModelTests.swift
git commit -m "feat: decode richer preview stops"
```

## Task 4: Two-Step Intake UI

**Files:**
- Modify: `Amora/Views/InputView.swift`
- Modify: `Amora/Views/Components.swift` only if needed

- [ ] **Step 1: Add local step state and split input screen**

In `Amora/Views/InputView.swift`, add:

```swift
@State private var step = 1
```

Replace the current single `Form` body with a `NavigationStack` containing:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 24) {
        if step == 1 {
            personalAnchorStep
        } else {
            shapeTheNightStep
        }
    }
    .padding()
}
.navigationTitle(step == 1 ? "Plan with Amora" : "Shape the night")
```

- [ ] **Step 2: Implement Step 1 view**

Add this computed view inside `InputView`:

```swift
private var personalAnchorStep: some View {
    VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
            Text("What would make her feel seen?")
                .font(.largeTitle.bold())
            Text("Tell us what she likes, notices, avoids, or paste a message or note you want us to consider.")
                .font(.body)
                .foregroundStyle(.secondary)
        }

        TextField("She mentioned matcha, art books, quiet places...", text: $viewModel.partnerLikes, axis: .vertical)
            .lineLimit(5...8)
            .textFieldStyle(.roundedBorder)

        VStack(alignment: .leading, spacing: 10) {
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
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }

        PrimaryButton(title: "Continue", isLoading: false) {
            step = 2
        }
    }
}
```

- [ ] **Step 3: Implement Step 2 view**

Add this computed view inside `InputView`:

```swift
private var shapeTheNightStep: some View {
    VStack(alignment: .leading, spacing: 20) {
        Button {
            step = 1
        } label: {
            Label("Back", systemImage: "chevron.left")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Shape the night")
                .font(.largeTitle.bold())
            Text("Set the mood and constraints around what would make this feel considered.")
                .font(.body)
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

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }

        PrimaryButton(title: "Build My Sealed Preview", isLoading: viewModel.isLoading) {
            Task { await viewModel.generatePreview() }
        }
    }
}
```

- [ ] **Step 4: Run iOS tests/build**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 5: Commit intake UI**

```bash
git add Amora/Views/InputView.swift Amora/Views/Components.swift
git commit -m "feat: add two-step date intake"
```

## Task 5: Sealed Itinerary Preview UI

**Files:**
- Modify: `Amora/Views/PreviewPlanView.swift`
- Modify: `Amora/Views/PaywallView.swift`

- [ ] **Step 1: Render richer preview stop fields**

In `Amora/Views/PreviewPlanView.swift`, update the intro copy to:

```swift
Text("Your sealed itinerary is ready. Exact venues, timing, costs, and maps unlock when you reveal the full plan.")
    .font(.subheadline)
    .foregroundStyle(.secondary)
```

Inside each preview stop card, render:

```swift
Text(stop.concept)
    .font(.headline)
PillLabel(text: stop.vibe)
Text(stop.reason)
    .font(.subheadline)
Text(stop.personalizationSignal)
    .font(.caption)
    .foregroundStyle(.secondary)
Label("Exact venue, timing, cost, and maps unlock after purchase", systemImage: "lock.fill")
    .font(.caption)
    .foregroundStyle(.secondary)
```

Change the unlock button label to:

```swift
Button("Reveal Full Plan", action: onUnlock)
```

- [ ] **Step 2: Update paywall copy**

In `Amora/Views/PaywallView.swift`, change the title to:

```swift
Text("Reveal Your Full Date Plan")
```

Change the body copy to:

```swift
Text("Walk in with more confidence and less guesswork. Reveal the exact venues, timing, and reasons behind a plan built to feel considered.")
```

Update labels to include:

```swift
Label("More confidence going into the date", systemImage: "checkmark.seal")
Label("A smoother night with less guesswork", systemImage: "sparkles")
Label("Exact venues", systemImage: "mappin.and.ellipse")
Label("Timing per stop", systemImage: "clock")
Label("Reasons tied to what she likes", systemImage: "heart")
Label("Estimated cost", systemImage: "dollarsign.circle")
Label("Apple Maps actions", systemImage: "map")
```

- [ ] **Step 3: Run iOS tests/build**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Commit preview/paywall UI**

```bash
git add Amora/Views/PreviewPlanView.swift Amora/Views/PaywallView.swift
git commit -m "feat: present sealed itinerary preview"
```

## Task 6: Full Verification

**Files:**
- No source changes expected unless verification finds a bug.

- [ ] **Step 1: Run backend tests**

Run:

```bash
cd worker
npm test
```

Expected: PASS.

- [ ] **Step 2: Run iOS tests**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 3: Build and run app in simulator**

Run:

```bash
xcodebuild -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual flow check**

Open the app in Simulator and verify:

- Step 1 opens with "What would make her feel seen?"
- The text field accepts a written summary or pasted chat/note.
- "Use Current Location" still fills the editable planning area or shows the existing manual-entry error.
- Continue moves to Step 2 without losing entered text.
- Back returns to Step 1 with values preserved.
- Step 2 can generate a preview.
- Preview shows three sealed itinerary stops with concept, vibe, reason, and personalization signal.
- Paywall uses reveal/confidence framing.
- Successful StoreKit test purchase still unlocks the current plan.

- [ ] **Step 5: Commit any verification fixes**

If fixes were needed:

```bash
git add <changed-files>
git commit -m "fix: polish premium reveal flow"
```

If no fixes were needed, do not create an empty commit.

# Budget for Two Slider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the vague `$ / $$ / $$$` budget input with a local-currency budget-for-two stepped control that sends a concrete spend comfort to the backend.

**Architecture:** Keep budget selection as one simple whole-number amount in the iOS app and request payload. Resolve the display/prompt currency from the existing planning-area country code on both iOS and the Worker, using the same country/currency mapping concept already present in the Worker. The backend prompt treats the amount as an approximate comfort limit, not a target to exhaust.

**Tech Stack:** SwiftUI, XCTest, TypeScript, Zod, Vitest, Cloudflare Worker.

---

## Files

- Modify `Amora/Models/DatePlanModels.swift`: remove `BudgetTier`; add `budgetAmount` to `GeneratePlanRequest`; add a small budget catalog for local-currency display steps.
- Modify `Amora/ViewModels/PlanViewModel.swift`: replace `budgetTier` state with `budgetAmount`; keep the selected budget valid when country changes.
- Modify `Amora/Views/InputView.swift`: replace the segmented budget picker with a stepped slider labeled `Budget for two`.
- Modify `AmoraTests/DatePlanModelsTests.swift`: test local-currency budget options and request coding.
- Modify `AmoraTests/PlanViewModelTests.swift`: update defaults and request assertions.
- Modify `AmoraTests/DatePlanClientTests.swift`: update encoded request expectations.
- Modify `worker/src/schema.ts`: replace `budgetTier` schema with `budgetAmount`.
- Modify `worker/src/openai.ts`: prompt with concrete currency amount and spend-comfort guidance.
- Modify `worker/test/schema.test.ts`, `worker/test/openai.test.ts`, and `worker/test/index.test.ts`: update valid requests and prompt expectations.
- Modify `PRD.md` and `DESIGN.md` if implementation uncovers wording that should be synchronized; otherwise leave existing approved docs as-is.

## Task 1: Swift Budget Model

**Files:**
- Modify: `Amora/Models/DatePlanModels.swift`
- Test: `AmoraTests/DatePlanModelsTests.swift`

- [ ] **Step 1: Write failing model tests**

Add these tests to `DatePlanModelsTests`:

```swift
func testBudgetOptionsUseCountryCurrency() {
    let usOptions = BudgetCatalog.options(for: "US")
    XCTAssertEqual(usOptions.map(\.label), ["USD 50", "USD 100", "USD 150", "USD 200", "USD 300+"])
    XCTAssertEqual(usOptions.map(\.amount), [50, 100, 150, 200, 300])

    let thailandOptions = BudgetCatalog.options(for: "TH")
    XCTAssertEqual(thailandOptions.map(\.label), ["THB 1000", "THB 2000", "THB 3500", "THB 5000", "THB 8000+"])
    XCTAssertEqual(thailandOptions.map(\.amount), [1000, 2000, 3500, 5000, 8000])
}

func testBudgetOptionsFallbackToUSD() {
    let options = BudgetCatalog.options(for: "")

    XCTAssertEqual(options.first?.currencyCode, "USD")
    XCTAssertEqual(options.first?.amount, 50)
}

func testGeneratePlanRequestEncodesBudgetAmount() throws {
    let request = GeneratePlanRequest(
        locationLabel: "Williamsburg, Brooklyn",
        countryCode: "US",
        budgetAmount: 100,
        vibe: .cozy,
        noDrinking: true,
        durationMinutes: 120,
        partnerLikes: "bookstores"
    )

    let data = try JSONEncoder().encode(request)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

    XCTAssertEqual(object["budgetAmount"] as? Int, 100)
    XCTAssertNil(object["budgetTier"])
}
```

- [ ] **Step 2: Run the failing Swift model test**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AmoraTests/DatePlanModelsTests
```

Expected: FAIL because `BudgetCatalog` and `budgetAmount` do not exist yet.

- [ ] **Step 3: Implement the minimal model change**

In `Amora/Models/DatePlanModels.swift`, replace `BudgetTier` with:

```swift
struct BudgetOption: Equatable, Identifiable {
    var amount: Int
    var currencyCode: String
    var isOpenEnded: Bool

    var id: String { "\(currencyCode)-\(amount)" }

    var label: String {
        "\(currencyCode) \(amount)\(isOpenEnded ? "+" : "")"
    }
}

enum BudgetCatalog {
    static func currencyCode(for countryCode: String) -> String {
        countryCurrencyMap[countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()] ?? "USD"
    }

    static func options(for countryCode: String) -> [BudgetOption] {
        let currencyCode = currencyCode(for: countryCode)
        let amounts = budgetSteps[currencyCode] ?? budgetSteps["USD"]!
        return amounts.enumerated().map { index, amount in
            BudgetOption(amount: amount, currencyCode: currencyCode, isOpenEnded: index == amounts.count - 1)
        }
    }

    private static let budgetSteps: [String: [Int]] = [
        "USD": [50, 100, 150, 200, 300],
        "GBP": [40, 80, 120, 180, 250],
        "EUR": [50, 90, 140, 200, 300],
        "THB": [1000, 2000, 3500, 5000, 8000]
    ]

    private static let countryCurrencyMap: [String: String] = [
        "AD": "EUR", "AE": "AED", "AT": "EUR", "AU": "AUD", "BE": "EUR", "BR": "BRL",
        "CA": "CAD", "CH": "CHF", "CN": "CNY", "CY": "EUR", "CZ": "CZK", "DE": "EUR",
        "DK": "DKK", "EE": "EUR", "ES": "EUR", "FI": "EUR", "FR": "EUR", "GB": "GBP",
        "GR": "EUR", "HK": "HKD", "HR": "EUR", "HU": "HUF", "IE": "EUR", "IL": "ILS",
        "IN": "INR", "IT": "EUR", "JP": "JPY", "KR": "KRW", "LT": "EUR", "LU": "EUR",
        "LV": "EUR", "MC": "EUR", "MT": "EUR", "MX": "MXN", "MY": "MYR", "NL": "EUR",
        "NO": "NOK", "NZ": "NZD", "PH": "PHP", "PL": "PLN", "PT": "EUR", "SA": "SAR",
        "SE": "SEK", "SG": "SGD", "SI": "EUR", "SK": "EUR", "TH": "THB", "TR": "TRY",
        "TW": "TWD", "US": "USD", "VN": "VND", "ZA": "ZAR"
    ]
}
```

Then change `GeneratePlanRequest` to:

```swift
struct GeneratePlanRequest: Codable, Equatable {
    var locationLabel: String
    var countryCode: String
    var budgetAmount: Int
    var vibe: DateVibe
    var noDrinking: Bool
    var durationMinutes: Int
    var partnerLikes: String
    var regenerationAttempt: Int = 0
}
```

- [ ] **Step 4: Run the Swift model test**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AmoraTests/DatePlanModelsTests
```

Expected: PASS for `DatePlanModelsTests`.

- [ ] **Step 5: Commit**

```bash
git add Amora/Models/DatePlanModels.swift AmoraTests/DatePlanModelsTests.swift
git commit -m "feat: model budget for two amount"
```

## Task 2: View Model Request Flow

**Files:**
- Modify: `Amora/ViewModels/PlanViewModel.swift`
- Test: `AmoraTests/PlanViewModelTests.swift`

- [ ] **Step 1: Write failing view model tests**

Update `testDefaultInputsMatchMVPDefaults`:

```swift
XCTAssertEqual(viewModel.budgetAmount, 100)
```

Remove the old `XCTAssertEqual(viewModel.budgetTier, .medium)`.

Add this test:

```swift
func testSetPlanningAreaKeepsBudgetValidForCountry() {
    let viewModel = PlanViewModel()
    viewModel.budgetAmount = 300

    viewModel.setPlanningArea(label: "Shoreditch, London", countryCode: "GB")

    XCTAssertEqual(viewModel.planningAreaCountryCode, "GB")
    XCTAssertEqual(viewModel.budgetAmount, 250)
}
```

In `testRegenerateUnlockedPlanConsumesOneRegenerate`, add:

```swift
XCTAssertEqual(requests.map(\.budgetAmount), [100, 100])
```

- [ ] **Step 2: Run the failing view model test**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AmoraTests/PlanViewModelTests
```

Expected: FAIL because `PlanViewModel` still exposes `budgetTier`.

- [ ] **Step 3: Implement view model budget amount**

In `PlanViewModel`, replace:

```swift
@Published var budgetTier: BudgetTier = .medium
```

with:

```swift
@Published var budgetAmount = 100
```

Add:

```swift
var budgetOptions: [BudgetOption] {
    BudgetCatalog.options(for: planningAreaCountryCode)
}
```

In `setPlanningArea(label:countryCode:)`, after setting `planningAreaCountryCode`, add:

```swift
if !budgetOptions.contains(where: { $0.amount == budgetAmount }) {
    budgetAmount = budgetOptions[min(1, budgetOptions.count - 1)].amount
}
```

In `makeRequest()`, replace:

```swift
budgetTier: budgetTier,
```

with:

```swift
budgetAmount: budgetAmount,
```

- [ ] **Step 4: Run the view model test**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AmoraTests/PlanViewModelTests
```

Expected: PASS for `PlanViewModelTests`.

- [ ] **Step 5: Commit**

```bash
git add Amora/ViewModels/PlanViewModel.swift AmoraTests/PlanViewModelTests.swift
git commit -m "feat: send budget amount from view model"
```

## Task 3: SwiftUI Budget Control

**Files:**
- Modify: `Amora/Views/InputView.swift`
- Test: existing Swift tests plus simulator build

- [ ] **Step 1: Build to expose current UI compile failures**

Run:

```bash
xcodebuild build -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL because `InputView` still references `BudgetTier`.

- [ ] **Step 2: Replace the budget picker with a stepped slider**

In `InputView.swift`, replace the whole budget `SurfaceCard` with:

```swift
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
```

Add these helpers inside `InputView`:

```swift
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
```

- [ ] **Step 3: Build the app**

Run:

```bash
xcodebuild build -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Run the Swift test suite**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Amora/Views/InputView.swift
git commit -m "feat: add budget for two slider"
```

## Task 4: Swift Client Encoding

**Files:**
- Modify: `AmoraTests/DatePlanClientTests.swift`

- [ ] **Step 1: Update the client test expectations**

In `DatePlanClientTests`, change request construction from:

```swift
budgetTier: .medium,
```

to:

```swift
budgetAmount: 100,
```

Inside the request handler assertion, add:

```swift
XCTAssertEqual(encoded.budgetAmount, 100)
```

- [ ] **Step 2: Run the client test**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AmoraTests/DatePlanClientTests
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add AmoraTests/DatePlanClientTests.swift
git commit -m "test: assert budget amount client payload"
```

## Task 5: Worker Request Schema

**Files:**
- Modify: `worker/src/schema.ts`
- Test: `worker/test/schema.test.ts`, `worker/test/index.test.ts`, `worker/test/openai.test.ts`

- [ ] **Step 1: Write failing worker schema tests**

In every valid request object, replace:

```ts
budgetTier: "$$",
```

with:

```ts
budgetAmount: 100,
```

In `worker/test/schema.test.ts`, update the valid request test assertion:

```ts
expect(result.data.budgetAmount).toBe(100);
```

Add this test:

```ts
it("rejects invalid budget amounts", () => {
  const result = GeneratePlanRequestSchema.safeParse({
    locationLabel: "Williamsburg, Brooklyn",
    budgetAmount: 0,
    countryCode: "US",
    vibe: "cozy",
    noDrinking: true,
    durationMinutes: 120,
    partnerLikes: ""
  });

  expect(result.success).toBe(false);
});
```

- [ ] **Step 2: Run the failing worker schema tests**

Run:

```bash
cd worker && npm test -- schema.test.ts index.test.ts openai.test.ts
```

Expected: FAIL because the Worker still requires `budgetTier`.

- [ ] **Step 3: Implement worker schema change**

In `worker/src/schema.ts`, delete:

```ts
export const BudgetTierSchema = z.enum(["$", "$$", "$$$"]);
```

In `GeneratePlanRequestSchema`, replace:

```ts
budgetTier: BudgetTierSchema,
```

with:

```ts
budgetAmount: z.number().int().min(1).max(1_000_000),
```

- [ ] **Step 4: Run worker schema and route tests**

Run:

```bash
cd worker && npm test -- schema.test.ts index.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/src/schema.ts worker/test/schema.test.ts worker/test/index.test.ts worker/test/openai.test.ts
git commit -m "feat: validate budget amount requests"
```

## Task 6: Worker Prompt

**Files:**
- Modify: `worker/src/openai.ts`
- Test: `worker/test/openai.test.ts`

- [ ] **Step 1: Update prompt tests**

In `worker/test/openai.test.ts`, replace:

```ts
expect(body.input).toContain("Budget tier: $$.");
```

with:

```ts
expect(body.input).toContain("Budget for two: USD 100.");
expect(body.input).toContain("Treat the budget as the user's approximate spend comfort for the full date for two people, not a target to exhaust.");
expect(body.input).toContain("Prefer plans with total estimated cost around or below USD 100 when realistic.");
```

Remove:

```ts
expect(body.input).toContain("The budget tier symbols are relative budget inputs only; do not use $, $$, or $$$ as cost estimate currency.");
```

- [ ] **Step 2: Run the failing prompt test**

Run:

```bash
cd worker && npm test -- openai.test.ts
```

Expected: FAIL because the prompt still says `Budget tier`.

- [ ] **Step 3: Implement prompt copy**

In `buildPrompt`, replace:

```ts
`Budget tier: ${input.budgetTier}.`,
```

with:

```ts
`Budget for two: ${currencyCode} ${input.budgetAmount}.`,
"Treat the budget as the user's approximate spend comfort for the full date for two people, not a target to exhaust.",
`Prefer plans with total estimated cost around or below ${currencyCode} ${input.budgetAmount} when realistic.`,
```

Delete this old line:

```ts
"The budget tier symbols are relative budget inputs only; do not use $, $$, or $$$ as cost estimate currency.",
```

In the regeneration copy, replace:

```ts
"same user preferences, area, budget, and constraints"
```

with the same wording if present; no behavior change is needed.

- [ ] **Step 4: Run worker tests and typecheck**

Run:

```bash
cd worker && npm test && npm run typecheck
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/src/openai.ts worker/test/openai.test.ts
git commit -m "feat: prompt with budget for two"
```

## Task 7: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Run full Swift tests**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 2: Run full Worker tests**

Run:

```bash
cd worker && npm test && npm run typecheck
```

Expected: PASS.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git diff --stat HEAD
git diff HEAD -- Amora/Models/DatePlanModels.swift Amora/ViewModels/PlanViewModel.swift Amora/Views/InputView.swift worker/src/schema.ts worker/src/openai.ts
```

Expected: only budget-for-two related changes are present.

- [ ] **Step 4: Manual UI check**

Build and run the app in Simulator. On the input screen, verify:

- Budget card label is `Budget for two`.
- Selected value displays a currency amount such as `USD 100`.
- Helper copy says `Amora will plan around this amount, not spend it for the sake of it.`
- Moving the slider changes between stepped values.
- Selecting a GB planning area changes the display to `GBP` options.
- Selecting a TH planning area changes the display to `THB` options.

- [ ] **Step 5: Final commit if any verification fixes were needed**

```bash
git add Amora AmoraTests worker
git commit -m "fix: polish budget for two flow"
```

Only run this commit if verification required additional changes after Tasks 1-6.

## Self-Review

- Spec coverage: The plan replaces symbolic budget with a concrete local-currency budget-for-two control, clarifies that the amount is not a spending target, updates backend payload/prompt, and includes verification for low-friction stepped values.
- Placeholder scan: No `TBD`, `TODO`, or unspecified implementation steps remain.
- Type consistency: The request field is consistently named `budgetAmount` in Swift and TypeScript. UI display currency comes from `BudgetCatalog`; Worker prompt currency comes from `resolveCurrencyCode(countryCode)`.
- Scope check: This is one coherent app/worker contract change. No accounts, maps, pricing guarantees, or venue-cost accuracy features are included.

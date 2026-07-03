# Amora MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Amora, a SwiftUI iOS MVP with a Cloudflare Worker backend that generates anonymized date-plan previews and unlocks exact 3-stop plans through StoreKit.

**Architecture:** The iOS app owns input, location labeling, preview/paywall/full-plan UI, StoreKit purchase state, and Apple Maps actions. The Cloudflare Worker owns request validation, OpenAI key custody, OpenAI web-search generation, schema validation, and retryable generation errors.

**Tech Stack:** Swift, SwiftUI, CoreLocation, CLGeocoder, MapKit/Apple Maps URLs, StoreKit 2, URLSession, Cloudflare Workers, TypeScript, Vitest, Zod, OpenAI Responses API.

---

## Assumptions

- App name: Amora.
- Bundle id: `com.planwithamora.Amora`.
- StoreKit product id: `amora_plus_monthly`.
- Worker endpoint during development: `http://127.0.0.1:8787/generate-plan`.
- Production Worker route is configured after the MVP builds locally.
- The iOS project can be scaffolded with Xcode/XcodeBuildMCP during implementation.
- Current events, Google Places, accounts, route optimization, and reservations stay out of scope.

## File Structure

Create these top-level areas:

- `Amora/`: SwiftUI iOS app source.
- `AmoraTests/`: Swift unit tests.
- `Amora.xcodeproj/`: generated iOS project.
- `StoreKit/Amora.storekit`: local StoreKit configuration.
- `worker/`: Cloudflare Worker package.
- `docs/superpowers/plans/`: implementation plan.

Key iOS files:

- `Amora/AmoraApp.swift`: app entry point.
- `Amora/Models/DatePlanModels.swift`: shared request/response/domain models.
- `Amora/Services/DatePlanClient.swift`: URLSession backend client.
- `Amora/Services/LocationLabelService.swift`: CoreLocation/CLGeocoder wrapper.
- `Amora/Services/PurchaseService.swift`: StoreKit product loading and purchase unlock.
- `Amora/ViewModels/PlanViewModel.swift`: input state, generation, unlock, regenerate.
- `Amora/Views/InputView.swift`: input form.
- `Amora/Views/PreviewPlanView.swift`: anonymized preview and paywall CTA.
- `Amora/Views/PaywallView.swift`: $4.99 unlock UI.
- `Amora/Views/UnlockedPlanView.swift`: exact plan details and Apple Maps buttons.
- `Amora/Views/Components.swift`: small reusable UI controls.
- `Amora/Config/AppConfig.swift`: backend URL and product id constants.

Key Worker files:

- `worker/package.json`: scripts and dependencies.
- `worker/wrangler.toml`: Worker config.
- `worker/src/schema.ts`: Zod schemas and types.
- `worker/src/openai.ts`: OpenAI generation and tool-call recovery loop.
- `worker/src/index.ts`: HTTP endpoint.
- `worker/test/schema.test.ts`: schema tests.
- `worker/test/index.test.ts`: endpoint tests with mocked OpenAI.

---

### Task 1: Scaffold Worker Package

**Files:**

- Create: `worker/package.json`
- Create: `worker/tsconfig.json`
- Create: `worker/wrangler.toml`
- Create: `worker/src/schema.ts`
- Create: `worker/src/index.ts`
- Create: `worker/test/schema.test.ts`

- [ ] **Step 1: Create Worker package files**

Create `worker/package.json`:

```json
{
  "name": "amora-worker",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "test": "vitest run",
    "typecheck": "tsc --noEmit",
    "deploy": "wrangler deploy"
  },
  "dependencies": {
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@cloudflare/vitest-pool-workers": "^0.5.2",
    "@cloudflare/workers-types": "^4.20260601.0",
    "typescript": "^5.5.4",
    "vitest": "^2.1.1",
    "wrangler": "^3.90.0"
  }
}
```

Create `worker/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "strict": true,
    "types": ["@cloudflare/workers-types", "vitest/globals"],
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

Create `worker/wrangler.toml`:

```toml
name = "amora-api"
main = "src/index.ts"
compatibility_date = "2026-06-22"
```

- [ ] **Step 2: Write failing schema tests**

Create `worker/test/schema.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  GeneratePlanRequestSchema,
  DatePlanResponseSchema,
} from "../src/schema";

describe("GeneratePlanRequestSchema", () => {
  it("accepts a valid MVP request", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetTier: "$$",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: "bookstores, matcha, quiet places",
    });

    expect(result.success).toBe(true);
  });

  it("rejects unsupported durations", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetTier: "$$",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 95,
      partnerLikes: "",
    });

    expect(result.success).toBe(false);
  });
});

describe("DatePlanResponseSchema", () => {
  it("requires exactly 3 preview and locked stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      id: "plan_123",
      preview: {
        title: "A cozy 2-hour plan near Williamsburg",
        summaryBadges: ["$$", "2 hours", "No bars"],
        stops: [
          { order: 1, concept: "A cozy conversation starter" },
          { order: 2, concept: "A personal activity" },
        ],
      },
      lockedPlan: {
        totalEstimatedCost: "$60-$90",
        stops: [
          {
            order: 1,
            venueName: "Example Cafe",
            address: "123 Example St",
            appleMapsQuery: "Example Cafe 123 Example St",
            durationMinutes: 40,
            reason: "A calm first stop.",
            estimatedCost: "$20-$30",
          },
        ],
      },
    });

    expect(result.success).toBe(false);
  });
});
```

- [ ] **Step 3: Run tests and confirm failure**

Run:

```bash
cd worker
npm install
npm test
```

Expected: tests fail because `../src/schema` does not exist.

- [ ] **Step 4: Implement schemas**

Create `worker/src/schema.ts`:

```ts
import { z } from "zod";

export const BudgetTierSchema = z.enum(["$", "$$", "$$$"]);
export const VibeSchema = z.enum([
  "cozy",
  "adventurous",
  "romantic",
  "low-key",
  "foodie",
  "outdoorsy",
]);
export const DurationMinutesSchema = z.union([
  z.literal(90),
  z.literal(120),
  z.literal(180),
  z.literal(240),
]);

export const GeneratePlanRequestSchema = z.object({
  locationLabel: z.string().trim().min(2).max(120),
  budgetTier: BudgetTierSchema,
  vibe: VibeSchema,
  noDrinking: z.boolean(),
  durationMinutes: DurationMinutesSchema,
  partnerLikes: z.string().trim().max(500).optional().default(""),
});

export const PreviewStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  concept: z.string().trim().min(8).max(160),
});

export const LockedStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  venueName: z.string().trim().min(2).max(120),
  address: z.string().trim().min(2).max(180),
  appleMapsQuery: z.string().trim().min(2).max(220),
  durationMinutes: z.number().int().min(15).max(180),
  reason: z.string().trim().min(12).max(260),
  estimatedCost: z.string().trim().min(1).max(40),
});

export const DatePlanResponseSchema = z.object({
  id: z.string().trim().min(6).max(80),
  preview: z.object({
    title: z.string().trim().min(8).max(120),
    summaryBadges: z.array(z.string().trim().min(1).max(40)).min(2).max(6),
    stops: z.tuple([PreviewStopSchema, PreviewStopSchema, PreviewStopSchema]),
  }),
  lockedPlan: z.object({
    totalEstimatedCost: z.string().trim().min(1).max(40),
    stops: z.tuple([LockedStopSchema, LockedStopSchema, LockedStopSchema]),
  }),
});

export type GeneratePlanRequest = z.infer<typeof GeneratePlanRequestSchema>;
export type DatePlanResponse = z.infer<typeof DatePlanResponseSchema>;
```

Create temporary `worker/src/index.ts`:

```ts
export default {
  async fetch(): Promise<Response> {
    return new Response("Amora API", { status: 200 });
  },
};
```

- [ ] **Step 5: Verify Worker tests pass**

Run:

```bash
cd worker
npm test
npm run typecheck
```

Expected: schema tests pass and TypeScript typecheck passes.

- [ ] **Step 6: Commit**

```bash
git add worker/package.json worker/tsconfig.json worker/wrangler.toml worker/src/schema.ts worker/src/index.ts worker/test/schema.test.ts
git commit -m "test: add worker plan schemas"
```

---

### Task 2: Implement Worker Endpoint With Mockable Generator

**Files:**

- Create: `worker/src/openai.ts`
- Modify: `worker/src/index.ts`
- Create: `worker/test/index.test.ts`

- [ ] **Step 1: Write endpoint tests with a fake generator**

Create `worker/test/index.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import type { DatePlanResponse, GeneratePlanRequest } from "../src/schema";

const validRequest: GeneratePlanRequest = {
  locationLabel: "Williamsburg, Brooklyn",
  budgetTier: "$$",
  vibe: "cozy",
  noDrinking: true,
  durationMinutes: 120,
  partnerLikes: "bookstores, matcha, quiet places",
};

const validPlan: DatePlanResponse = {
  id: "plan_test_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["$$", "2 hours", "No bars", "Matched to bookstores"],
    stops: [
      { order: 1, concept: "A cozy conversation starter near Williamsburg" },
      { order: 2, concept: "A personal activity matched to bookstores" },
      { order: 3, concept: "A relaxed dessert finish nearby" },
    ],
  },
  lockedPlan: {
    totalEstimatedCost: "$60-$90",
    stops: [
      {
        order: 1,
        venueName: "Example Cafe",
        address: "123 Example St",
        appleMapsQuery: "Example Cafe 123 Example St",
        durationMinutes: 35,
        reason: "A calm first stop that fits the cozy vibe.",
        estimatedCost: "$20-$30",
      },
      {
        order: 2,
        venueName: "Example Bookstore",
        address: "456 Example Ave",
        appleMapsQuery: "Example Bookstore 456 Example Ave",
        durationMinutes: 50,
        reason: "A personal stop aligned with her interests.",
        estimatedCost: "$10-$25",
      },
      {
        order: 3,
        venueName: "Example Dessert Bar",
        address: "789 Example Rd",
        appleMapsQuery: "Example Dessert Bar 789 Example Rd",
        durationMinutes: 35,
        reason: "A relaxed finish that keeps the date low-pressure.",
        estimatedCost: "$30-$35",
      },
    ],
  },
};

vi.mock("../src/openai", () => ({
  generateDatePlan: vi.fn(async () => validPlan),
}));

describe("POST /generate-plan", () => {
  it("returns a generated plan for a valid request", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: { "content-type": "application/json" },
      }),
      { OPENAI_API_KEY: "test-key" },
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(validPlan);
  });

  it("rejects invalid request bodies", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify({ ...validRequest, durationMinutes: 95 }),
        headers: { "content-type": "application/json" },
      }),
      { OPENAI_API_KEY: "test-key" },
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      error: "invalid_request",
    });
  });
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```bash
cd worker
npm test
```

Expected: endpoint tests fail because `generateDatePlan` and endpoint routing are not implemented.

- [ ] **Step 3: Implement endpoint and generator boundary**

Create `worker/src/openai.ts`:

```ts
import {
  DatePlanResponseSchema,
  type DatePlanResponse,
  type GeneratePlanRequest,
} from "./schema";

export interface Env {
  OPENAI_API_KEY: string;
}

export async function generateDatePlan(
  input: GeneratePlanRequest,
  env: Env,
): Promise<DatePlanResponse> {
  if (!env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const prompt = buildPrompt(input);
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      tools: [{ type: "web_search" }],
      input: prompt,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI request failed with ${response.status}`);
  }

  const payload: unknown = await response.json();
  const candidate = extractJsonCandidate(payload);
  return DatePlanResponseSchema.parse(candidate);
}

export function buildPrompt(input: GeneratePlanRequest): string {
  return [
    "Generate a premium date plan for Amora.",
    "Return only valid JSON matching the required plan schema.",
    `Planning area: ${input.locationLabel}. Treat this as the planning area, not the whole metro region.`,
    "Prefer stops close to this area and close enough for a short walk or short rideshare.",
    `Budget tier: ${input.budgetTier}.`,
    `Vibe: ${input.vibe}.`,
    `Duration: ${input.durationMinutes} minutes.`,
    `No drinking: ${input.noDrinking ? "yes, avoid alcohol-centered stops" : "no"}.`,
    `Partner likes: ${input.partnerLikes || "not provided"}.`,
    "Do not include current events. Do not reveal exact venues in preview concepts.",
    "Return exactly 3 preview stops and exactly 3 locked stops.",
  ].join("\n");
}

function extractJsonCandidate(payload: unknown): unknown {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "output_text" in payload
  ) {
    const text = String((payload as { output_text: unknown }).output_text);
    return JSON.parse(text);
  }
  throw new Error("No JSON candidate found in OpenAI response");
}
```

Modify `worker/src/index.ts`:

```ts
import { generateDatePlan, type Env } from "./openai";
import { GeneratePlanRequestSchema } from "./schema";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return json({}, 204);
    }

    if (request.method !== "POST" || url.pathname !== "/generate-plan") {
      return json({ error: "not_found" }, 404);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const parsed = GeneratePlanRequestSchema.safeParse(body);
    if (!parsed.success) {
      return json({ error: "invalid_request" }, 400);
    }

    try {
      const plan = await generateDatePlan(parsed.data, env);
      return json(plan, 200);
    } catch {
      return json({ error: "generation_failed", retryable: true }, 502);
    }
  },
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "POST, OPTIONS",
      "access-control-allow-headers": "content-type",
    },
  });
}
```

- [ ] **Step 4: Verify endpoint tests pass**

Run:

```bash
cd worker
npm test
npm run typecheck
```

Expected: all Worker tests pass.

- [ ] **Step 5: Commit**

```bash
git add worker/src/openai.ts worker/src/index.ts worker/test/index.test.ts
git commit -m "feat: add worker generate plan endpoint"
```

---

### Task 3: Add Self-Recovering Structured Output Loop

**Files:**

- Modify: `worker/src/openai.ts`
- Create: `worker/test/openai.test.ts`

- [ ] **Step 1: Write tests for recovery loop behavior**

Create `worker/test/openai.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  buildRecoveryPrompt,
  parsePlanCandidate,
  runRecoveryLoop,
} from "../src/openai";

const validPlan = {
  id: "plan_test_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["$$", "2 hours", "No bars"],
    stops: [
      { order: 1, concept: "A cozy conversation starter" },
      { order: 2, concept: "A bookstore-aligned activity" },
      { order: 3, concept: "A relaxed dessert finish" },
    ],
  },
  lockedPlan: {
    totalEstimatedCost: "$60-$90",
    stops: [
      {
        order: 1,
        venueName: "A",
        address: "1 St",
        appleMapsQuery: "A 1 St",
        durationMinutes: 35,
        reason: "A thoughtful first stop.",
        estimatedCost: "$20-$30",
      },
      {
        order: 2,
        venueName: "B",
        address: "2 St",
        appleMapsQuery: "B 2 St",
        durationMinutes: 50,
        reason: "A thoughtful second stop.",
        estimatedCost: "$10-$25",
      },
      {
        order: 3,
        venueName: "C",
        address: "3 St",
        appleMapsQuery: "C 3 St",
        durationMinutes: 35,
        reason: "A thoughtful final stop.",
        estimatedCost: "$30-$35",
      },
    ],
  },
};

describe("parsePlanCandidate", () => {
  it("accepts a valid candidate", () => {
    expect(parsePlanCandidate(validPlan)).toEqual(validPlan);
  });

  it("throws a retryable error for invalid candidates", () => {
    expect(() =>
      parsePlanCandidate({ ...validPlan, lockedPlan: { stops: [] } }),
    ).toThrow("invalid_plan_schema");
  });
});

describe("buildRecoveryPrompt", () => {
  it("includes validation feedback and the original prompt", () => {
    const prompt = buildRecoveryPrompt(
      "original prompt",
      "lockedPlan.stops must contain 3 items",
    );
    expect(prompt).toContain("original prompt");
    expect(prompt).toContain("lockedPlan.stops must contain 3 items");
  });
});

describe("runRecoveryLoop", () => {
  it("returns a valid plan after an invalid attempt", async () => {
    let calls = 0;
    const result = await runRecoveryLoop("original prompt", async () => {
      calls += 1;
      return calls === 1
        ? { ...validPlan, lockedPlan: { stops: [] } }
        : validPlan;
    });

    expect(result).toEqual(validPlan);
    expect(calls).toBe(2);
  });

  it("stops after 5 invalid attempts", async () => {
    await expect(
      runRecoveryLoop("original prompt", async () => ({
        ...validPlan,
        lockedPlan: { stops: [] },
      })),
    ).rejects.toThrow("invalid_plan_schema");
  });
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```bash
cd worker
npm test
```

Expected: fails because `parsePlanCandidate`, `buildRecoveryPrompt`, and `runRecoveryLoop` do not exist.

- [ ] **Step 3: Implement bounded recovery loop**

Modify `worker/src/openai.ts`:

```ts
import {
  DatePlanResponseSchema,
  type DatePlanResponse,
  type GeneratePlanRequest,
} from "./schema";

export interface Env {
  OPENAI_API_KEY: string;
}

export async function generateDatePlan(
  input: GeneratePlanRequest,
  env: Env,
): Promise<DatePlanResponse> {
  if (!env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const initialPrompt = buildPrompt(input);
  return runRecoveryLoop(initialPrompt, (prompt) =>
    callOpenAIForJson(prompt, env),
  );
}

async function callOpenAIForJson(prompt: string, env: Env): Promise<unknown> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      tools: [{ type: "web_search" }],
      input: prompt,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI request failed with ${response.status}`);
  }

  const payload: unknown = await response.json();
  return extractJsonCandidate(payload);
}

export async function runRecoveryLoop(
  initialPrompt: string,
  generateCandidate: (prompt: string) => Promise<unknown>,
): Promise<DatePlanResponse> {
  let prompt = initialPrompt;
  let lastError = "invalid_plan_schema";

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    const candidate = await generateCandidate(prompt);
    try {
      return parsePlanCandidate(candidate);
    } catch (error) {
      lastError =
        error instanceof Error ? error.message : "invalid_plan_schema";
      prompt = buildRecoveryPrompt(initialPrompt, lastError);
    }
  }

  throw new Error(lastError);
}

export function parsePlanCandidate(candidate: unknown): DatePlanResponse {
  const parsed = DatePlanResponseSchema.safeParse(candidate);
  if (parsed.success) {
    return parsed.data;
  }
  throw new Error("invalid_plan_schema");
}

export function buildRecoveryPrompt(
  originalPrompt: string,
  validationError: string,
): string {
  return [
    originalPrompt,
    "",
    "The previous response failed schema validation.",
    `Validation error: ${validationError}`,
    "Correct the response and return a complete valid plan with exactly 3 preview stops and exactly 3 locked stops.",
  ].join("\n");
}

export function buildPrompt(input: GeneratePlanRequest): string {
  return [
    "Generate a premium date plan for Amora.",
    "Return only valid JSON matching the required plan schema.",
    "If validation feedback is provided, correct the response and try again.",
    "Maximum recovery steps are handled by the server; keep each attempt concise.",
    `Planning area: ${input.locationLabel}. Treat this as the planning area, not the whole metro region.`,
    "Prefer stops close to this area and close enough for a short walk or short rideshare.",
    `Budget tier: ${input.budgetTier}.`,
    `Vibe: ${input.vibe}.`,
    `Duration: ${input.durationMinutes} minutes.`,
    `No drinking: ${input.noDrinking ? "yes, avoid alcohol-centered stops" : "no"}.`,
    `Partner likes: ${input.partnerLikes || "not provided"}.`,
    "Do not include current events. Do not reveal exact venues in preview concepts.",
    "Return exactly 3 preview stops and exactly 3 locked stops.",
  ].join("\n");
}

function extractJsonCandidate(payload: unknown): unknown {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "output_text" in payload
  ) {
    const text = String((payload as { output_text: unknown }).output_text);
    return JSON.parse(text);
  }
  throw new Error("No JSON candidate found in OpenAI response");
}
```

- [ ] **Step 4: Verify tests**

Run:

```bash
cd worker
npm test
npm run typecheck
```

Expected: all Worker tests pass.

- [ ] **Step 5: Commit**

```bash
git add worker/src/openai.ts worker/test/openai.test.ts
git commit -m "test: validate generated plan recovery path"
```

---

### Task 4: Scaffold iOS Project And Domain Models

**Files:**

- Create: `Amora.xcodeproj/`
- Create: `Amora/AmoraApp.swift`
- Create: `Amora/Config/AppConfig.swift`
- Create: `Amora/Models/DatePlanModels.swift`
- Create: `AmoraTests/DatePlanModelsTests.swift`
- Create: `StoreKit/Amora.storekit`

- [ ] **Step 1: Scaffold SwiftUI iOS app**

Use Xcode or XcodeBuildMCP to create an iOS SwiftUI app:

- Product name: `Amora`
- Bundle id: `com.planwithamora.Amora`
- Language: Swift
- Interface: SwiftUI
- Tests: Unit tests enabled

Expected created paths:

```text
Amora.xcodeproj
Amora/AmoraApp.swift
Amora/ContentView.swift
AmoraTests/
```

- [ ] **Step 2: Create StoreKit configuration**

Create `StoreKit/Amora.storekit` in Xcode with one auto-renewable subscription product:

- Reference Name: `Amora Plus Monthly`
- Product ID: `amora_plus_monthly`
- Type: Auto-Renewable Subscription
- Price: `9.99`

- [ ] **Step 3: Write model tests**

Create `AmoraTests/DatePlanModelsTests.swift`:

```swift
import XCTest
@testable import Amora

final class DatePlanModelsTests: XCTestCase {
    func testDecodeValidPlanResponse() throws {
        let json = """
        {
          "id": "plan_test_123",
          "preview": {
            "title": "A cozy 2-hour plan near Williamsburg",
            "summaryBadges": ["$$", "2 hours", "No bars"],
            "stops": [
              { "order": 1, "concept": "A cozy conversation starter" },
              { "order": 2, "concept": "A personal activity" },
              { "order": 3, "concept": "A relaxed dessert finish" }
            ]
          },
          "lockedPlan": {
            "totalEstimatedCost": "$60-$90",
            "stops": [
              { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "$20-$30" },
              { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "$10-$25" },
              { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "$30-$35" }
            ]
          }
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(DatePlanResponse.self, from: json)

        XCTAssertEqual(plan.preview.stops.count, 3)
        XCTAssertEqual(plan.lockedPlan.stops.count, 3)
        XCTAssertEqual(plan.lockedPlan.totalEstimatedCost, "$60-$90")
    }
}
```

- [ ] **Step 4: Run test and confirm failure**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: test fails because `DatePlanResponse` is not defined.

- [ ] **Step 5: Implement models and config**

Create `Amora/Config/AppConfig.swift`:

```swift
import Foundation

enum AppConfig {
    static let backendBaseURL = URL(string: "http://127.0.0.1:8787")!
    static let plusMonthlyProductID = "amora_plus_monthly"
}
```

Create `Amora/Models/DatePlanModels.swift`:

```swift
import Foundation

enum BudgetTier: String, Codable, CaseIterable, Identifiable {
    case low = "$"
    case medium = "$$"
    case high = "$$$"

    var id: String { rawValue }
}

enum DateVibe: String, Codable, CaseIterable, Identifiable {
    case cozy
    case adventurous
    case romantic
    case lowKey = "low-key"
    case foodie
    case outdoorsy

    var id: String { rawValue }
}

struct GeneratePlanRequest: Codable, Equatable {
    var locationLabel: String
    var budgetTier: BudgetTier
    var vibe: DateVibe
    var noDrinking: Bool
    var durationMinutes: Int
    var partnerLikes: String
}

struct DatePlanResponse: Codable, Equatable, Identifiable {
    var id: String
    var preview: PlanPreview
    var lockedPlan: LockedPlan
}

struct PlanPreview: Codable, Equatable {
    var title: String
    var summaryBadges: [String]
    var stops: [PreviewStop]
}

struct PreviewStop: Codable, Equatable, Identifiable {
    var order: Int
    var concept: String
    var id: Int { order }
}

struct LockedPlan: Codable, Equatable {
    var totalEstimatedCost: String
    var stops: [LockedStop]
}

struct LockedStop: Codable, Equatable, Identifiable {
    var order: Int
    var venueName: String
    var address: String
    var appleMapsQuery: String
    var durationMinutes: Int
    var reason: String
    var estimatedCost: String
    var id: Int { order }
}
```

- [ ] **Step 6: Verify tests pass**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: model tests pass.

- [ ] **Step 7: Commit**

```bash
git add Amora.xcodeproj Amora AmoraTests StoreKit
git commit -m "test: add iOS app models"
```

---

### Task 5: Implement iOS Backend Client

**Files:**

- Create: `Amora/Services/DatePlanClient.swift`
- Create: `AmoraTests/DatePlanClientTests.swift`

- [ ] **Step 1: Write client tests with URLProtocol stub**

Create `AmoraTests/DatePlanClientTests.swift`:

```swift
import XCTest
@testable import Amora

final class DatePlanClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testGeneratePlanEncodesRequestAndDecodesResponse() async throws {
        let responseJSON = """
        {
          "id": "plan_test_123",
          "preview": {
            "title": "A cozy 2-hour plan near Williamsburg",
            "summaryBadges": ["$$", "2 hours", "No bars"],
            "stops": [
              { "order": 1, "concept": "A cozy conversation starter" },
              { "order": 2, "concept": "A personal activity" },
              { "order": 3, "concept": "A relaxed dessert finish" }
            ]
          },
          "lockedPlan": {
            "totalEstimatedCost": "$60-$90",
            "stops": [
              { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "$20-$30" },
              { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "$10-$25" },
              { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "$30-$35" }
            ]
          }
        }
        """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/generate-plan")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(request.httpBody)
            let encoded = try JSONDecoder().decode(GeneratePlanRequest.self, from: body)
            XCTAssertEqual(encoded.locationLabel, "Williamsburg, Brooklyn")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseJSON)
        }

        let client = DatePlanClient(baseURL: URL(string: "https://example.com")!, session: .stubbed)
        let plan = try await client.generatePlan(
            GeneratePlanRequest(
                locationLabel: "Williamsburg, Brooklyn",
                budgetTier: .medium,
                vibe: .cozy,
                noDrinking: true,
                durationMinutes: 120,
                partnerLikes: "bookstores"
            )
        )

        XCTAssertEqual(plan.id, "plan_test_123")
        XCTAssertEqual(plan.lockedPlan.stops.count, 3)
    }

    func testGeneratePlanThrowsGenerationFailedForBackendError() async {
        URLProtocolStub.requestHandler = { request in
            let data = #"{"error":"generation_failed","retryable":true}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = DatePlanClient(baseURL: URL(string: "https://example.com")!, session: .stubbed)

        do {
            _ = try await client.generatePlan(
                GeneratePlanRequest(
                    locationLabel: "Williamsburg, Brooklyn",
                    budgetTier: .medium,
                    vibe: .cozy,
                    noDrinking: true,
                    durationMinutes: 120,
                    partnerLikes: ""
                )
            )
            XCTFail("Expected generationFailed")
        } catch let error as DatePlanClientError {
            XCTAssertEqual(error, .generationFailed)
        } catch {
            XCTFail("Unexpected error: \\(error)")
        }
    }
}

final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static var stubbed: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}
```

- [ ] **Step 2: Run test and confirm failure**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: fails because `DatePlanClient` does not exist.

- [ ] **Step 3: Implement client**

Create `Amora/Services/DatePlanClient.swift`:

```swift
import Foundation

enum DatePlanClientError: Error, Equatable {
    case invalidResponse
    case generationFailed
}

struct DatePlanClient {
    var baseURL: URL
    var session: URLSession = .shared

    func generatePlan(_ request: GeneratePlanRequest) async throws -> DatePlanResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("generate-plan"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatePlanClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DatePlanClientError.generationFailed
        }

        return try JSONDecoder().decode(DatePlanResponse.self, from: data)
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: client tests pass.

- [ ] **Step 5: Commit**

```bash
git add Amora/Services/DatePlanClient.swift AmoraTests/DatePlanClientTests.swift
git commit -m "test: add date plan client"
```

---

### Task 6: Implement Location Label Service

**Files:**

- Create: `Amora/Services/LocationLabelService.swift`
- Create: `AmoraTests/LocationLabelServiceTests.swift`

- [ ] **Step 1: Write pure formatter tests**

Create `AmoraTests/LocationLabelServiceTests.swift`:

```swift
import XCTest
@testable import Amora

final class LocationLabelServiceTests: XCTestCase {
    func testPrefersNeighborhoodOverCity() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: "Williamsburg", locality: "Brooklyn", administrativeArea: "NY"),
            "Williamsburg, Brooklyn"
        )
    }

    func testFallsBackToCityAndState() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: nil, locality: "Austin", administrativeArea: "TX"),
            "Austin, TX"
        )
    }

    func testFallsBackToRegionOnly() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: nil, locality: nil, administrativeArea: "CA"),
            "CA"
        )
    }
}
```

- [ ] **Step 2: Run test and confirm failure**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: fails because `LocationLabelFormatter` does not exist.

- [ ] **Step 3: Implement location label service**

Create `Amora/Services/LocationLabelService.swift`:

```swift
import CoreLocation
import Foundation

enum LocationLabelFormatter {
    static func label(from placemark: CLPlacemark) -> String {
        label(
            subLocality: placemark.subLocality,
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea
        )
    }

    static func label(subLocality: String?, locality: String?, administrativeArea: String?) -> String {
        if let subLocality, let locality {
            return "\(subLocality), \(locality)"
        }
        if let locality, let administrativeArea {
            return "\(locality), \(administrativeArea)"
        }
        if let locality {
            return locality
        }
        if let administrativeArea {
            return administrativeArea
        }
        return ""
    }
}

@MainActor
final class LocationLabelService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func currentAreaLabel() async throws -> String {
        guard let location = manager.location else {
            return ""
        }
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first.map(LocationLabelFormatter.label(from:)) ?? ""
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: formatter tests pass.

- [ ] **Step 5: Commit**

```bash
git add Amora/Services/LocationLabelService.swift AmoraTests/LocationLabelServiceTests.swift
git commit -m "test: add editable area label support"
```

---

### Task 7: Implement View Model State

**Files:**

- Create: `Amora/ViewModels/PlanViewModel.swift`
- Create: `AmoraTests/PlanViewModelTests.swift`

- [ ] **Step 1: Write view model tests**

Create `AmoraTests/PlanViewModelTests.swift`:

```swift
import XCTest
@testable import Amora

@MainActor
final class PlanViewModelTests: XCTestCase {
    func testDefaultInputsMatchMVPDefaults() {
        let viewModel = PlanViewModel()

        XCTAssertEqual(viewModel.budgetTier, .medium)
        XCTAssertEqual(viewModel.vibe, .cozy)
        XCTAssertTrue(viewModel.noDrinking)
        XCTAssertEqual(viewModel.durationMinutes, 120)
    }

    func testGeneratePreviewStoresPlan() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_one")
        XCTAssertFalse(viewModel.isUnlocked)
    }

    func testUnlockCurrentPlanEnablesOneRegenerate() async {
        let viewModel = PlanViewModel(generate: { _ in Self.samplePlan(id: "plan_one") })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()

        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertTrue(viewModel.canRegenerateUnlockedPlan)
    }

    func testRegenerateUnlockedPlanConsumesOneRegenerate() async {
        var count = 0
        let viewModel = PlanViewModel(generate: { _ in
            count += 1
            return Self.samplePlan(id: "plan_\\(count)")
        })
        viewModel.locationLabel = "Williamsburg, Brooklyn"

        await viewModel.generatePreview()
        viewModel.unlockCurrentPlan()
        await viewModel.regenerateUnlockedPlan()

        XCTAssertEqual(viewModel.currentPlan?.id, "plan_2")
        XCTAssertTrue(viewModel.isUnlocked)
        XCTAssertFalse(viewModel.canRegenerateUnlockedPlan)
    }

    private static func samplePlan(id: String) -> DatePlanResponse {
        DatePlanResponse(
            id: id,
            preview: PlanPreview(
                title: "A cozy 2-hour plan near Williamsburg",
                summaryBadges: ["$$", "2 hours", "No bars"],
                stops: [
                    PreviewStop(order: 1, concept: "A cozy conversation starter"),
                    PreviewStop(order: 2, concept: "A personal activity"),
                    PreviewStop(order: 3, concept: "A relaxed dessert finish")
                ]
            ),
            lockedPlan: LockedPlan(
                totalEstimatedCost: "$60-$90",
                stops: [
                    LockedStop(order: 1, venueName: "A", address: "1 St", appleMapsQuery: "A 1 St", durationMinutes: 35, reason: "A thoughtful first stop.", estimatedCost: "$20-$30"),
                    LockedStop(order: 2, venueName: "B", address: "2 St", appleMapsQuery: "B 2 St", durationMinutes: 50, reason: "A thoughtful second stop.", estimatedCost: "$10-$25"),
                    LockedStop(order: 3, venueName: "C", address: "3 St", appleMapsQuery: "C 3 St", durationMinutes: 35, reason: "A thoughtful final stop.", estimatedCost: "$30-$35")
                ]
            )
        )
    }
}
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: fails because `PlanViewModel` does not exist.

- [ ] **Step 3: Implement view model with injectable client**

Create `Amora/ViewModels/PlanViewModel.swift`:

```swift
import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var locationLabel = ""
    @Published var budgetTier: BudgetTier = .medium
    @Published var vibe: DateVibe = .cozy
    @Published var noDrinking = true
    @Published var durationMinutes = 120
    @Published var partnerLikes = ""
    @Published var currentPlan: DatePlanResponse?
    @Published var isUnlocked = false
    @Published var remainingUnlockedRegenerates = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let generate: (GeneratePlanRequest) async throws -> DatePlanResponse

    init(generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
        try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
    }) {
        self.generate = generate
    }

    var canRegenerateUnlockedPlan: Bool {
        isUnlocked && remainingUnlockedRegenerates > 0
    }

    func generatePreview() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentPlan = try await generate(makeRequest())
            isUnlocked = false
            remainingUnlockedRegenerates = 0
        } catch {
            errorMessage = "We could not generate a plan. Try again."
        }
    }

    func unlockCurrentPlan() {
        guard currentPlan != nil else { return }
        isUnlocked = true
        remainingUnlockedRegenerates = 1
    }

    func regenerateUnlockedPlan() async {
        guard canRegenerateUnlockedPlan else { return }
        remainingUnlockedRegenerates -= 1
        await generatePreview()
        isUnlocked = true
    }

    private func makeRequest() -> GeneratePlanRequest {
        GeneratePlanRequest(
            locationLabel: locationLabel,
            budgetTier: budgetTier,
            vibe: vibe,
            noDrinking: noDrinking,
            durationMinutes: durationMinutes,
            partnerLikes: partnerLikes
        )
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run:

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: view model tests pass.

- [ ] **Step 5: Commit**

```bash
git add Amora/ViewModels/PlanViewModel.swift AmoraTests/PlanViewModelTests.swift
git commit -m "test: add plan view model state"
```

---

### Task 8: Implement StoreKit Purchase Service

**Files:**

- Create: `Amora/Services/PurchaseService.swift`
- Modify: `Amora/ViewModels/PlanViewModel.swift`

- [ ] **Step 1: Add purchase service**

Create `Amora/Services/PurchaseService.swift`:

```swift
import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var product: Product?

    func loadProduct() async {
        do {
            product = try await Product.products(for: [AppConfig.unlockProductID]).first
        } catch {
            product = nil
        }
    }

    func purchaseUnlock() async -> Bool {
        guard let product else { return false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified = verification {
                return true
            }
            return false
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 2: Wire purchase into view model**

Add this method to `PlanViewModel`:

```swift
func completePurchase(success: Bool) {
    if success {
        unlockCurrentPlan()
    }
}
```

- [ ] **Step 3: Verify build**

Run:

```bash
xcodebuild build -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Amora/Services/PurchaseService.swift Amora/ViewModels/PlanViewModel.swift StoreKit/Amora.storekit
git commit -m "feat: add StoreKit unlock service"
```

---

### Task 9: Build SwiftUI Screens

**Files:**

- Modify: `Amora/ContentView.swift`
- Create: `Amora/Views/InputView.swift`
- Create: `Amora/Views/PreviewPlanView.swift`
- Create: `Amora/Views/PaywallView.swift`
- Create: `Amora/Views/UnlockedPlanView.swift`
- Create: `Amora/Views/Components.swift`

- [ ] **Step 1: Create reusable UI components**

Create `Amora/Views/Components.swift`:

```swift
import SwiftUI

struct PillLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
}
```

- [ ] **Step 2: Implement input screen**

Create `Amora/Views/InputView.swift`:

```swift
import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: PlanViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan near") {
                    TextField("Neighborhood or city", text: $viewModel.locationLabel)
                        .textInputAutocapitalization(.words)
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

                Section("What does she like?") {
                    TextField("Bookstores, matcha, quiet places", text: $viewModel.partnerLikes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                PrimaryButton(title: "Generate preview", isLoading: viewModel.isLoading) {
                    Task { await viewModel.generatePreview() }
                }
            }
            .navigationTitle("Plan with Amora")
        }
    }
}
```

- [ ] **Step 3: Implement preview screen**

Create `Amora/Views/PreviewPlanView.swift`:

```swift
import SwiftUI

struct PreviewPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    let onUnlock: () -> Void

    var body: some View {
        guard let plan = viewModel.currentPlan else {
            return AnyView(InputView(viewModel: viewModel))
        }

        return AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(plan.preview.title)
                        .font(.largeTitle.bold())

                    FlowBadges(badges: plan.preview.summaryBadges)

                    VStack(spacing: 12) {
                        ForEach(plan.preview.stops) { stop in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Stop \(stop.order)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(stop.concept)
                                    .font(.headline)
                                Label("Exact venue, timing, cost, and Maps unlock after purchase", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Button("Unlock full plan", action: onUnlock)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                    Button("Regenerate preview") {
                        Task { await viewModel.generatePreview() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        )
    }
}

struct FlowBadges: View {
    let badges: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(badges, id: \.self) { badge in
                PillLabel(text: badge)
            }
        }
    }
}
```

- [ ] **Step 4: Implement paywall screen**

Create `Amora/Views/PaywallView.swift`:

```swift
import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchaseService: PurchaseService
    let onPurchased: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Start Amora Plus")
                .font(.largeTitle.bold())

            Text("Make the money you are already spending on the date worth it by planning something that helps her feel seen.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label("Exact venues", systemImage: "mappin.and.ellipse")
                Label("Timing per stop", systemImage: "clock")
                Label("Reasons that match her interests", systemImage: "heart")
                Label("Estimated cost", systemImage: "dollarsign.circle")
                Label("Apple Maps actions", systemImage: "map")
            }

            Spacer()

            Button(purchaseService.product?.displayPrice ?? "$4.99") {
                Task {
                    let success = await purchaseService.purchaseUnlock()
                    onPurchased(success)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .task {
            await purchaseService.loadProduct()
        }
    }
}

```

- [ ] **Step 5: Implement unlocked plan screen**

Create `Amora/Views/UnlockedPlanView.swift`:

```swift
import SwiftUI

struct UnlockedPlanView: View {
    @ObservedObject var viewModel: PlanViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        guard let plan = viewModel.currentPlan else {
            return AnyView(InputView(viewModel: viewModel))
        }

        return AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your Date plan")
                        .font(.largeTitle.bold())
                    PillLabel(text: "Estimated total \(plan.lockedPlan.totalEstimatedCost)")

                    ForEach(plan.lockedPlan.stops) { stop in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stop \(stop.order)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(stop.venueName)
                                .font(.title3.bold())
                            Text(stop.reason)
                            HStack {
                                PillLabel(text: "\(stop.durationMinutes) min")
                                PillLabel(text: stop.estimatedCost)
                            }
                            Button("Open in Apple Maps") {
                                openURL(appleMapsURL(for: stop))
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if viewModel.canRegenerateUnlockedPlan {
                        Button("Regenerate once") {
                            Task { await viewModel.regenerateUnlockedPlan() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        )
    }

    private func appleMapsURL(for stop: LockedStop) -> URL {
        let encoded = stop.appleMapsQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stop.appleMapsQuery
        return URL(string: "http://maps.apple.com/?q=\(encoded)")!
    }
}
```

- [ ] **Step 6: Wire ContentView**

Replace `Amora/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlanViewModel()
    @StateObject private var purchaseService = PurchaseService()
    @State private var showingPaywall = false

    var body: some View {
        Group {
            if viewModel.currentPlan == nil {
                InputView(viewModel: viewModel)
            } else if viewModel.isUnlocked {
                UnlockedPlanView(viewModel: viewModel)
            } else {
                PreviewPlanView(viewModel: viewModel) {
                    showingPaywall = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(purchaseService: purchaseService) { success in
                viewModel.completePurchase(success: success)
                showingPaywall = false
            }
        }
    }
}
```

- [ ] **Step 7: Verify build**

Run:

```bash
xcodebuild build -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds with all SwiftUI screens.

- [ ] **Step 8: Commit**

```bash
git add Amora/ContentView.swift Amora/Views
git commit -m "feat: add Amora MVP screens"
```

---

### Task 10: End-To-End Local Verification

**Files:**

- Modify only if verification finds defects in MVP files.

- [ ] **Step 1: Run Worker tests**

```bash
cd worker
npm test
npm run typecheck
```

Expected: all Worker tests and typecheck pass.

- [ ] **Step 2: Start Worker locally**

```bash
cd worker
npm run dev
```

Expected: Worker runs at `http://127.0.0.1:8787`.

- [ ] **Step 3: Run iOS tests**

```bash
xcodebuild test -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: all iOS tests pass.

- [ ] **Step 4: Run app in Simulator**

Use XcodeBuildMCP or Xcode to run the app on an iPhone simulator.

Manual verification:

- Generate preview from typed area.
- Confirm preview hides venue names and addresses.
- Regenerate preview.
- Use StoreKit local config to purchase.
- Confirm exact plan unlocks.
- Confirm 3 exact stops appear.
- Confirm Apple Maps button opens Maps URL.
- Confirm exact-plan regeneration is available while subscribed.

- [ ] **Step 5: Commit fixes from verification**

If verification required fixes:

```bash
git add Amora AmoraTests worker
git commit -m "fix: complete MVP verification"
```

If no fixes were required, do not create an empty commit.

---

## Self-Review Notes

- PRD coverage: app name, location narrowing, preview paywall, StoreKit product, Worker backend, OpenAI key custody, no current events, no Google Places, and verification are covered.
- Scope check: this is one MVP with two necessary subsystems, iOS and Worker. They are coupled by one endpoint and can be implemented in task order.
- Worker reliability requirement: the plan includes a bounded 5-attempt recovery loop that feeds validation errors back into the generation prompt and returns a retryable error if no valid plan is produced.
- Known setup risk: Xcode project scaffolding depends on local Xcode tooling. Verify scheme and simulator names before running tests.

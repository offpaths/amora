# Backend Paid Unlock Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the backend enforce Amora Plus unlocks so exact venue details are not returned until the server verifies an active StoreKit subscription.

**Architecture:** Split plan generation into a preview response plus short-lived server-side locked-plan storage. Add a separate unlock endpoint that accepts only an opaque plan token and Apple-signed StoreKit transaction proof, verifies that proof server-side, and returns the stored locked plan only for active `amora_plus_monthly` subscribers. Keep the MVP accountless and store only the transient generated plan payload needed for unlock.

**Tech Stack:** SwiftUI, StoreKit 2, XCTest, Cloudflare Workers, Workers KV, TypeScript, Zod, Vitest, Apple App Store Server Library signed-data verification.

---

## Assumptions To Confirm Before Execution

- Bundle ID is `com.planwithamora.Amora`.
- Product ID remains `amora_plus_monthly`.
- Backend remains Cloudflare Workers for this iteration.
- The unlock request must contain no purchaser profile data. It may contain only:
  - `planToken`: opaque short-lived access handle for this generated locked plan.
  - `signedTransactionInfo`: Apple StoreKit JWS proving an active entitlement.
- The app obtains `signedTransactionInfo` from StoreKit 2 `VerificationResult.jwsRepresentation` for the verified active transaction.
- The Worker verifies the signed transaction JWS using Apple signed-data verification, then checks product, bundle, expiration, revocation, and environment.
- We can configure Worker env/secrets:
  - `APP_STORE_BUNDLE_ID`
  - `APP_STORE_ENVIRONMENT`
  - `APP_STORE_APP_APPLE_ID`
- For TestFlight/App Store review, `APP_STORE_ENVIRONMENT` should be `Sandbox` until production launch, then switched to `Production`.
- KV TTL for locked plans is 24 hours.
- Restored active subscribers should generate already-unlocked plans without seeing the paywall.

## Questions To Grill Before Coding

1. What is the App Store app Apple ID? Production signed-data verification requires it.
2. Do you want unlocked plans to survive more than 24 hours before purchase, or is a short preview-to-purchase window fine?
3. Is bearer-token access acceptable for preview-to-unlock? With no accounts, possession of the short-lived `planToken` plus a valid signed subscription proof unlocks the stored content.
4. Do you want to keep using Cloudflare KV, or prefer Durable Objects for stronger single-region consistency? KV is simpler and enough for this one-token lookup flow.

## File Structure

- Modify `worker/wrangler.toml`: add a KV namespace binding named `PLANS`.
- Modify `worker/src/schema.ts`: add preview-only response, unlock request, unlock response, and transaction status schemas.
- Create `worker/src/plan-store.ts`: generate opaque tokens and store/load full plans in KV.
- Create `worker/src/app-store.ts`: verify Apple-signed StoreKit transaction proof.
- Modify `worker/src/index.ts`: add request-size checks, preview-only generation response, and `POST /unlock-plan`.
- Modify `worker/test/index.test.ts`: cover preview-only generation, unlock success/failure, request-size checks, and no locked-plan leak.
- Create `worker/test/plan-store.test.ts`: cover token format, storage, missing/expired token behavior.
- Create `worker/test/app-store.test.ts`: cover signed-transaction parsing and active-subscription decisions.
- Modify `Amora/Models/DatePlanModels.swift`: split `DatePlanPreviewResponse`, `UnlockedPlanResponse`, and optional locked plan on `DatePlanResponse`.
- Modify `Amora/Services/DatePlanClient.swift`: add `unlockPlan(planToken:signedTransactionInfo:)`.
- Modify `Amora/Services/PurchaseService.swift`: expose verified StoreKit signed transaction JWS for active subscriptions and purchases.
- Modify `Amora/ViewModels/PlanViewModel.swift`: store `planToken`, call backend unlock after purchase or active subscription.
- Modify `AmoraTests/DatePlanClientTests.swift`: cover preview response and unlock request.
- Modify `AmoraTests/PlanViewModelTests.swift`: cover preview locked state, purchase unlock via backend, subscribed preview auto-unlock, and unlock failure.
- Modify `AGENTS.md`: record the product decision that backend unlock enforcement is required.
- Modify `DESIGN.md`: record the architecture decision that exact venues are server-gated behind StoreKit verification.

---

### Task 1: Add Worker Schemas For Preview And Unlock Contracts

**Files:**
- Modify: `worker/src/schema.ts`
- Test: `worker/test/schema.test.ts`

- [ ] **Step 1: Write failing schema tests**

Add these imports in `worker/test/schema.test.ts`:

```ts
import {
  GeneratePlanRequestSchema,
  DatePlanResponseSchema,
  GeneratePlanPreviewResponseSchema,
  UnlockPlanRequestSchema,
  UnlockPlanResponseSchema,
  resolveCurrencyCode,
  validatePlanCostsForCurrency
} from "../src/schema";
```

Add these tests after the existing `DatePlanResponseSchema` tests:

```ts
describe("GeneratePlanPreviewResponseSchema", () => {
  it("accepts a preview response without locked plan details", () => {
    const result = GeneratePlanPreviewResponseSchema.safeParse({
      id: "plan_test_123",
      planToken: "0123456789abcdef0123456789abcdef",
      preview: validDatePlanResponse.preview
    });

    expect(result.success).toBe(true);
  });

  it("rejects preview responses that include locked plan details", () => {
    const result = GeneratePlanPreviewResponseSchema.safeParse({
      id: "plan_test_123",
      planToken: "0123456789abcdef0123456789abcdef",
      preview: validDatePlanResponse.preview,
      lockedPlan: validDatePlanResponse.lockedPlan
    });

    expect(result.success).toBe(false);
  });
});

describe("UnlockPlanRequestSchema", () => {
  it("accepts a plan token and signed transaction proof", () => {
    const result = UnlockPlanRequestSchema.safeParse({
      planToken: "0123456789abcdef0123456789abcdef",
      signedTransactionInfo: [
        "eyJhbGciOiJFUzI1NiJ9",
        "eyJwcm9kdWN0SWQiOiJhbW9yYV9wbHVzX21vbnRobHkifQ",
        "signature"
      ].join(".")
    });

    expect(result.success).toBe(true);
  });

  it("rejects blank unlock inputs", () => {
    const result = UnlockPlanRequestSchema.safeParse({
      planToken: "",
      signedTransactionInfo: ""
    });

    expect(result.success).toBe(false);
  });
});

describe("UnlockPlanResponseSchema", () => {
  it("accepts an unlock response with locked plan details", () => {
    const result = UnlockPlanResponseSchema.safeParse({
      id: "plan_test_123",
      lockedPlan: validDatePlanResponse.lockedPlan
    });

    expect(result.success).toBe(true);
  });
});
```

- [ ] **Step 2: Run schema tests and verify failure**

Run:

```bash
cd worker
npm test -- schema.test.ts
```

Expected: FAIL because `GeneratePlanPreviewResponseSchema`, `UnlockPlanRequestSchema`, and `UnlockPlanResponseSchema` are not exported yet.

- [ ] **Step 3: Add schemas and types**

In `worker/src/schema.ts`, add these exports after `DatePlanResponseSchema`:

```ts
export const GeneratePlanPreviewResponseSchema = DatePlanResponseSchema
  .pick({ id: true, preview: true })
  .extend({
    planToken: z.string().trim().min(32).max(128)
  })
  .strict();

export const UnlockPlanRequestSchema = z.object({
  planToken: z.string().trim().min(32).max(128),
  signedTransactionInfo: z.string().trim().min(20).max(10_000)
}).strict();

export const UnlockPlanResponseSchema = DatePlanResponseSchema
  .pick({ id: true, lockedPlan: true })
  .strict();
```

Replace the type exports at the bottom with:

```ts
export type GeneratePlanRequest = z.infer<typeof GeneratePlanRequestSchema>;
export type DatePlanResponse = z.infer<typeof DatePlanResponseSchema>;
export type GeneratePlanPreviewResponse = z.infer<typeof GeneratePlanPreviewResponseSchema>;
export type UnlockPlanRequest = z.infer<typeof UnlockPlanRequestSchema>;
export type UnlockPlanResponse = z.infer<typeof UnlockPlanResponseSchema>;
```

- [ ] **Step 4: Run schema tests and verify pass**

Run:

```bash
cd worker
npm test -- schema.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/src/schema.ts worker/test/schema.test.ts
git commit -m "feat: add paid unlock schemas"
```

---

### Task 2: Add Short-Lived Locked Plan Storage

**Files:**
- Create: `worker/src/plan-store.ts`
- Create: `worker/test/plan-store.test.ts`
- Modify: `worker/src/openai.ts`

- [ ] **Step 1: Write failing plan-store tests**

Create `worker/test/plan-store.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { createPlanToken, loadLockedPlan, storeLockedPlan } from "../src/plan-store";
import type { DatePlanResponse } from "../src/schema";

const validPlan: DatePlanResponse = {
  id: "plan_test_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["USD 60-90", "2 hours"],
    stops: [
      { order: 1, concept: "A cozy conversation starter", vibe: "cozy", reason: "A calm opening.", personalizationSignal: "quiet places" },
      { order: 2, concept: "A bookstore pause", vibe: "personal", reason: "A shared browse.", personalizationSignal: "bookstores" },
      { order: 3, concept: "A dessert finish", vibe: "sweet", reason: "A relaxed ending.", personalizationSignal: "matcha" }
    ]
  },
  lockedPlan: {
    totalEstimatedCost: "USD 60-90",
    stops: [
      { order: 1, venueName: "A", address: "1 St", appleMapsQuery: "A 1 St", durationMinutes: 35, reason: "A thoughtful first stop.", estimatedCost: "USD 20-30" },
      { order: 2, venueName: "B", address: "2 St", appleMapsQuery: "B 2 St", durationMinutes: 50, reason: "A thoughtful second stop.", estimatedCost: "USD 10-25" },
      { order: 3, venueName: "C", address: "3 St", appleMapsQuery: "C 3 St", durationMinutes: 35, reason: "A thoughtful final stop.", estimatedCost: "USD 30-35" }
    ]
  }
};

function kvStore() {
  const values = new Map<string, string>();
  return {
    put: vi.fn(async (key: string, value: string) => {
      values.set(key, value);
    }),
    get: vi.fn(async (key: string) => values.get(key) ?? null)
  };
}

describe("createPlanToken", () => {
  it("creates opaque hex tokens", () => {
    const token = createPlanToken();

    expect(token).toMatch(/^[a-f0-9]{64}$/);
  });
});

describe("locked plan storage", () => {
  it("stores and loads a locked plan by token", async () => {
    const kv = kvStore();
    const token = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    await storeLockedPlan(kv, token, validPlan);
    const loaded = await loadLockedPlan(kv, token);

    expect(loaded).toEqual({ id: "plan_test_123", lockedPlan: validPlan.lockedPlan });
    expect(kv.put).toHaveBeenCalledWith(
      `locked-plan:${token}`,
      JSON.stringify({ id: validPlan.id, lockedPlan: validPlan.lockedPlan }),
      { expirationTtl: 86_400 }
    );
  });

  it("returns undefined when no stored plan exists", async () => {
    const kv = kvStore();

    await expect(loadLockedPlan(kv, "missing-token")).resolves.toBeUndefined();
  });
});
```

- [ ] **Step 2: Run plan-store tests and verify failure**

Run:

```bash
cd worker
npm test -- plan-store.test.ts
```

Expected: FAIL because `worker/src/plan-store.ts` does not exist.

- [ ] **Step 3: Implement plan-store**

Create `worker/src/plan-store.ts`:

```ts
import { UnlockPlanResponseSchema, type DatePlanResponse, type UnlockPlanResponse } from "./schema";

export interface LockedPlanKV {
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
  get(key: string): Promise<string | null>;
}

const LOCKED_PLAN_TTL_SECONDS = 24 * 60 * 60;
const TOKEN_BYTES = 32;

export function createPlanToken(): string {
  const bytes = new Uint8Array(TOKEN_BYTES);
  crypto.getRandomValues(bytes);
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function storeLockedPlan(kv: LockedPlanKV, token: string, plan: DatePlanResponse): Promise<void> {
  const unlockPayload: UnlockPlanResponse = {
    id: plan.id,
    lockedPlan: plan.lockedPlan
  };

  await kv.put(storageKey(token), JSON.stringify(unlockPayload), {
    expirationTtl: LOCKED_PLAN_TTL_SECONDS
  });
}

export async function loadLockedPlan(kv: LockedPlanKV, token: string): Promise<UnlockPlanResponse | undefined> {
  const rawValue = await kv.get(storageKey(token));
  if (!rawValue) {
    return undefined;
  }

  try {
    return UnlockPlanResponseSchema.parse(JSON.parse(rawValue));
  } catch {
    return undefined;
  }
}

function storageKey(token: string): string {
  return `locked-plan:${token}`;
}
```

- [ ] **Step 4: Add KV to Worker environment type**

In `worker/src/openai.ts`, change `Env` to:

```ts
export interface Env {
  OPENAI_API_KEY: string;
  PLANS: {
    put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
    get(key: string): Promise<string | null>;
  };
  APP_STORE_BUNDLE_ID?: string;
  APP_STORE_ENVIRONMENT?: string;
  APP_STORE_APP_APPLE_ID?: string;
}
```

- [ ] **Step 5: Run plan-store tests and verify pass**

Run:

```bash
cd worker
npm test -- plan-store.test.ts
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add worker/src/openai.ts worker/src/plan-store.ts worker/test/plan-store.test.ts
git commit -m "feat: store locked plans by token"
```

---

### Task 3: Return Preview-Only Responses From `/generate-plan`

**Files:**
- Modify: `worker/src/index.ts`
- Modify: `worker/test/index.test.ts`

- [ ] **Step 1: Update failing Worker tests**

In `worker/test/index.test.ts`, update the mocked env helper pattern by adding:

```ts
function env() {
  const values = new Map<string, string>();
  return {
    OPENAI_API_KEY: "test-key",
    PLANS: {
      put: vi.fn(async (key: string, value: string) => {
        values.set(key, value);
      }),
      get: vi.fn(async (key: string) => values.get(key) ?? null)
    }
  };
}
```

Change the valid generation test expectation to:

```ts
const testEnv = env();
const response = await worker.fetch(
  new Request("http://localhost/generate-plan", {
    method: "POST",
    body: JSON.stringify(validRequest),
    headers: { "content-type": "application/json" }
  }),
  testEnv
);

expect(response.status).toBe(200);
const body = await response.json();
expect(body).toMatchObject({
  id: validPlan.id,
  preview: validPlan.preview
});
expect(body.planToken).toMatch(/^[a-f0-9]{64}$/);
expect(body.lockedPlan).toBeUndefined();
expect(testEnv.PLANS.put).toHaveBeenCalledTimes(1);
expect(generateDatePlan).toHaveBeenCalledWith(validRequest, testEnv);
expectCorsHeaders(response);
```

Add this test:

```ts
it("rejects oversized request bodies before parsing JSON", async () => {
  const response = await worker.fetch(
    new Request("http://localhost/generate-plan", {
      method: "POST",
      body: "{}",
      headers: {
        "content-type": "application/json",
        "content-length": "16385"
      }
    }),
    env()
  );

  expect(response.status).toBe(413);
  await expect(response.json()).resolves.toEqual({ error: "request_too_large" });
});
```

Replace existing inline env objects like `{ OPENAI_API_KEY: "test-key" }` with `env()`.

- [ ] **Step 2: Run Worker tests and verify failure**

Run:

```bash
cd worker
npm test -- index.test.ts
```

Expected: FAIL because `/generate-plan` still returns `lockedPlan` and has no request-size check.

- [ ] **Step 3: Implement preview-only generation**

In `worker/src/index.ts`, update imports:

```ts
import { generateDatePlan, type Env } from "./openai";
import { createPlanToken, loadLockedPlan, storeLockedPlan } from "./plan-store";
import { GeneratePlanRequestSchema, UnlockPlanRequestSchema } from "./schema";
```

Add near constants:

```ts
const MAX_REQUEST_BODY_BYTES = 16_384;
```

After method validation and before rate limiting, add:

```ts
if (isRequestTooLarge(request)) {
  return json({ error: "request_too_large" }, 413);
}
```

Replace the success branch:

```ts
const plan = await generateDatePlan(parsed.data, env);
const planToken = createPlanToken();
await storeLockedPlan(env.PLANS, planToken, plan);
return json({ id: plan.id, planToken, preview: plan.preview }, 200);
```

Add helper:

```ts
function isRequestTooLarge(request: Request): boolean {
  const contentLength = request.headers.get("content-length");
  if (!contentLength) {
    return false;
  }

  const parsedLength = Number(contentLength);
  return Number.isFinite(parsedLength) && parsedLength > MAX_REQUEST_BODY_BYTES;
}
```

- [ ] **Step 4: Run Worker tests and verify pass**

Run:

```bash
cd worker
npm test -- index.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/src/index.ts worker/test/index.test.ts
git commit -m "feat: return preview-only generated plans"
```

---

### Task 4: Add App Store Subscription Verification

**Files:**
- Create: `worker/src/app-store.ts`
- Create: `worker/test/app-store.test.ts`
- Modify: `worker/package.json`

- [ ] **Step 1: Write failing signed-proof verifier tests**

Create `worker/test/app-store.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { isActiveAmoraPlusTransaction, verifyActiveSubscriptionProof } from "../src/app-store";
import type { Env } from "../src/openai";

const baseEnv: Env = {
  OPENAI_API_KEY: "test-key",
  PLANS: {
    put: async () => {},
    get: async () => null
  },
  APP_STORE_BUNDLE_ID: "com.planwithamora.Amora",
  APP_STORE_ENVIRONMENT: "Sandbox",
  APP_STORE_APP_APPLE_ID: "1234567890"
};

describe("isActiveAmoraPlusTransaction", () => {
  it("returns true for an active Amora Plus signed transaction payload", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(true);
  });

  it("returns false for expired transactions", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() - 1000
    }, baseEnv)).toBe(false);
  });

  it("returns false for revoked transactions", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000,
      revocationDate: Date.now()
    }, baseEnv)).toBe(false);
  });

  it("returns false for another product id", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "other_product",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(false);
  });

  it("returns false for another bundle id", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.example.Other",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(false);
  });
});

describe("verifyActiveSubscriptionProof", () => {
  it("verifies signed proof through the supplied verifier and ignores purchaser profile fields", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => ({
        bundleId: "com.planwithamora.Amora",
        productId: "amora_plus_monthly",
        environment: "Sandbox",
        expiresDate: Date.now() + 86_400_000,
        appAccountToken: "ignored-purchaser-linkage"
      }))
    };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", baseEnv, verifier)).resolves.toBe(true);
    expect(verifier.verifyAndDecodeTransaction).toHaveBeenCalledWith("apple.signed.transaction.jws");
  });

  it("returns false when signed proof verification fails", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => {
        throw new Error("verification failed");
      })
    };

    await expect(verifyActiveSubscriptionProof("bad-proof", baseEnv, verifier)).resolves.toBe(false);
  });
});
```

- [ ] **Step 2: Run verifier tests and verify failure**

Run:

```bash
cd worker
npm test -- app-store.test.ts
```

Expected: FAIL because `worker/src/app-store.ts` does not exist.

- [ ] **Step 3: Install Apple library**

Run:

```bash
cd worker
npm install @apple/app-store-server-library
```

Expected: `package.json` and `package-lock.json` update.

- [ ] **Step 4: Implement verifier using Apple signed transaction proof**

Create `worker/src/app-store.ts`:

```ts
import { Environment, SignedDataVerifier, type JWSTransactionDecodedPayload } from "@apple/app-store-server-library";
import type { Env } from "./openai";

const PLUS_PRODUCT_ID = "amora_plus_monthly";
const APPLE_ROOT_CERTIFICATE_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G4.cer"
];

type TransactionVerifier = Pick<SignedDataVerifier, "verifyAndDecodeTransaction">;

let cachedRootCertificates: Buffer[] | undefined;

export async function verifyActiveSubscriptionProof(
  signedTransactionInfo: string,
  env: Env,
  verifier = await createVerifier(env)
): Promise<boolean> {
  try {
    const payload = await verifier.verifyAndDecodeTransaction(signedTransactionInfo);
    return isActiveAmoraPlusTransaction(payload, env);
  } catch {
    return false;
  }
}

export function isActiveAmoraPlusTransaction(payload: JWSTransactionDecodedPayload, env: Env): boolean {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const environment = env.APP_STORE_ENVIRONMENT ?? "Sandbox";

  if (payload.bundleId !== bundleId) {
    return false;
  }
  if (payload.productId !== PLUS_PRODUCT_ID) {
    return false;
  }
  if (payload.environment !== environment) {
    return false;
  }
  const expiresDate = Number(payload.expiresDate);
  if (!Number.isFinite(expiresDate) || expiresDate <= Date.now()) {
    return false;
  }
  return payload.revocationDate === undefined;
}

async function createVerifier(env: Env): Promise<TransactionVerifier> {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const environment = env.APP_STORE_ENVIRONMENT === "Production" ? Environment.PRODUCTION : Environment.SANDBOX;
  const appAppleId = env.APP_STORE_APP_APPLE_ID ? Number(env.APP_STORE_APP_APPLE_ID) : undefined;
  return new SignedDataVerifier(await loadAppleRootCertificates(), true, environment, bundleId, appAppleId);
}

async function loadAppleRootCertificates(): Promise<Buffer[]> {
  if (cachedRootCertificates) {
    return cachedRootCertificates;
  }

  cachedRootCertificates = await Promise.all(APPLE_ROOT_CERTIFICATE_URLS.map(async (url) => {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error("apple_root_certificate_fetch_failed");
    }
    return Buffer.from(await response.arrayBuffer());
  }));
  return cachedRootCertificates;
}

function required(value: string | undefined): string {
  if (!value) {
    throw new Error("app_store_not_configured");
  }
  return value;
}
```

- [ ] **Step 5: Run verifier tests**

Run:

```bash
cd worker
npm test -- app-store.test.ts
```

Expected: PASS. If `Buffer` or certificate loading causes Worker bundling/runtime issues, stop and either polyfill narrowly or switch this verifier to a tiny Node serverless verifier. Do not continue with unsigned JWT decoding or a fake verifier.

- [ ] **Step 6: Commit**

```bash
git add worker/package.json worker/package-lock.json worker/src/app-store.ts worker/test/app-store.test.ts
git commit -m "feat: verify App Store subscription status"
```

---

### Task 5: Add `/unlock-plan`

**Files:**
- Modify: `worker/src/index.ts`
- Modify: `worker/test/index.test.ts`

- [ ] **Step 1: Mock verifier in Worker tests**

In `worker/test/index.test.ts`, add:

```ts
import { verifyActiveSubscriptionProof } from "../src/app-store";
```

Add mock:

```ts
vi.mock("../src/app-store", () => ({
  verifyActiveSubscriptionProof: vi.fn(async () => true)
}));
```

Add unlock tests:

```ts
describe("POST /unlock-plan", () => {
  it("returns locked plan details for an active subscription and valid token", async () => {
    const testEnv = env();
    const generateResponse = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: { "content-type": "application/json", "cf-connecting-ip": "198.51.100.44" }
      }),
      testEnv
    );
    const preview = await generateResponse.json() as { planToken: string };

    const response = await worker.fetch(
      new Request("http://localhost/unlock-plan", {
        method: "POST",
        body: JSON.stringify({ planToken: preview.planToken, signedTransactionInfo: "apple.signed.transaction.jws" }),
        headers: { "content-type": "application/json", "cf-connecting-ip": "198.51.100.45" }
      }),
      testEnv
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      id: validPlan.id,
      lockedPlan: validPlan.lockedPlan
    });
    expect(verifyActiveSubscriptionProof).toHaveBeenCalledWith("apple.signed.transaction.jws", testEnv);
  });

  it("rejects unlock when subscription is inactive", async () => {
    vi.mocked(verifyActiveSubscriptionProof).mockResolvedValueOnce(false);
    const response = await worker.fetch(
      new Request("http://localhost/unlock-plan", {
        method: "POST",
        body: JSON.stringify({
          planToken: "0123456789abcdef0123456789abcdef",
          signedTransactionInfo: "apple.signed.transaction.jws"
        }),
        headers: { "content-type": "application/json" }
      }),
      env()
    );

    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({ error: "subscription_required" });
  });

  it("returns not found for missing plan token", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/unlock-plan", {
        method: "POST",
        body: JSON.stringify({
          planToken: "0123456789abcdef0123456789abcdef",
          signedTransactionInfo: "apple.signed.transaction.jws"
        }),
        headers: { "content-type": "application/json" }
      }),
      env()
    );

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toEqual({ error: "plan_not_found" });
  });

  it("rejects unlock requests that include purchaser profile fields", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/unlock-plan", {
        method: "POST",
        body: JSON.stringify({
          planToken: "0123456789abcdef0123456789abcdef",
          signedTransactionInfo: "apple.signed.transaction.jws",
          email: "person@example.com"
        }),
        headers: { "content-type": "application/json" }
      }),
      env()
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_request" });
  });
});
```

- [ ] **Step 2: Run Worker tests and verify failure**

Run:

```bash
cd worker
npm test -- index.test.ts
```

Expected: FAIL because `/unlock-plan` is not implemented.

- [ ] **Step 3: Implement unlock route**

In `worker/src/index.ts`, import verifier:

```ts
import { verifyActiveSubscriptionProof } from "./app-store";
```

Replace the route check:

```ts
if (url.pathname !== "/generate-plan" && url.pathname !== "/unlock-plan") {
  return json({ error: "not_found" }, 404);
}
```

Replace POST handling with route dispatch:

```ts
if (request.method !== "POST") {
  return json({ error: "not_found" }, 404);
}

if (isRequestTooLarge(request)) {
  return json({ error: "request_too_large" }, 413);
}

if (isRateLimited(request)) {
  return json({ error: "rate_limited", retryable: true }, 429);
}

if (url.pathname === "/generate-plan") {
  return handleGeneratePlan(request, env);
}

return handleUnlockPlan(request, env);
```

Move existing JSON parse/generation logic into:

```ts
async function handleGeneratePlan(request: Request, env: Env): Promise<Response> {
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
    const planToken = createPlanToken();
    await storeLockedPlan(env.PLANS, planToken, plan);
    return json({ id: plan.id, planToken, preview: plan.preview }, 200);
  } catch {
    return json({ error: "generation_failed", retryable: true }, 502);
  }
}
```

Add:

```ts
async function handleUnlockPlan(request: Request, env: Env): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const parsed = UnlockPlanRequestSchema.safeParse(body);
  if (!parsed.success) {
    return json({ error: "invalid_request" }, 400);
  }

  let isActive = false;
  try {
    isActive = await verifyActiveSubscriptionProof(parsed.data.signedTransactionInfo, env);
  } catch {
    return json({ error: "subscription_verification_failed", retryable: true }, 502);
  }

  if (!isActive) {
    return json({ error: "subscription_required" }, 403);
  }

  const plan = await loadLockedPlan(env.PLANS, parsed.data.planToken);
  if (!plan) {
    return json({ error: "plan_not_found" }, 404);
  }

  return json(plan, 200);
}
```

- [ ] **Step 4: Run Worker tests and verify pass**

Run:

```bash
cd worker
npm test -- index.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/src/index.ts worker/test/index.test.ts
git commit -m "feat: add paid plan unlock endpoint"
```

---

### Task 6: Configure Cloudflare KV And Secrets

**Files:**
- Modify: `worker/wrangler.toml`
- No test file

- [ ] **Step 1: Create KV namespaces**

Run:

```bash
cd worker
npx wrangler kv namespace create PLANS
npx wrangler kv namespace create PLANS --preview
```

Expected: Wrangler prints production and preview namespace IDs.

- [ ] **Step 2: Add KV binding**

Modify `worker/wrangler.toml`:

```toml
name = "amora-api"
main = "src/index.ts"
compatibility_date = "2026-06-22"
compatibility_flags = ["nodejs_compat"]

[[routes]]
pattern = "api.planwithamora.com"
custom_domain = true

[[kv_namespaces]]
binding = "PLANS"
id = "replace-with-production-plans-kv-id"
preview_id = "replace-with-preview-plans-kv-id"
```

Before committing, replace both IDs with the exact values printed by Wrangler.

- [ ] **Step 3: Configure App Store environment values**

Run each command and paste the matching value when prompted:

```bash
cd worker
npx wrangler secret put APP_STORE_BUNDLE_ID
npx wrangler secret put APP_STORE_ENVIRONMENT
npx wrangler secret put APP_STORE_APP_APPLE_ID
```

Use these values:

```text
APP_STORE_BUNDLE_ID=com.planwithamora.Amora
APP_STORE_ENVIRONMENT=Sandbox
```

Use the App Store app Apple ID for `APP_STORE_APP_APPLE_ID`. No purchaser profile fields, App Store Connect private key, issuer id, or customer account identifier is required for this signed-transaction-proof flow.

- [ ] **Step 4: Typecheck**

Run:

```bash
cd worker
npm run typecheck
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add worker/wrangler.toml
git commit -m "chore: configure locked plan storage"
```

---

### Task 7: Update iOS Models And Client

**Files:**
- Modify: `Amora/Models/DatePlanModels.swift`
- Modify: `Amora/Services/DatePlanClient.swift`
- Modify: `AmoraTests/DatePlanClientTests.swift`

- [ ] **Step 1: Write failing client tests**

In `AmoraTests/DatePlanClientTests.swift`, replace `testGeneratePlanEncodesRequestAndDecodesResponse` response JSON with preview-only JSON:

```swift
let responseJSON = """
{
  "id": "plan_test_123",
  "planToken": "0123456789abcdef0123456789abcdef",
  "preview": {
    "title": "A cozy 2-hour plan near Williamsburg",
    "summaryBadges": ["USD 60-90", "2 hours", "No bars"],
    "stops": [
      { "order": 1, "concept": "A cozy conversation starter" },
      { "order": 2, "concept": "A personal activity" },
      { "order": 3, "concept": "A relaxed dessert finish" }
    ]
  }
}
""".data(using: .utf8)!
```

Change assertions:

```swift
XCTAssertEqual(plan.id, "plan_test_123")
XCTAssertEqual(plan.planToken, "0123456789abcdef0123456789abcdef")
XCTAssertNil(plan.lockedPlan)
```

Add unlock test:

```swift
func testUnlockPlanPostsTokenAndTransactionID() async throws {
    let responseJSON = """
    {
      "id": "plan_test_123",
      "lockedPlan": {
        "totalEstimatedCost": "USD 60-90",
        "stops": [
          { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "USD 20-30" },
          { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "USD 10-25" },
          { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "USD 30-35" }
        ]
      }
    }
    """.data(using: .utf8)!

    URLProtocolStub.requestHandler = { request in
        XCTAssertEqual(request.url?.path, "/unlock-plan")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBodyData)
        let encoded = try JSONDecoder().decode(UnlockPlanRequest.self, from: body)
        XCTAssertEqual(encoded.planToken, "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(encoded.signedTransactionInfo, "apple.signed.transaction.jws")
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseJSON)
    }

    let client = DatePlanClient(baseURL: URL(string: "https://example.com")!, session: .stubbed)
    let unlocked = try await client.unlockPlan(
        planToken: "0123456789abcdef0123456789abcdef",
        signedTransactionInfo: "apple.signed.transaction.jws"
    )

    XCTAssertEqual(unlocked.id, "plan_test_123")
    XCTAssertEqual(unlocked.lockedPlan.stops.count, 3)
}
```

- [ ] **Step 2: Run iOS client tests and verify failure**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AmoraTests/DatePlanClientTests
```

Expected: FAIL because models/client still require `lockedPlan` in generation response and no unlock method exists.

- [ ] **Step 3: Update models**

In `Amora/Models/DatePlanModels.swift`, replace `DatePlanResponse` with:

```swift
struct DatePlanResponse: Codable, Equatable, Identifiable {
    var id: String
    var planToken: String?
    var preview: PlanPreview
    var lockedPlan: LockedPlan?
}

struct UnlockPlanRequest: Codable, Equatable {
    var planToken: String
    var signedTransactionInfo: String
}

struct UnlockedPlanResponse: Codable, Equatable, Identifiable {
    var id: String
    var lockedPlan: LockedPlan
}
```

- [ ] **Step 4: Update client**

In `Amora/Services/DatePlanClient.swift`, add an error:

```swift
case unlockFailed
```

Add method:

```swift
func unlockPlan(planToken: String, signedTransactionInfo: String) async throws -> UnlockedPlanResponse {
    var urlRequest = URLRequest(url: baseURL.appendingPathComponent("unlock-plan"))
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(
        UnlockPlanRequest(planToken: planToken, signedTransactionInfo: signedTransactionInfo)
    )

    let (data, response) = try await session.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw DatePlanClientError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
        throw DatePlanClientError.unlockFailed
    }

    return try JSONDecoder().decode(UnlockedPlanResponse.self, from: data)
}
```

- [ ] **Step 5: Run client tests and verify pass**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AmoraTests/DatePlanClientTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Amora/Models/DatePlanModels.swift Amora/Services/DatePlanClient.swift AmoraTests/DatePlanClientTests.swift
git commit -m "feat: add iOS unlock client contract"
```

---

### Task 8: Expose StoreKit Signed Transaction Proof

**Files:**
- Modify: `Amora/Services/PurchaseService.swift`
- Test: manual plus existing plan tests

- [ ] **Step 1: Update PurchaseService state**

In `Amora/Services/PurchaseService.swift`, add property:

```swift
@Published private(set) var activeSignedTransactionInfo: String?
```

In `refreshSubscriptionStatus()`, update the loop:

```swift
var activeSignedTransactionInfo: String?

for await entitlement in Transaction.currentEntitlements {
    guard case .verified(let transaction) = entitlement else {
        continue
    }

    if transaction.productID == AppConfig.plusMonthlyProductID {
        isActive = true
        activeSignedTransactionInfo = entitlement.jwsRepresentation
        break
    }
}

hasActiveSubscription = isActive
self.activeSignedTransactionInfo = activeSignedTransactionInfo
```

In `purchasePlusMonthly()`, after success:

```swift
await refreshSubscriptionStatus()
```

Replace direct `hasActiveSubscription = true` with the refresh.

- [ ] **Step 2: Typecheck with app tests**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AmoraTests/PlanViewModelTests
```

Expected: PASS or unrelated existing simulator failure only.

- [ ] **Step 3: Commit**

```bash
git add Amora/Services/PurchaseService.swift
git commit -m "feat: expose active StoreKit transaction id"
```

---

### Task 9: Wire ViewModel Unlock Flow

**Files:**
- Modify: `Amora/ViewModels/PlanViewModel.swift`
- Modify: `Amora/ContentView.swift`
- Modify: `AmoraTests/PlanViewModelTests.swift`

- [ ] **Step 1: Update failing ViewModel tests**

Update `PlanViewModel` test construction to provide both generation and unlock closures. Add helper:

```swift
private static func samplePreview(id: String = "plan_one", token: String = "token_0123456789abcdef0123456789") -> DatePlanResponse {
    DatePlanResponse(
        id: id,
        planToken: token,
        preview: samplePlan(id: id).preview,
        lockedPlan: nil
    )
}

private static func sampleUnlock(id: String = "plan_one") -> UnlockedPlanResponse {
    UnlockedPlanResponse(id: id, lockedPlan: samplePlan(id: id).lockedPlan!)
}
```

Add tests:

```swift
func testPurchaseUnlockCallsBackendWithPlanTokenAndSignedProof() async {
    var unlockInputs: [(String, String)] = []
    let viewModel = PlanViewModel(
        generate: { _ in Self.samplePreview(id: "plan_one", token: "token_0123456789abcdef0123456789") },
        unlock: { token, signedTransactionInfo in
            unlockInputs.append((token, signedTransactionInfo))
            return Self.sampleUnlock(id: "plan_one")
        }
    )
    viewModel.locationLabel = "Williamsburg, Brooklyn"
    viewModel.planningAreaCountryCode = "US"
    viewModel.hasAcceptedAIDisclosure = true

    await viewModel.generatePreview()
    await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "apple.signed.transaction.jws")

    XCTAssertEqual(unlockInputs.first?.0, "token_0123456789abcdef0123456789")
    XCTAssertEqual(unlockInputs.first?.1, "apple.signed.transaction.jws")
    XCTAssertTrue(viewModel.isUnlocked)
    XCTAssertEqual(viewModel.currentPlan?.lockedPlan?.stops.count, 3)
}

func testUnlockFailureDoesNotRevealPlan() async {
    let viewModel = PlanViewModel(
        generate: { _ in Self.samplePreview(id: "plan_one", token: "token_0123456789abcdef0123456789") },
        unlock: { _, _ in throw DatePlanClientError.unlockFailed }
    )
    viewModel.locationLabel = "Williamsburg, Brooklyn"
    viewModel.planningAreaCountryCode = "US"
    viewModel.hasAcceptedAIDisclosure = true

    await viewModel.generatePreview()
    await viewModel.completeSubscriptionPurchase(success: true, signedTransactionInfo: "apple.signed.transaction.jws")

    XCTAssertFalse(viewModel.isUnlocked)
    XCTAssertNil(viewModel.currentPlan?.lockedPlan)
    XCTAssertEqual(viewModel.errorMessage, "We could not unlock your plan. Try Restore Purchases or contact support.")
}
```

- [ ] **Step 2: Run ViewModel tests and verify failure**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AmoraTests/PlanViewModelTests
```

Expected: FAIL because ViewModel has no unlock closure and completion is synchronous.

- [ ] **Step 3: Update ViewModel initializer and properties**

In `Amora/ViewModels/PlanViewModel.swift`, add:

```swift
private let unlock: (String, String) async throws -> UnlockedPlanResponse
```

Update initializer:

```swift
init(
    generate: @escaping (GeneratePlanRequest) async throws -> DatePlanResponse = {
        try await DatePlanClient(baseURL: AppConfig.backendBaseURL).generatePlan($0)
    },
    unlock: @escaping (String, String) async throws -> UnlockedPlanResponse = {
        try await DatePlanClient(baseURL: AppConfig.backendBaseURL).unlockPlan(planToken: $0, signedTransactionInfo: $1)
    },
    unlockedPlanStore: UnlockedPlanStore = UnlockedPlanStore()
) {
    hasAcceptedAIDisclosure = UserDefaults.standard.bool(forKey: Self.aiDisclosureConsentKey)
    self.generate = generate
    self.unlock = unlock
    self.unlockedPlanStore = unlockedPlanStore
    savedUnlockedPlan = unlockedPlanStore.load()
}
```

- [ ] **Step 4: Add async unlock method**

Replace `completeSubscriptionPurchase(success:)` with:

```swift
func completeSubscriptionPurchase(success: Bool, signedTransactionInfo: String?) async {
    guard success else { return }
    hasActiveSubscription = true
    await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
}
```

Replace `unlockCurrentPlan()` with:

```swift
func unlockCurrentPlan(signedTransactionInfo: String?) async {
    guard let currentPlan, let planToken = currentPlan.planToken, let signedTransactionInfo else {
        errorMessage = "We could not unlock your plan. Try Restore Purchases or contact support."
        return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
        let unlocked = try await unlock(planToken, signedTransactionInfo)
        self.currentPlan = DatePlanResponse(
            id: currentPlan.id,
            planToken: currentPlan.planToken,
            preview: currentPlan.preview,
            lockedPlan: unlocked.lockedPlan
        )
        isUnlocked = true
        isShowingSavedUnlockedPlan = false
        if let currentPlan = self.currentPlan {
            saveLatestUnlockedPlan(currentPlan)
        }
    } catch {
        isUnlocked = false
        errorMessage = "We could not unlock your plan. Try Restore Purchases or contact support."
    }
}
```

Update `setSubscriptionActive(_:)`:

```swift
func setSubscriptionActive(_ isActive: Bool) {
    hasActiveSubscription = isActive
}
```

Update `generatePreview()`:

```swift
currentPlan = try await generate(makeRequest())
isUnlocked = false
isShowingSavedUnlockedPlan = false
```

Update `regenerateUnlockedPlan()`:

```swift
func regenerateUnlockedPlan(signedTransactionInfo: String?) async {
    guard canRegenerateUnlockedPlan else { return }
    regenerationAttempt += 1
    await generatePreview()
    await unlockCurrentPlan(signedTransactionInfo: signedTransactionInfo)
}
```

- [ ] **Step 5: Update ContentView calls**

In `Amora/ContentView.swift`, change purchase callback:

```swift
onPurchased: { success in
    await viewModel.completeSubscriptionPurchase(
        success: success,
        signedTransactionInfo: purchaseService.activeSignedTransactionInfo
    )
}
```

If the closure is not async, wrap it:

```swift
onPurchased: { success in
    Task {
        await viewModel.completeSubscriptionPurchase(
            success: success,
            signedTransactionInfo: purchaseService.activeSignedTransactionInfo
        )
    }
}
```

For regenerate buttons, pass the active signed transaction proof:

```swift
Task { await viewModel.regenerateUnlockedPlan(signedTransactionInfo: purchaseService.activeSignedTransactionInfo) }
```

- [ ] **Step 6: Run ViewModel tests and verify pass**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AmoraTests/PlanViewModelTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Amora/ViewModels/PlanViewModel.swift Amora/ContentView.swift AmoraTests/PlanViewModelTests.swift
git commit -m "feat: unlock paid plans through backend"
```

---

### Task 10: Update Views For Optional Locked Plan

**Files:**
- Modify: `Amora/Views/UnlockedPlanView.swift`
- Modify: `Amora/Services/UnlockedPlanStore.swift`

- [ ] **Step 1: Make unlocked view require locked details safely**

In `Amora/Views/UnlockedPlanView.swift`, replace direct `plan.lockedPlan` access with:

```swift
if let lockedPlan = plan.lockedPlan {
    PillLabel(text: "Estimated total \(lockedPlan.totalEstimatedCost)", tint: AmoraTheme.olive)

    VStack(spacing: 12) {
        ForEach(lockedPlan.stops) { stop in
            LockedStopCard(stop: stop)
        }
    }
} else {
    Text("Your exact plan is still unlocking.")
        .font(.subheadline)
        .foregroundStyle(AmoraTheme.muted)
}
```

- [ ] **Step 2: Prevent saving preview-only plans**

In `Amora/Services/UnlockedPlanStore.swift`, update `save(plan:savedAt:)`:

```swift
func save(plan: DatePlanResponse, savedAt: Date = Date()) {
    guard plan.lockedPlan != nil else { return }
    let savedPlan = SavedUnlockedPlan(plan: plan, savedAt: savedAt)
    guard let data = try? JSONEncoder().encode(savedPlan) else { return }
    UserDefaults.standard.set(data, forKey: Self.storageKey)
}
```

- [ ] **Step 3: Run app tests**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Amora/Views/UnlockedPlanView.swift Amora/Services/UnlockedPlanStore.swift
git commit -m "fix: require locked details before saving unlocked plans"
```

---

### Task 11: Document Security Decisions

**Files:**
- Modify: `AGENTS.md`
- Modify: `DESIGN.md`

- [ ] **Step 1: Update product decisions**

Add to `AGENTS.md` Product Decisions:

```md
- Exact venue details must be enforced server-side: the Worker returns only a preview until it verifies an active StoreKit subscription for `amora_plus_monthly`.
- Generated locked plans may be stored server-side only as short-lived transient unlock payloads; the MVP does not introduce accounts or long-term backend plan history.
```

- [ ] **Step 2: Update design decisions**

Add to `DESIGN.md` under Thoughtful Date Plan MVP:

```md
- Backend generation returns a preview plus an opaque short-lived plan token; exact venues are retrieved through a separate unlock endpoint after server-side StoreKit verification.
- The unlock architecture stays accountless for MVP and uses transient Worker storage instead of profiles or saved cloud plan history.
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md DESIGN.md
git commit -m "docs: record backend unlock enforcement decision"
```

---

### Task 12: Final Verification And Deployment Check

**Files:**
- No source edits expected

- [ ] **Step 1: Run Worker tests**

Run:

```bash
cd worker
npm test
npm run typecheck
```

Expected: PASS.

- [ ] **Step 2: Run iOS tests**

Run:

```bash
xcodebuild test -project Amora.xcodeproj -scheme Amora -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: PASS.

- [ ] **Step 3: Run dependency audit**

Run:

```bash
cd worker
npm audit --audit-level=moderate
```

Expected: Any remaining findings are dev-tool-only or separately tracked. If production dependency findings appear for runtime packages, fix before deploy.

- [ ] **Step 4: Deploy Worker to staging or production**

Run:

```bash
cd worker
npx wrangler deploy
```

Expected: deploy succeeds for `api.planwithamora.com`.

- [ ] **Step 5: Manual StoreKit sandbox verification**

Use a sandbox tester or StoreKit test flow and verify:

- Generate preview returns no exact venue details before purchase.
- Purchase succeeds.
- Backend unlock returns exact venue details.
- Restore Purchases sets active subscription and unlocks a newly generated preview.
- Expired or missing transaction does not unlock.

- [ ] **Step 6: Commit any final fixes**

```bash
git status --short
git add <changed-files>
git commit -m "fix: complete paid unlock verification"
```

## Self-Review

- Spec coverage: The plan covers server-side unlock enforcement, transient plan storage, request-size limiting, StoreKit subscription verification, iOS purchase flow wiring, tests, docs, and deployment.
- Placeholder scan: The only replaceable values are Cloudflare KV namespace IDs and App Store app configuration values, which cannot be known from the repository and must be supplied by platform setup.
- Type consistency: Worker and iOS use `planToken` plus `signedTransactionInfo`; no purchaser profile fields are part of `UnlockPlanRequest`.

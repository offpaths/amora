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
      { order: 1, venueName: "AA", address: "1 St", appleMapsQuery: "A 1 St", durationMinutes: 35, reason: "A thoughtful first stop.", estimatedCost: "USD 20-30" },
      { order: 2, venueName: "BB", address: "2 St", appleMapsQuery: "B 2 St", durationMinutes: 50, reason: "A thoughtful second stop.", estimatedCost: "USD 10-25" },
      { order: 3, venueName: "CC", address: "3 St", appleMapsQuery: "C 3 St", durationMinutes: 35, reason: "A thoughtful final stop.", estimatedCost: "USD 30-35" }
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

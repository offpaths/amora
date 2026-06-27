import { describe, expect, it } from "vitest";
import {
  GeneratePlanRequestSchema,
  DatePlanResponseSchema,
  resolveCurrencyCode,
  validatePlanCostsForCurrency
} from "../src/schema";

const validDatePlanResponse = {
  id: "plan_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["$$", "2 hours", "No bars"],
    stops: [
      {
        order: 1,
        concept: "A cozy conversation starter",
        vibe: "Calm and warm",
        reason: "A low-pressure first stop gives the date room to settle in.",
        personalizationSignal: "Matches her interest in quiet places."
      },
      {
        order: 2,
        concept: "A personal activity together",
        vibe: "Playful and thoughtful",
        reason: "A shared activity gives them something natural to react to together.",
        personalizationSignal: "Connects to their interest in bookstores."
      },
      {
        order: 3,
        concept: "A gentle final stop",
        vibe: "Sweet and unhurried",
        reason: "A soft final stop gives the plan a memorable closing moment.",
        personalizationSignal: "Keeps the night aligned with quiet, cozy preferences."
      }
    ]
  },
  lockedPlan: {
    totalEstimatedCost: "USD 60-90",
    stops: [
      {
        order: 1,
        venueName: "Example Cafe",
        address: "123 Example St",
        appleMapsQuery: "Example Cafe 123 Example St",
        durationMinutes: 40,
        reason: "A calm first stop.",
        estimatedCost: "USD 20-30"
      },
      {
        order: 2,
        venueName: "Example Bookstore",
        address: "456 Example Ave",
        appleMapsQuery: "Example Bookstore 456 Example Ave",
        durationMinutes: 50,
        reason: "A thoughtful middle stop.",
        estimatedCost: "USD 15-25"
      },
      {
        order: 3,
        venueName: "Example Dessert",
        address: "789 Example Blvd",
        appleMapsQuery: "Example Dessert 789 Example Blvd",
        durationMinutes: 30,
        reason: "A sweet closing moment.",
        estimatedCost: "USD 25-35"
      }
    ]
  }
};

describe("GeneratePlanRequestSchema", () => {
  it("accepts a valid MVP request", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetAmount: 100,
      countryCode: "US",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: "bookstores, matcha, quiet places"
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.budgetAmount).toBe(100);
      expect(result.data.regenerationAttempt).toBe(0);
    }
  });

  it("rejects unsupported durations", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetAmount: 100,
      countryCode: "US",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 95,
      partnerLikes: ""
    });

    expect(result.success).toBe(false);
  });

  it("rejects requests without a country code", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetAmount: 100,
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: ""
    });

    expect(result.success).toBe(false);
  });

  it("rejects unsupported country codes", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Atlantis",
      budgetAmount: 100,
      countryCode: "ZZ",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: ""
    });

    expect(result.success).toBe(false);
  });

  it("accepts free budget amounts", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetAmount: 0,
      countryCode: "US",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: ""
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.budgetAmount).toBe(0);
    }
  });

  it("rejects invalid budget amounts", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetAmount: -1,
      countryCode: "US",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: ""
    });

    expect(result.success).toBe(false);
  });
});

describe("DatePlanResponseSchema", () => {
  it("accepts exactly 3 preview and locked stops", () => {
    const result = DatePlanResponseSchema.safeParse(validDatePlanResponse);

    expect(result.success).toBe(true);
  });

  it("rejects locked cost estimates without an explicit currency identifier", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        totalEstimatedCost: "$60",
        stops: validDatePlanResponse.lockedPlan.stops.map((stop) => ({
          ...stop,
          estimatedCost: "$25"
        }))
      }
    });

    expect(result.success).toBe(false);
  });

  it("accepts free stop costs in any country", () => {
    const plan = {
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        stops: [
          { ...validDatePlanResponse.lockedPlan.stops[0], estimatedCost: "Free" },
          validDatePlanResponse.lockedPlan.stops[1],
          validDatePlanResponse.lockedPlan.stops[2]
        ]
      }
    };

    const parsed = DatePlanResponseSchema.parse(plan);

    expect(() => validatePlanCostsForCurrency(parsed, "USD")).not.toThrow();
  });

  it("allows a free total only when every stop is free", () => {
    const allFreePlan = {
      ...validDatePlanResponse,
      lockedPlan: {
        totalEstimatedCost: "Free",
        stops: validDatePlanResponse.lockedPlan.stops.map((stop) => ({
          ...stop,
          estimatedCost: "Free"
        }))
      }
    };

    const mixedPlan = {
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        totalEstimatedCost: "Free",
        stops: [
          { ...validDatePlanResponse.lockedPlan.stops[0], estimatedCost: "Free" },
          validDatePlanResponse.lockedPlan.stops[1],
          validDatePlanResponse.lockedPlan.stops[2]
        ]
      }
    };

    expect(() => validatePlanCostsForCurrency(DatePlanResponseSchema.parse(allFreePlan), "USD")).not.toThrow();
    expect(() => validatePlanCostsForCurrency(DatePlanResponseSchema.parse(mixedPlan), "USD")).toThrow("invalid_plan_currency");
  });

  it("validates paid estimates against the resolved country currency", () => {
    const ukPlan = {
      ...validDatePlanResponse,
      lockedPlan: {
        totalEstimatedCost: "GBP 40-60",
        stops: validDatePlanResponse.lockedPlan.stops.map((stop) => ({
          ...stop,
          estimatedCost: "GBP 10-20"
        }))
      }
    };

    const wrongCurrencyPlan = {
      ...ukPlan,
      lockedPlan: {
        ...ukPlan.lockedPlan,
        totalEstimatedCost: "USD 40-60"
      }
    };

    expect(() => validatePlanCostsForCurrency(DatePlanResponseSchema.parse(ukPlan), "GBP")).not.toThrow();
    expect(() => validatePlanCostsForCurrency(DatePlanResponseSchema.parse(wrongCurrencyPlan), "GBP")).toThrow("invalid_plan_currency");
  });

  it("rejects too few preview stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      preview: {
        ...validDatePlanResponse.preview,
        stops: validDatePlanResponse.preview.stops.slice(0, 2)
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects too many preview stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      preview: {
        ...validDatePlanResponse.preview,
        stops: [
          ...validDatePlanResponse.preview.stops,
          {
            order: 3,
            concept: "An extra preview stop",
            vibe: "Brief and bright",
            reason: "An extra stop should still carry the same preview contract.",
            personalizationSignal: "Reflects the requested quiet, cozy mood."
          }
        ]
      }
    });

    expect(result.success).toBe(false);
  });

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

  it("rejects too few locked stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        stops: validDatePlanResponse.lockedPlan.stops.slice(0, 2)
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects too many locked stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        stops: [
          ...validDatePlanResponse.lockedPlan.stops,
          {
            order: 3,
            venueName: "Example Nightcap",
            address: "321 Example Rd",
            appleMapsQuery: "Example Nightcap 321 Example Rd",
            durationMinutes: 25,
            reason: "An extra locked stop.",
            estimatedCost: "USD 10-20"
          }
        ]
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects duplicate preview stop orders", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      preview: {
        ...validDatePlanResponse.preview,
        stops: [
          validDatePlanResponse.preview.stops[0],
          { ...validDatePlanResponse.preview.stops[1], order: 1 },
          validDatePlanResponse.preview.stops[2]
        ]
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects out-of-order preview stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      preview: {
        ...validDatePlanResponse.preview,
        stops: [
          validDatePlanResponse.preview.stops[1],
          validDatePlanResponse.preview.stops[0],
          validDatePlanResponse.preview.stops[2]
        ]
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects duplicate locked stop orders", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        stops: [
          validDatePlanResponse.lockedPlan.stops[0],
          { ...validDatePlanResponse.lockedPlan.stops[1], order: 1 },
          validDatePlanResponse.lockedPlan.stops[2]
        ]
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects out-of-order locked stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      ...validDatePlanResponse,
      lockedPlan: {
        ...validDatePlanResponse.lockedPlan,
        stops: [
          validDatePlanResponse.lockedPlan.stops[1],
          validDatePlanResponse.lockedPlan.stops[0],
          validDatePlanResponse.lockedPlan.stops[2]
        ]
      }
    });

    expect(result.success).toBe(false);
  });
});

describe("resolveCurrencyCode", () => {
  it("maps countries to their estimate currencies", () => {
    expect(resolveCurrencyCode("GB")).toBe("GBP");
    expect(resolveCurrencyCode("TH")).toBe("THB");
    expect(resolveCurrencyCode("US")).toBe("USD");
    expect(resolveCurrencyCode("JP")).toBe("JPY");
    expect(resolveCurrencyCode("FR")).toBe("EUR");
  });

  it("returns undefined for unsupported country codes", () => {
    expect(resolveCurrencyCode("ZZ")).toBeUndefined();
  });
});

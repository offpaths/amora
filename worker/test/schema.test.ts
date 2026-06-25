import { describe, expect, it } from "vitest";
import { GeneratePlanRequestSchema, DatePlanResponseSchema } from "../src/schema";

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
    totalEstimatedCost: "$60-$90",
    stops: [
      {
        order: 1,
        venueName: "Example Cafe",
        address: "123 Example St",
        appleMapsQuery: "Example Cafe 123 Example St",
        durationMinutes: 40,
        reason: "A calm first stop.",
        estimatedCost: "$20-$30"
      },
      {
        order: 2,
        venueName: "Example Bookstore",
        address: "456 Example Ave",
        appleMapsQuery: "Example Bookstore 456 Example Ave",
        durationMinutes: 50,
        reason: "A thoughtful middle stop.",
        estimatedCost: "$15-$25"
      },
      {
        order: 3,
        venueName: "Example Dessert",
        address: "789 Example Blvd",
        appleMapsQuery: "Example Dessert 789 Example Blvd",
        durationMinutes: 30,
        reason: "A sweet closing moment.",
        estimatedCost: "$25-$35"
      }
    ]
  }
};

describe("GeneratePlanRequestSchema", () => {
  it("accepts a valid MVP request", () => {
    const result = GeneratePlanRequestSchema.safeParse({
      locationLabel: "Williamsburg, Brooklyn",
      budgetTier: "$$",
      vibe: "cozy",
      noDrinking: true,
      durationMinutes: 120,
      partnerLikes: "bookstores, matcha, quiet places"
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
            estimatedCost: "$10-$20"
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

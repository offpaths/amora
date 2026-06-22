import { describe, expect, it } from "vitest";
import { GeneratePlanRequestSchema, DatePlanResponseSchema } from "../src/schema";

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
  it("requires exactly 3 preview and locked stops", () => {
    const result = DatePlanResponseSchema.safeParse({
      id: "plan_123",
      preview: {
        title: "A cozy 2-hour plan near Williamsburg",
        summaryBadges: ["$$", "2 hours", "No bars"],
        stops: [
          { order: 1, concept: "A cozy conversation starter" },
          { order: 2, concept: "A personal activity" }
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
          }
        ]
      }
    });

    expect(result.success).toBe(false);
  });
});

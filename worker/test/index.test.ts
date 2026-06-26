import { beforeEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { generateDatePlan } from "../src/openai";
import type { DatePlanResponse, GeneratePlanRequest } from "../src/schema";

const validRequest: GeneratePlanRequest = {
  locationLabel: "Williamsburg, Brooklyn",
  budgetTier: "$$",
  vibe: "cozy",
  noDrinking: true,
  durationMinutes: 120,
  partnerLikes: "bookstores, matcha, quiet places",
  regenerationAttempt: 0
};

const validPlan: DatePlanResponse = {
  id: "plan_test_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["$$", "2 hours", "No bars", "Matched to bookstores"],
    stops: [
      {
        order: 1,
        concept: "A cozy conversation starter near Williamsburg",
        vibe: "cozy",
        reason: "Starts with an easy, quiet setting for conversation.",
        personalizationSignal: "near Williamsburg"
      },
      {
        order: 2,
        concept: "A personal activity matched to bookstores",
        vibe: "personal",
        reason: "Builds the date around a shared browsing activity.",
        personalizationSignal: "bookstores"
      },
      {
        order: 3,
        concept: "A relaxed dessert finish nearby",
        vibe: "relaxed",
        reason: "Ends low-pressure with something sweet close by.",
        personalizationSignal: "quiet places"
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
        durationMinutes: 35,
        reason: "A calm first stop that fits the cozy vibe.",
        estimatedCost: "$20-$30"
      },
      {
        order: 2,
        venueName: "Example Bookstore",
        address: "456 Example Ave",
        appleMapsQuery: "Example Bookstore 456 Example Ave",
        durationMinutes: 50,
        reason: "A personal stop aligned with her interests.",
        estimatedCost: "$10-$25"
      },
      {
        order: 3,
        venueName: "Example Dessert Bar",
        address: "789 Example Rd",
        appleMapsQuery: "Example Dessert Bar 789 Example Rd",
        durationMinutes: 35,
        reason: "A relaxed finish that keeps the date low-pressure.",
        estimatedCost: "$30-$35"
      }
    ]
  }
};

vi.mock("../src/openai", () => ({
  generateDatePlan: vi.fn(async () => validPlan)
}));

beforeEach(() => {
  vi.clearAllMocks();
});

describe("POST /generate-plan", () => {
  it("returns a generated plan for a valid request", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(validPlan);
    expect(generateDatePlan).toHaveBeenCalledWith(validRequest, { OPENAI_API_KEY: "test-key" });
    expectCorsHeaders(response);
  });

  it("rejects invalid request bodies", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify({ ...validRequest, durationMinutes: 95 }),
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ error: "invalid_request" });
  });

  it("rejects invalid JSON", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: "{",
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_json" });
  });

  it("returns a retryable error when generation fails", async () => {
    vi.mocked(generateDatePlan).mockRejectedValueOnce(new Error("generation failed"));

    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({ error: "generation_failed", retryable: true });
  });

  it("returns not found for non-POST methods", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "GET"
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toEqual({ error: "not_found" });
  });
});

describe("OPTIONS /generate-plan", () => {
  it("returns 204 for the generate-plan route", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "OPTIONS"
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(204);
    await expect(response.text()).resolves.toBe("");
    expectCorsHeaders(response);
  });

  it("returns not found for other routes", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/anything", {
        method: "OPTIONS"
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toEqual({ error: "not_found" });
  });
});

function expectCorsHeaders(response: Response): void {
  expect(response.headers.get("access-control-allow-origin")).toBe("*");
  expect(response.headers.get("access-control-allow-methods")).toBe("POST, OPTIONS");
  expect(response.headers.get("access-control-allow-headers")).toBe("content-type");
}

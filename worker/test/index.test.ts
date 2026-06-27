import { beforeEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { generateDatePlan } from "../src/openai";
import type { DatePlanResponse, GeneratePlanRequest } from "../src/schema";

const validRequest: GeneratePlanRequest = {
  locationLabel: "Williamsburg, Brooklyn",
  budgetAmount: 100,
  countryCode: "US",
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
    totalEstimatedCost: "USD 60-90",
    stops: [
      {
        order: 1,
        venueName: "Example Cafe",
        address: "123 Example St",
        appleMapsQuery: "Example Cafe 123 Example St",
        durationMinutes: 35,
        reason: "A calm first stop that fits the cozy vibe.",
        estimatedCost: "USD 20-30"
      },
      {
        order: 2,
        venueName: "Example Bookstore",
        address: "456 Example Ave",
        appleMapsQuery: "Example Bookstore 456 Example Ave",
        durationMinutes: 50,
        reason: "A personal stop aligned with her interests.",
        estimatedCost: "USD 10-25"
      },
      {
        order: 3,
        venueName: "Example Dessert Bar",
        address: "789 Example Rd",
        appleMapsQuery: "Example Dessert Bar 789 Example Rd",
        durationMinutes: 35,
        reason: "A relaxed finish that keeps the date low-pressure.",
        estimatedCost: "USD 30-35"
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

  it("allows requests up to the per-client rate limit", async () => {
    for (let i = 0; i < 10; i += 1) {
      const response = await worker.fetch(
        new Request("http://localhost/generate-plan", {
          method: "POST",
          body: JSON.stringify(validRequest),
          headers: {
            "content-type": "application/json",
            "cf-connecting-ip": "203.0.113.10"
          }
        }),
        { OPENAI_API_KEY: "test-key" }
      );

      expect(response.status).toBe(200);
    }

    expect(generateDatePlan).toHaveBeenCalledTimes(10);
  });

  it("returns a retryable rate limit error after too many requests from one client", async () => {
    for (let i = 0; i < 10; i += 1) {
      await worker.fetch(
        new Request("http://localhost/generate-plan", {
          method: "POST",
          body: JSON.stringify(validRequest),
          headers: {
            "content-type": "application/json",
            "cf-connecting-ip": "203.0.113.20"
          }
        }),
        { OPENAI_API_KEY: "test-key" }
      );
    }

    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: {
          "content-type": "application/json",
          "cf-connecting-ip": "203.0.113.20"
        }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({ error: "rate_limited", retryable: true });
    expect(generateDatePlan).toHaveBeenCalledTimes(10);
    expectCorsHeaders(response);
  });

  it("tracks rate limits separately by client IP", async () => {
    for (let i = 0; i < 10; i += 1) {
      await worker.fetch(
        new Request("http://localhost/generate-plan", {
          method: "POST",
          body: JSON.stringify(validRequest),
          headers: {
            "content-type": "application/json",
            "x-forwarded-for": "203.0.113.30, 198.51.100.1"
          }
        }),
        { OPENAI_API_KEY: "test-key" }
      );
    }

    const blockedResponse = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: {
          "content-type": "application/json",
          "x-forwarded-for": "203.0.113.30, 198.51.100.1"
        }
      }),
      { OPENAI_API_KEY: "test-key" }
    );
    const allowedResponse = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "POST",
        body: JSON.stringify(validRequest),
        headers: {
          "content-type": "application/json",
          "x-forwarded-for": "203.0.113.31, 198.51.100.1"
        }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(blockedResponse.status).toBe(429);
    expect(allowedResponse.status).toBe(200);
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

describe("POST /telemetry", () => {
  it("accepts a valid telemetry event", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/telemetry", {
        method: "POST",
        body: JSON.stringify({
          eventName: "paywall_viewed",
          occurredAt: "2026-06-27T12:00:00.000Z",
          properties: {
            hasActiveSubscription: false
          }
        }),
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(202);
    await expect(response.json()).resolves.toEqual({ accepted: true });
    expectCorsHeaders(response);
  });

  it("rejects telemetry events with raw personal fields", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/telemetry", {
        method: "POST",
        body: JSON.stringify({
          eventName: "preview_generation_succeeded",
          properties: {
            locationLabel: "Williamsburg, Brooklyn",
            partnerLikes: "private context"
          }
        }),
        headers: { "content-type": "application/json" }
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_request" });
  });
});

describe("OPTIONS /generate-plan", () => {
  it("returns 204 for known routes", async () => {
    const response = await worker.fetch(
      new Request("http://localhost/generate-plan", {
        method: "OPTIONS"
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(response.status).toBe(204);
    await expect(response.text()).resolves.toBe("");
    expectCorsHeaders(response);

    const telemetryResponse = await worker.fetch(
      new Request("http://localhost/telemetry", {
        method: "OPTIONS"
      }),
      { OPENAI_API_KEY: "test-key" }
    );

    expect(telemetryResponse.status).toBe(204);
    await expect(telemetryResponse.text()).resolves.toBe("");
    expectCorsHeaders(telemetryResponse);
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

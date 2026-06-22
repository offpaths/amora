import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { buildRecoveryPrompt, generateDatePlan, parsePlanCandidate, runRecoveryLoop } from "../src/openai";
import type { DatePlanResponse, GeneratePlanRequest } from "../src/schema";

const validRequest: GeneratePlanRequest = {
  locationLabel: "Williamsburg, Brooklyn",
  budgetTier: "$$",
  vibe: "cozy",
  noDrinking: true,
  durationMinutes: 120,
  partnerLikes: "bookstores, matcha, quiet places"
};

const validPlan: DatePlanResponse = {
  id: "plan_test_123",
  preview: {
    title: "A cozy 2-hour plan near Williamsburg",
    summaryBadges: ["$$", "2 hours", "No bars", "Matched to bookstores"],
    stops: [
      { order: 1, concept: "A cozy conversation starter near Williamsburg" },
      { order: 2, concept: "A personal activity matched to bookstores" },
      { order: 3, concept: "A relaxed dessert finish nearby" }
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

const alternateValidPlan: DatePlanResponse = {
  ...validPlan,
  id: "plan_test_456",
  preview: {
    ...validPlan.preview,
    title: "A romantic 2-hour plan near Williamsburg"
  }
};

const rawOpenAIResponse = {
  output: [
    {
      type: "message",
      content: [
        { type: "output_text", text: JSON.stringify(validPlan) }
      ]
    }
  ]
};

describe("generateDatePlan", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("sends a prompt to the Responses API and parses raw output text", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(jsonResponse(rawOpenAIResponse));

    const plan = await generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" });

    expect(plan).toEqual(validPlan);
    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.openai.com/v1/responses",
      expect.objectContaining({
        method: "POST",
        headers: {
          "authorization": "Bearer test-key",
          "content-type": "application/json"
        }
      })
    );

    const [, init] = fetchMock.mock.calls[0];
    const body = JSON.parse(String(init?.body));
    expect(body).toMatchObject({
      model: "gpt-4.1-mini",
      tools: [{ type: "web_search" }]
    });
    expect(body.input).toContain("Planning area: Williamsburg, Brooklyn.");
    expect(body.input).toContain("Budget tier: $$.");
    expect(body.input).toContain("No drinking: yes, avoid alcohol-centered stops.");
    expect(body.input).toContain("Partner likes: bookstores, matcha, quiet places.");
    expect(body.input).toContain("Schema contract:");
    expect(body.input).toContain("id: string");
    expect(body.input).toContain("preview.title: string");
    expect(body.input).toContain("preview.summaryBadges: string[]");
    expect(body.input).toContain("preview.stops: exactly 3 objects with order 1, 2, 3 and concept");
    expect(body.input).toContain("lockedPlan.totalEstimatedCost: string");
    expect(body.input).toContain(
      "lockedPlan.stops: exactly 3 objects with order 1, 2, 3, venueName, address, appleMapsQuery, durationMinutes, reason, estimatedCost"
    );
    expect(body.input).toContain("No markdown. No prose outside JSON.");
    expect(body.input).toContain("Return exactly 3 preview stops and exactly 3 locked stops.");
  });

  it("continues scanning raw text candidates until it finds valid output JSON", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(
      jsonResponse({
        output: [
          {
            type: "message",
            content: [
              { type: "text", text: "not json" },
              { type: "output_text", text: JSON.stringify(validPlan) }
            ]
          }
        ]
      })
    );

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(validPlan);
  });

  it("uses valid raw output when top-level output_text is invalid", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(
      jsonResponse({
        output_text: "not json",
        output: [
          {
            type: "message",
            content: [
              { type: "output_text", text: JSON.stringify(validPlan) }
            ]
          }
        ]
      })
    );

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(validPlan);
  });

  it("skips schema-invalid JSON candidates when a later candidate is valid", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(
      jsonResponse({
        output: [
          {
            type: "message",
            content: [
              {
                type: "output_text",
                text: JSON.stringify({
                  ...validPlan,
                  preview: {
                    ...validPlan.preview,
                    stops: validPlan.preview.stops.slice(0, 2)
                  }
                })
              },
              { type: "output_text", text: JSON.stringify(validPlan) }
            ]
          }
        ]
      })
    );

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(validPlan);
  });

  it("prefers raw output_text candidates across all output items", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(
      jsonResponse({
        output: [
          {
            type: "message",
            content: [
              { type: "text", text: JSON.stringify(validPlan) }
            ]
          },
          {
            type: "message",
            content: [
              { type: "output_text", text: JSON.stringify(alternateValidPlan) }
            ]
          }
        ]
      })
    );

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(alternateValidPlan);
  });

  it("keeps output_text fallback compatibility", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(jsonResponse({ output_text: JSON.stringify(validPlan) }));

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(validPlan);
  });

  it("rejects non-OK OpenAI responses", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: "nope" }, 500));

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).rejects.toThrow(
      "OpenAI request failed with 500"
    );
  });

  it("rejects missing API keys before calling fetch", async () => {
    const fetchMock = vi.mocked(fetch);

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "" })).rejects.toThrow(
      "OPENAI_API_KEY is not configured"
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects generated plans that do not match the schema", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockImplementation(() =>
      Promise.resolve(jsonResponse({
        output: [
          {
            type: "message",
            content: [
              {
                type: "output_text",
                text: JSON.stringify({
                  ...validPlan,
                  preview: {
                    ...validPlan.preview,
                    stops: validPlan.preview.stops.slice(0, 2)
                  }
                })
              }
            ]
          }
        ]
      }))
    );

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).rejects.toThrow();
    expect(fetchMock).toHaveBeenCalledTimes(5);
  });

  it("recovers after a schema-invalid OpenAI response", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock
      .mockResolvedValueOnce(
        jsonResponse({
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    ...validPlan,
                    preview: {
                      ...validPlan.preview,
                      stops: validPlan.preview.stops.slice(0, 2)
                    }
                  })
                }
              ]
            }
          ]
        })
      )
      .mockResolvedValueOnce(jsonResponse(rawOpenAIResponse));

    await expect(generateDatePlan(validRequest, { OPENAI_API_KEY: "test-key" })).resolves.toEqual(validPlan);

    expect(fetchMock).toHaveBeenCalledTimes(2);
    const secondBody = JSON.parse(String(fetchMock.mock.calls[1][1]?.body));
    expect(secondBody.input).toContain("The previous response failed schema validation.");
    expect(secondBody.input).toContain("Validation error: No JSON candidate found in OpenAI response");
  });
});

describe("parsePlanCandidate", () => {
  it("accepts a valid candidate", () => {
    expect(parsePlanCandidate(validPlan)).toEqual(validPlan);
  });

  it("throws for invalid candidates", () => {
    expect(() => parsePlanCandidate({ ...validPlan, lockedPlan: { stops: [] } })).toThrow("invalid_plan_schema");
  });
});

describe("buildRecoveryPrompt", () => {
  it("includes validation feedback and the original prompt", () => {
    const prompt = buildRecoveryPrompt("original prompt", "lockedPlan.stops must contain 3 items");

    expect(prompt).toContain("original prompt");
    expect(prompt).toContain("lockedPlan.stops must contain 3 items");
    expect(prompt).toContain("The previous response failed schema validation.");
  });
});

describe("runRecoveryLoop", () => {
  it("returns a valid plan after an invalid attempt", async () => {
    let calls = 0;

    const result = await runRecoveryLoop("original prompt", async () => {
      calls += 1;
      return calls === 1 ? { ...validPlan, lockedPlan: { stops: [] } } : validPlan;
    });

    expect(result).toEqual(validPlan);
    expect(calls).toBe(2);
  });

  it("stops after 5 invalid attempts", async () => {
    let calls = 0;

    await expect(
      runRecoveryLoop("original prompt", async () => {
        calls += 1;
        return { ...validPlan, lockedPlan: { stops: [] } };
      })
    ).rejects.toThrow("invalid_plan_schema");

    expect(calls).toBe(5);
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" }
  });
}

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { buildPrompt, buildRecoveryPrompt, generateDatePlan, parsePlanCandidate, runRecoveryLoop, type Env } from "../src/openai";
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

function createEnv(openAIApiKey = "test-key"): Env {
  return {
    OPENAI_API_KEY: openAIApiKey,
    PLANS: {
      put: vi.fn(async () => undefined),
      get: vi.fn(async () => null)
    }
  };
}

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

    const plan = await generateDatePlan(validRequest, createEnv());

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
    expect(body.input).toContain("Estimate currency: USD.");
    expect(body.input).toContain("Budget for two: USD 100.");
    expect(body.input).toContain("Treat the budget as the user's approximate spend comfort for the full date for two people, not a target to exhaust.");
    expect(body.input).toContain("Prefer plans with total estimated cost around or below USD 100 when realistic.");
    expect(body.input).toContain("No drinking: yes, avoid alcohol-centered stops.");
    expect(body.input).toContain("Regeneration attempt: 0.");
    expect(body.input).toContain("This is the first generated plan for these inputs.");
    expect(body.input).toContain("Partner likes or pasted context: bookstores, matcha, quiet places.");
    expect(body.input).toContain("The partner likes field may contain a clean summary or pasted chat/note context.");
    expect(body.input).toContain("Extract only date-planning signals that are clearly supported by the provided text.");
    expect(body.input).toContain("Do not psychoanalyze, infer sensitive traits, or make claims about the person beyond the provided context.");
    expect(body.input).toContain("Write locked-stop reasons from the recipient's perspective.");
    expect(body.input).toContain("Explain how each locked stop reflects her stated preferences, comfort, energy, and desired vibe.");
    expect(body.input).toContain("Do not promise emotional outcomes or say the plan will make her feel a specific way.");
    expect(body.input).toContain("Estimate costs for two people using USD.");
    expect(body.input).toContain("Paid locked cost estimates must begin with USD.");
    expect(body.input).toContain("Use exactly Free for zero-cost stops.");
    expect(body.input).toContain("Schema contract:");
    expect(body.input).toContain("id: string");
    expect(body.input).toContain("preview.title: string");
    expect(body.input).toContain("preview.summaryBadges: string[]");
    expect(body.input).toContain("preview.stops: exactly 3 objects with order 1, 2, 3, concept, vibe, reason, personalizationSignal");
    expect(body.input).toContain("lockedPlan.totalEstimatedCost: string");
    expect(body.input).toContain(
      "lockedPlan.stops: exactly 3 objects with order 1, 2, 3, venueName, address, appleMapsQuery, durationMinutes, reason, estimatedCost"
    );
    expect(body.input).toContain("No markdown. No prose outside JSON.");
    expect(body.input).toContain("Return exactly 3 preview stops and exactly 3 locked stops.");
  });

  it("includes activity-led planning guidance in the prompt", () => {
    const prompt = buildPrompt({
      ...validRequest,
      vibe: "adventurous",
      partnerLikes: "axe throwing, dumplings, playful competition"
    });

    expect(prompt).toContain("Prioritize activities explicitly mentioned in the partner likes or pasted context before inventing unrelated activity ideas.");
    expect(prompt).toContain("For adventurous, playful, active, novelty, romantic, outdoorsy, cozy, low-key, or foodie vibes, consider one activity-led stop when it fits the planning area, budget, duration, and no-drinking constraint.");
    expect(prompt).toContain("Activity-led stops can include axe throwing, bowling, pottery painting, mini golf, arcades, climbing, cooking classes, bookstores, galleries, museums, dance classes, markets, or similarly specific local experiences.");
    expect(prompt).toContain("Restaurants, bars, coffee shops, parks, and walks may support the plan, but they should not become the default shape of most plans when a realistic activity-led option would feel more personal or memorable.");
    expect(prompt).toContain("Do not force an activity stop when the area, budget, duration, or personal context makes it unrealistic.");
  });

  it("asks for a meaningfully different itinerary on regeneration", () => {
    const prompt = buildPrompt({ ...validRequest, regenerationAttempt: 1 });

    expect(prompt).toContain("Regeneration attempt: 1.");
    expect(prompt).toContain("This is a regenerated plan.");
    expect(prompt).toContain("use different venue choices, a different stop sequence, and different preview concepts");
    expect(prompt).toContain("Do not simply reword the same plan.");
  });

  it("describes a zero budget as free", () => {
    const prompt = buildPrompt({ ...validRequest, budgetAmount: 0 });

    expect(prompt).toContain("Budget for two: Free.");
    expect(prompt).toContain("Prioritize free stops and only include paid options when there is no realistic free alternative.");
    expect(prompt).not.toContain("Budget for two: USD 0.");
    expect(prompt).not.toContain("around or below USD 0");
  });

  it("rejects generated plans that use the wrong country currency", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockImplementation(() =>
      Promise.resolve(jsonResponse({
        output: [
          {
            type: "message",
            content: [
              { type: "output_text", text: JSON.stringify(validPlan) }
            ]
          }
        ]
      }))
    );

    await expect(
      generateDatePlan({ ...validRequest, countryCode: "GB" }, createEnv())
    ).rejects.toThrow("invalid_plan_currency");
    expect(fetchMock).toHaveBeenCalledTimes(5);
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

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(validPlan);
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

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(validPlan);
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

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(validPlan);
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

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(alternateValidPlan);
  });

  it("keeps output_text fallback compatibility", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(jsonResponse({ output_text: JSON.stringify(validPlan) }));

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(validPlan);
  });

  it("rejects non-OK OpenAI responses", async () => {
    const fetchMock = vi.mocked(fetch);
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: "nope" }, 500));

    await expect(generateDatePlan(validRequest, createEnv())).rejects.toThrow(
      "OpenAI request failed with 500"
    );
  });

  it("rejects missing API keys before calling fetch", async () => {
    const fetchMock = vi.mocked(fetch);

    await expect(generateDatePlan(validRequest, createEnv(""))).rejects.toThrow(
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

    await expect(generateDatePlan(validRequest, createEnv())).rejects.toThrow();
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

    await expect(generateDatePlan(validRequest, createEnv())).resolves.toEqual(validPlan);

    expect(fetchMock).toHaveBeenCalledTimes(2);
    const secondBody = JSON.parse(String(fetchMock.mock.calls[1][1]?.body));
    expect(secondBody.input).toContain("The previous response failed schema validation.");
    expect(secondBody.input).toContain("Validation error: No JSON candidate found in OpenAI response");
  });
});

describe("parsePlanCandidate", () => {
  it("accepts a valid candidate", () => {
    expect(parsePlanCandidate(validPlan, "USD")).toEqual(validPlan);
  });

  it("throws for invalid candidates", () => {
    expect(() => parsePlanCandidate({ ...validPlan, lockedPlan: { stops: [] } }, "USD")).toThrow("invalid_plan_schema");
  });

  it("throws when a valid candidate uses the wrong currency", () => {
    expect(() => parsePlanCandidate(validPlan, "GBP")).toThrow("invalid_plan_currency");
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

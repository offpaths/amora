import { DatePlanResponseSchema, type DatePlanResponse, type GeneratePlanRequest } from "./schema";

export interface Env {
  OPENAI_API_KEY: string;
}

export async function generateDatePlan(input: GeneratePlanRequest, env: Env): Promise<DatePlanResponse> {
  if (!env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const prompt = buildPrompt(input);
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      tools: [{ type: "web_search" }],
      input: prompt
    })
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
    "Schema contract:",
    "id: string",
    "preview.title: string",
    "preview.summaryBadges: string[]",
    "preview.stops: exactly 3 objects with order 1, 2, 3 and concept",
    "lockedPlan.totalEstimatedCost: string",
    "lockedPlan.stops: exactly 3 objects with order 1, 2, 3, venueName, address, appleMapsQuery, durationMinutes, reason, estimatedCost",
    "Do not include current events. Do not reveal exact venues in preview concepts.",
    "No markdown. No prose outside JSON.",
    "Return exactly 3 preview stops and exactly 3 locked stops."
  ].join("\n");
}

function extractJsonCandidate(payload: unknown): unknown {
  if (typeof payload === "object" && payload !== null && "output_text" in payload) {
    const text = String((payload as { output_text: unknown }).output_text);
    return JSON.parse(text);
  }

  if (typeof payload === "object" && payload !== null && "output" in payload) {
    const output = (payload as { output: unknown }).output;
    if (Array.isArray(output)) {
      for (const item of output) {
        if (typeof item !== "object" || item === null || !("content" in item)) {
          continue;
        }

        const content = (item as { content: unknown }).content;
        if (!Array.isArray(content)) {
          continue;
        }

        const textParts = content.filter(hasText);
        const orderedTextParts = [
          ...textParts.filter((part) => part.type === "output_text"),
          ...textParts.filter((part) => part.type !== "output_text")
        ];

        for (const part of orderedTextParts) {
          const candidate = parseJsonCandidate(String(part.text));
          if (candidate !== undefined) {
            return candidate;
          }
        }
      }
    }
  }

  throw new Error("No JSON candidate found in OpenAI response");
}

function hasText(part: unknown): part is { type?: unknown; text: unknown } {
  return typeof part === "object" && part !== null && "text" in part;
}

function parseJsonCandidate(text: string): unknown | undefined {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

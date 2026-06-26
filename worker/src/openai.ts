import { DatePlanResponseSchema, type DatePlanResponse, type GeneratePlanRequest } from "./schema";

export interface Env {
  OPENAI_API_KEY: string;
}

export async function generateDatePlan(input: GeneratePlanRequest, env: Env): Promise<DatePlanResponse> {
  if (!env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const initialPrompt = buildPrompt(input);
  return runRecoveryLoop(initialPrompt, (prompt) => callOpenAIForCandidate(prompt, env));
}

async function callOpenAIForCandidate(prompt: string, env: Env): Promise<unknown> {
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
  return extractDatePlanCandidate(payload);
}

export async function runRecoveryLoop(
  initialPrompt: string,
  generateCandidate: (prompt: string) => Promise<unknown>
): Promise<DatePlanResponse> {
  let prompt = initialPrompt;
  let lastError = "invalid_plan_schema";

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    let candidate: unknown;
    try {
      candidate = await generateCandidate(prompt);
    } catch (error) {
      if (!isRecoverableGenerationError(error)) {
        throw error;
      }
      lastError = error instanceof Error ? error.message : "invalid_plan_schema";
      prompt = buildRecoveryPrompt(initialPrompt, lastError);
      continue;
    }

    try {
      return parsePlanCandidate(candidate);
    } catch (error) {
      lastError = error instanceof Error ? error.message : "invalid_plan_schema";
      prompt = buildRecoveryPrompt(initialPrompt, lastError);
    }
  }

  throw new Error(lastError);
}

export function parsePlanCandidate(candidate: unknown): DatePlanResponse {
  const parsed = DatePlanResponseSchema.safeParse(candidate);
  if (parsed.success) {
    return parsed.data;
  }
  throw new Error("invalid_plan_schema");
}

export function buildRecoveryPrompt(originalPrompt: string, validationError: string): string {
  return [
    originalPrompt,
    "",
    "The previous response failed schema validation.",
    `Validation error: ${validationError}`,
    "Correct the response and return a complete valid plan with exactly 3 preview stops and exactly 3 locked stops.",
    "Keep the same JSON schema contract. No markdown. No prose outside JSON."
  ].join("\n");
}

export function buildPrompt(input: GeneratePlanRequest): string {
  return [
    "Generate a premium date plan for Amora.",
    "Return only valid JSON matching the required plan schema.",
    "If validation feedback is provided, correct the response and try again.",
    "Maximum recovery steps are handled by the server; keep each attempt concise.",
    `Planning area: ${input.locationLabel}. Treat this as the planning area, not the whole metro region.`,
    "Prefer stops close to this area and close enough for a short walk or short rideshare.",
    `Budget tier: ${input.budgetTier}.`,
    `Vibe: ${input.vibe}.`,
    `Duration: ${input.durationMinutes} minutes.`,
    `No drinking: ${input.noDrinking ? "yes, avoid alcohol-centered stops" : "no"}.`,
    `Regeneration attempt: ${input.regenerationAttempt}.`,
    input.regenerationAttempt > 0
      ? "This is a regenerated plan. Keep the same user preferences, area, budget, and constraints, but produce a meaningfully different itinerary from a typical first answer: use different venue choices, a different stop sequence, and different preview concepts where possible. Do not simply reword the same plan."
      : "This is the first generated plan for these inputs.",
    `Partner likes or pasted context: ${input.partnerLikes || "not provided"}.`,
    "The partner likes field may contain a clean summary or pasted chat/note context.",
    "Extract only date-planning signals that are clearly supported by the provided text.",
    "Useful signals include likes, dislikes, food or drink preferences, vibe clues, activities or places mentioned, timing clues, comfort constraints, and personal details that can make the plan feel considered.",
    "Do not psychoanalyze, infer sensitive traits, or make claims about the person beyond the provided context.",
    "Separate strong signals from weak guesses internally; only use weak guesses when phrased cautiously.",
    "Make the plan feel specific to this person and moment, not like a reusable generic route.",
    "Use the personal context in preview concepts, preview reasons, preview personalization signals, and locked-stop reasons when provided.",
    "Avoid plans that could be copy-pasted for different people without changing the personal logic.",
    "Estimate costs for two people using the common local currency of the planning area. Use broad ranges, not exact prices. If local currency is uncertain, choose the most likely currency from the planning area and keep estimates approximate.",
    "Schema contract:",
    "id: string",
    "preview.title: string",
    "preview.summaryBadges: string[]",
    "preview.stops: exactly 3 objects with order 1, 2, 3, concept, vibe, reason, personalizationSignal",
    "lockedPlan.totalEstimatedCost: string",
    "lockedPlan.stops: exactly 3 objects with order 1, 2, 3, venueName, address, appleMapsQuery, durationMinutes, reason, estimatedCost",
    "Do not include current events. Do not reveal exact venues in preview concepts.",
    "No markdown. No prose outside JSON.",
    "Return exactly 3 preview stops and exactly 3 locked stops."
  ].join("\n");
}

function extractDatePlanCandidate(payload: unknown): DatePlanResponse {
  const rawOutputTextCandidates: string[] = [];
  const rawOtherTextCandidates: string[] = [];

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

        for (const part of content.filter(hasText)) {
          if (part.type === "output_text") {
            rawOutputTextCandidates.push(String(part.text));
          } else {
            rawOtherTextCandidates.push(String(part.text));
          }
        }
      }
    }
  }

  const candidates = [...rawOutputTextCandidates, ...rawOtherTextCandidates];

  if (typeof payload === "object" && payload !== null && "output_text" in payload) {
    candidates.push(String((payload as { output_text: unknown }).output_text));
  }

  for (const text of candidates) {
    const candidate = parseJsonCandidate(text);
    if (candidate === undefined) {
      continue;
    }

    const parsed = DatePlanResponseSchema.safeParse(candidate);
    if (parsed.success) {
      return parsed.data;
    }
  }

  throw new Error("No JSON candidate found in OpenAI response");
}

function isRecoverableGenerationError(error: unknown): boolean {
  return error instanceof Error && error.message === "No JSON candidate found in OpenAI response";
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

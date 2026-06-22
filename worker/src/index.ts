import { generateDatePlan, type Env } from "./openai";
import { GeneratePlanRequestSchema } from "./schema";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname !== "/generate-plan") {
      return json({ error: "not_found" }, 404);
    }

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders()
      });
    }

    if (request.method !== "POST") {
      return json({ error: "not_found" }, 404);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const parsed = GeneratePlanRequestSchema.safeParse(body);
    if (!parsed.success) {
      return json({ error: "invalid_request" }, 400);
    }

    try {
      const plan = await generateDatePlan(parsed.data, env);
      return json(plan, 200);
    } catch {
      return json({ error: "generation_failed", retryable: true }, 502);
    }
  }
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      ...corsHeaders()
    }
  });
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type"
  };
}

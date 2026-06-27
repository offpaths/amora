import { generateDatePlan, type Env } from "./openai";
import { GeneratePlanRequestSchema, TelemetryEventSchema } from "./schema";

const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const rateLimitBuckets = new Map<string, { count: number; resetAt: number }>();

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname !== "/generate-plan" && url.pathname !== "/telemetry") {
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

    if (url.pathname === "/telemetry") {
      return handleTelemetry(request);
    }

    if (isRateLimited(request)) {
      return json({ error: "rate_limited", retryable: true }, 429);
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

async function handleTelemetry(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const parsed = TelemetryEventSchema.safeParse(body);
  if (!parsed.success) {
    return json({ error: "invalid_request" }, 400);
  }

  console.log("telemetry_event", JSON.stringify(parsed.data));
  return json({ accepted: true }, 202);
}

function isRateLimited(request: Request): boolean {
  const now = Date.now();
  const clientKey = getClientKey(request);
  const bucket = rateLimitBuckets.get(clientKey);

  if (!bucket || bucket.resetAt <= now) {
    rateLimitBuckets.set(clientKey, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }

  if (bucket.count >= RATE_LIMIT_MAX_REQUESTS) {
    return true;
  }

  bucket.count += 1;
  return false;
}

function getClientKey(request: Request): string {
  const cloudflareIp = request.headers.get("cf-connecting-ip")?.trim();
  if (cloudflareIp) {
    return cloudflareIp;
  }

  const forwardedFor = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwardedFor || "unknown";
}

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

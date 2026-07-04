import { generateDatePlan, type Env } from "./openai";
import { createPlanToken, storeLockedPlan } from "./plan-store";
import { GeneratePlanRequestSchema } from "./schema";

const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const MAX_REQUEST_BYTES = 16 * 1024;

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

export interface WorkerEnv extends Env {
  RATE_LIMITER: DurableObjectNamespace;
}

export default {
  async fetch(request: Request, env: WorkerEnv): Promise<Response> {
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

    if (isRequestTooLarge(request)) {
      return json({ error: "request_too_large" }, 413);
    }

    if (await isRateLimited(request, env)) {
      return json({ error: "rate_limited", retryable: true }, 429);
    }

    let body: unknown;
    try {
      body = await readJsonBody(request);
    } catch (error) {
      if (error instanceof RequestTooLargeError) {
        return json({ error: "request_too_large" }, 413);
      }
      return json({ error: "invalid_json" }, 400);
    }

    const parsed = GeneratePlanRequestSchema.safeParse(body);
    if (!parsed.success) {
      return json({ error: "invalid_request" }, 400);
    }

    try {
      const plan = await generateDatePlan(parsed.data, env);
      const planToken = createPlanToken();
      await storeLockedPlan(env.PLANS, planToken, plan);
      return json({ id: plan.id, planToken, preview: plan.preview }, 200);
    } catch {
      return json({ error: "generation_failed", retryable: true }, 502);
    }
  }
};

class RequestTooLargeError extends Error {}

async function readJsonBody(request: Request): Promise<unknown> {
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_REQUEST_BYTES) {
    throw new RequestTooLargeError();
  }

  return JSON.parse(text);
}

export class RateLimiter {
  constructor(private readonly state: DurableObjectState) {}

  async fetch(): Promise<Response> {
    const now = Date.now();
    const bucket = await this.state.storage.get<RateLimitBucket>("bucket");

    if (!bucket || bucket.resetAt <= now) {
      await this.state.storage.put("bucket", { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
      return new Response(null, { status: 204 });
    }

    if (bucket.count >= RATE_LIMIT_MAX_REQUESTS) {
      return new Response(null, { status: 429 });
    }

    await this.state.storage.put("bucket", { count: bucket.count + 1, resetAt: bucket.resetAt });
    return new Response(null, { status: 204 });
  }
}

async function isRateLimited(request: Request, env: WorkerEnv): Promise<boolean> {
  const clientKey = getClientKey(request);
  const id = env.RATE_LIMITER.idFromName(clientKey);
  const stub = env.RATE_LIMITER.get(id);
  const response = await stub.fetch("https://rate-limiter/check", { method: "POST" });
  return response.status === 429;
}

function getClientKey(request: Request): string {
  const cloudflareIp = request.headers.get("cf-connecting-ip")?.trim();
  if (cloudflareIp) {
    return cloudflareIp;
  }

  const forwardedFor = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwardedFor || "unknown";
}

function isRequestTooLarge(request: Request): boolean {
  const contentLength = request.headers.get("content-length");
  if (!contentLength) {
    return false;
  }

  const parsedLength = Number(contentLength);
  return Number.isFinite(parsedLength) && parsedLength > MAX_REQUEST_BYTES;
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

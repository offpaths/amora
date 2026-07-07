import { verifyActiveSubscriptionProof } from "./app-store";
import { generateDatePlan, type Env } from "./openai";
import { createPlanToken, loadLockedPlan, storeLockedPlan } from "./plan-store";
import { GeneratePlanRequestSchema, UnlockPlanRequestSchema } from "./schema";

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

    if (!isKnownRoute(url.pathname)) {
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

    if (url.pathname === "/unlock-plan") {
      return handleUnlockPlan(request, env);
    }

    return handleGeneratePlan(request, env);
  }
};

async function handleGeneratePlan(request: Request, env: WorkerEnv): Promise<Response> {
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

  let shouldReturnUnlockedPlan = false;
  if (parsed.data.signedTransactionInfo) {
    try {
      shouldReturnUnlockedPlan = await verifyActiveSubscriptionProof(parsed.data.signedTransactionInfo, env);
    } catch (error) {
      console.error("subscription_verification_failed", sanitizeError(error));
      return json({ error: "subscription_verification_failed", retryable: true }, 502);
    }

    if (!shouldReturnUnlockedPlan) {
      return json({ error: "subscription_required" }, 403);
    }
  }

  try {
    const plan = await generateDatePlan(parsed.data, env);
    if (shouldReturnUnlockedPlan) {
      return json(plan, 200);
    }

    const planToken = createPlanToken();
    await storeLockedPlan(env.PLANS, planToken, plan);
    return json({ id: plan.id, planToken, preview: plan.preview }, 200);
  } catch (error) {
    console.error("generate_plan_failed", sanitizeError(error));
    return json({ error: "generation_failed", retryable: true }, 502);
  }
}

async function handleUnlockPlan(request: Request, env: WorkerEnv): Promise<Response> {
  let body: unknown;
  try {
    body = await readJsonBody(request);
  } catch (error) {
    if (error instanceof RequestTooLargeError) {
      return json({ error: "request_too_large" }, 413);
    }
    return json({ error: "invalid_json" }, 400);
  }

  const parsed = UnlockPlanRequestSchema.safeParse(body);
  if (!parsed.success) {
    return json({ error: "invalid_request" }, 400);
  }

  let hasActiveSubscription: boolean;
  try {
    hasActiveSubscription = await verifyActiveSubscriptionProof(parsed.data.signedTransactionInfo, env);
  } catch (error) {
    console.error("subscription_verification_failed", sanitizeError(error));
    return json({ error: "subscription_verification_failed", retryable: true }, 502);
  }

  if (!hasActiveSubscription) {
    return json({ error: "subscription_required" }, 403);
  }

  const plan = await loadLockedPlan(env.PLANS, parsed.data.planToken);
  if (!plan) {
    return json({ error: "plan_not_found" }, 404);
  }

  return json(plan, 200);
}

function isKnownRoute(pathname: string): boolean {
  return pathname === "/generate-plan" || pathname === "/unlock-plan";
}

function sanitizeError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    const sanitized: Record<string, unknown> = {
      name: error.name,
      constructorName: error.constructor.name,
      message: error.message
    };
    if (hasNumericStatus(error)) {
      sanitized.status = error.status;
      sanitized.statusName = verificationStatusName(error.status);
    }
    if (error.cause instanceof Error) {
      sanitized.cause = {
        name: error.cause.name,
        constructorName: error.cause.constructor.name,
        message: error.cause.message
      };
    }
    return sanitized;
  }
  return { name: "UnknownError", message: "unknown" };
}

function hasNumericStatus(error: Error): error is Error & { status: number } {
  return "status" in error && typeof (error as { status?: unknown }).status === "number";
}

function verificationStatusName(status: number): string {
  return {
    0: "OK",
    1: "VERIFICATION_FAILURE",
    2: "RETRYABLE_VERIFICATION_FAILURE",
    3: "INVALID_APP_IDENTIFIER",
    4: "INVALID_ENVIRONMENT",
    5: "INVALID_CHAIN_LENGTH",
    6: "INVALID_CERTIFICATE",
    7: "FAILURE"
  }[status] ?? "UNKNOWN";
}

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

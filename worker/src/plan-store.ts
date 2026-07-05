import { UnlockPlanResponseSchema, type DatePlanResponse, type UnlockPlanResponse } from "./schema";

export interface LockedPlanKV {
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
  get(key: string): Promise<string | null>;
}

const LOCKED_PLAN_TTL_SECONDS = 24 * 60 * 60;
const TOKEN_BYTES = 32;

export function createPlanToken(): string {
  const bytes = new Uint8Array(TOKEN_BYTES);
  crypto.getRandomValues(bytes);
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function storeLockedPlan(kv: LockedPlanKV, token: string, plan: DatePlanResponse): Promise<void> {
  const unlockPayload: UnlockPlanResponse = {
    id: plan.id,
    lockedPlan: plan.lockedPlan
  };

  await kv.put(storageKey(token), JSON.stringify(unlockPayload), {
    expirationTtl: LOCKED_PLAN_TTL_SECONDS
  });
}

export async function loadLockedPlan(kv: LockedPlanKV, token: string): Promise<UnlockPlanResponse | undefined> {
  const rawValue = await kv.get(storageKey(token));
  if (!rawValue) {
    return undefined;
  }

  try {
    return UnlockPlanResponseSchema.parse(JSON.parse(rawValue));
  } catch {
    return undefined;
  }
}

function storageKey(token: string): string {
  return `locked-plan:${token}`;
}

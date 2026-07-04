import { describe, expect, it, vi } from "vitest";
import { isActiveAmoraPlusTransaction, verifyActiveSubscriptionProof } from "../src/app-store";
import type { Env } from "../src/openai";

const baseEnv: Env = {
  OPENAI_API_KEY: "test-key",
  PLANS: {
    put: async () => {},
    get: async () => null
  },
  APP_STORE_BUNDLE_ID: "com.planwithamora.Amora",
  APP_STORE_ENVIRONMENT: "Sandbox",
  APP_STORE_APP_APPLE_ID: "1234567890"
};

describe("isActiveAmoraPlusTransaction", () => {
  it("returns true for an active Amora Plus signed transaction payload", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(true);
  });

  it("returns false for expired transactions", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() - 1000
    }, baseEnv)).toBe(false);
  });

  it("returns false for revoked transactions", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000,
      revocationDate: Date.now()
    }, baseEnv)).toBe(false);
  });

  it("returns false for another product id", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.planwithamora.Amora",
      productId: "other_product",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(false);
  });

  it("returns false for another bundle id", () => {
    expect(isActiveAmoraPlusTransaction({
      bundleId: "com.example.Other",
      productId: "amora_plus_monthly",
      environment: "Sandbox",
      expiresDate: Date.now() + 86_400_000
    }, baseEnv)).toBe(false);
  });
});

describe("verifyActiveSubscriptionProof", () => {
  it("verifies signed proof through the supplied verifier and ignores purchaser profile fields", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => ({
        bundleId: "com.planwithamora.Amora",
        productId: "amora_plus_monthly",
        environment: "Sandbox",
        expiresDate: Date.now() + 86_400_000,
        appAccountToken: "ignored-purchaser-linkage"
      }))
    };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", baseEnv, verifier)).resolves.toBe(true);
    expect(verifier.verifyAndDecodeTransaction).toHaveBeenCalledWith("apple.signed.transaction.jws");
  });

  it("returns false when signed proof verification fails", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => {
        throw new Error("verification failed");
      })
    };

    await expect(verifyActiveSubscriptionProof("bad-proof", baseEnv, verifier)).resolves.toBe(false);
  });
});

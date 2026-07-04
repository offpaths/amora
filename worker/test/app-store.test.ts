import { describe, expect, it, vi } from "vitest";
import { VerificationException, VerificationStatus } from "@apple/app-store-server-library";
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

  it("returns false when signed proof verification has an ordinary verification failure", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => {
        throw new VerificationException(VerificationStatus.VERIFICATION_FAILURE);
      })
    };

    await expect(verifyActiveSubscriptionProof("bad-proof", baseEnv, verifier)).resolves.toBe(false);
  });

  it("throws when signed proof verification has a retryable verification failure", async () => {
    const error = new VerificationException(VerificationStatus.RETRYABLE_VERIFICATION_FAILURE);
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => {
        throw error;
      })
    };

    await expect(verifyActiveSubscriptionProof("retryable-proof", baseEnv, verifier)).rejects.toBe(error);
  });

  it("throws when the verifier has an unexpected infrastructure error", async () => {
    const error = new Error("certificate fetch failed");
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => {
        throw error;
      })
    };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", baseEnv, verifier)).rejects.toBe(error);
  });

  it("returns false when the bundle id is missing", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => ({
        bundleId: "com.planwithamora.Amora",
        productId: "amora_plus_monthly",
        environment: "Sandbox",
        expiresDate: Date.now() + 86_400_000
      }))
    };
    const env = { ...baseEnv, APP_STORE_BUNDLE_ID: undefined };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", env, verifier)).resolves.toBe(false);
    expect(verifier.verifyAndDecodeTransaction).not.toHaveBeenCalled();
  });

  it("returns false when Production is missing the app Apple ID", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => ({
        bundleId: "com.planwithamora.Amora",
        productId: "amora_plus_monthly",
        environment: "Production",
        expiresDate: Date.now() + 86_400_000
      }))
    };
    const env = {
      ...baseEnv,
      APP_STORE_ENVIRONMENT: "Production",
      APP_STORE_APP_APPLE_ID: undefined
    };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", env, verifier)).resolves.toBe(false);
    expect(verifier.verifyAndDecodeTransaction).not.toHaveBeenCalled();
  });

  it.each(["not-a-number", "NaN", "0", "-1"])(
    "returns false when Production has invalid app Apple ID %s",
    async (appAppleId) => {
      const verifier = {
        verifyAndDecodeTransaction: vi.fn(async () => ({
          bundleId: "com.planwithamora.Amora",
          productId: "amora_plus_monthly",
          environment: "Production",
          expiresDate: Date.now() + 86_400_000
        }))
      };
      const env = {
        ...baseEnv,
        APP_STORE_ENVIRONMENT: "Production",
        APP_STORE_APP_APPLE_ID: appAppleId
      };

      await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", env, verifier)).resolves.toBe(false);
      expect(verifier.verifyAndDecodeTransaction).not.toHaveBeenCalled();
    }
  );

  it("returns false when the configured App Store environment is invalid", async () => {
    const verifier = {
      verifyAndDecodeTransaction: vi.fn(async () => ({
        bundleId: "com.planwithamora.Amora",
        productId: "amora_plus_monthly",
        environment: "Staging",
        expiresDate: Date.now() + 86_400_000
      }))
    };
    const env = { ...baseEnv, APP_STORE_ENVIRONMENT: "Staging" };

    await expect(verifyActiveSubscriptionProof("apple.signed.transaction.jws", env, verifier)).resolves.toBe(false);
    expect(verifier.verifyAndDecodeTransaction).not.toHaveBeenCalled();
  });
});

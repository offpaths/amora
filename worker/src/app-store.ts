import { Buffer } from "node:buffer";
import type { Env } from "./openai";

const PLUS_PRODUCT_ID = "amora_plus_monthly";
const RETRYABLE_VERIFICATION_FAILURE = 2;
const APPLE_ROOT_CERTIFICATE_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G4.cer"
];

interface TransactionPayload {
  bundleId?: string;
  productId?: string;
  environment?: string;
  expiresDate?: number | string;
  revocationDate?: number | string;
}

interface TransactionVerifier {
  verifyAndDecodeTransaction(signedTransactionInfo: string): Promise<TransactionPayload>;
}

let cachedRootCertificates: Buffer[] | undefined;
const cachedVerifiers = new Map<string, TransactionVerifier>();

export async function verifyActiveSubscriptionProof(
  signedTransactionInfo: string,
  env: Env,
  verifier?: TransactionVerifier
): Promise<boolean> {
  try {
    const config = resolveAppStoreConfig(env);
    const activeVerifier = verifier ?? await createVerifier(config);
    const payload = await activeVerifier.verifyAndDecodeTransaction(signedTransactionInfo);
    return isActiveAmoraPlusTransactionForConfig(payload, config);
  } catch (error) {
    if (error instanceof AppStoreConfigError) {
      return false;
    }
    if (isAppleVerificationError(error)) {
      if (error.status === RETRYABLE_VERIFICATION_FAILURE) {
        throw error;
      }
      return false;
    }
    throw error;
  }
}

export function isActiveAmoraPlusTransaction(payload: TransactionPayload, env: Env): boolean {
  return isActiveAmoraPlusTransactionForConfig(payload, resolveAppStoreConfig(env));
}

function isActiveAmoraPlusTransactionForConfig(
  payload: TransactionPayload,
  config: AppStoreConfig
): boolean {
  if (payload.bundleId !== config.bundleId) {
    return false;
  }
  if (payload.productId !== PLUS_PRODUCT_ID) {
    return false;
  }
  if (payload.environment !== config.environment) {
    return false;
  }
  const expiresDate = Number(payload.expiresDate);
  if (!Number.isFinite(expiresDate) || expiresDate <= Date.now()) {
    return false;
  }
  return payload.revocationDate === undefined;
}

async function createVerifier(config: AppStoreConfig): Promise<TransactionVerifier> {
  const cacheKey = `${config.environment}:${config.bundleId}:${config.appAppleId ?? ""}`;
  const cachedVerifier = cachedVerifiers.get(cacheKey);
  if (cachedVerifier) {
    return cachedVerifier;
  }

  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  const environment = config.environment === "Production" ? Environment.PRODUCTION : Environment.SANDBOX;
  const verifier = new SignedDataVerifier(
    await loadAppleRootCertificates(),
    true,
    environment,
    config.bundleId,
    config.appAppleId
  );
  cachedVerifiers.set(cacheKey, verifier);
  return verifier;
}

async function loadAppleRootCertificates(): Promise<Buffer[]> {
  if (cachedRootCertificates) {
    return cachedRootCertificates;
  }

  cachedRootCertificates = await Promise.all(APPLE_ROOT_CERTIFICATE_URLS.map(async (url) => {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error("apple_root_certificate_fetch_failed");
    }
    return Buffer.from(await response.arrayBuffer());
  }));
  return cachedRootCertificates;
}

function isAppleVerificationError(error: unknown): error is { status: number } {
  return typeof error === "object"
    && error !== null
    && "status" in error
    && typeof (error as { status?: unknown }).status === "number";
}

class AppStoreConfigError extends Error {}

function required(value: string | undefined): string {
  if (!value) {
    throw new AppStoreConfigError("app_store_not_configured");
  }
  return value;
}

interface AppStoreConfig {
  bundleId: string;
  environment: "Sandbox" | "Production";
  appAppleId?: number;
}

function resolveAppStoreConfig(env: Env): AppStoreConfig {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const environment = env.APP_STORE_ENVIRONMENT ?? "Sandbox";
  if (environment !== "Sandbox" && environment !== "Production") {
    throw new AppStoreConfigError("app_store_invalid_environment");
  }

  if (environment === "Sandbox") {
    return { bundleId, environment };
  }

  const appAppleId = Number(env.APP_STORE_APP_APPLE_ID);
  if (!Number.isFinite(appAppleId) || appAppleId <= 0 || !Number.isInteger(appAppleId)) {
    throw new AppStoreConfigError("app_store_invalid_app_apple_id");
  }
  return { bundleId, environment, appAppleId };
}

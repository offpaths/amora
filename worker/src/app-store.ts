import { Buffer } from "node:buffer";
import { Environment, SignedDataVerifier, type JWSTransactionDecodedPayload } from "@apple/app-store-server-library";
import type { Env } from "./openai";

const PLUS_PRODUCT_ID = "amora_plus_monthly";
const APPLE_ROOT_CERTIFICATE_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G4.cer"
];

type TransactionVerifier = Pick<SignedDataVerifier, "verifyAndDecodeTransaction">;

let cachedRootCertificates: Buffer[] | undefined;

export async function verifyActiveSubscriptionProof(
  signedTransactionInfo: string,
  env: Env,
  verifier?: TransactionVerifier
): Promise<boolean> {
  try {
    const activeVerifier = verifier ?? await createVerifier(env);
    const payload = await activeVerifier.verifyAndDecodeTransaction(signedTransactionInfo);
    return isActiveAmoraPlusTransaction(payload, env);
  } catch {
    return false;
  }
}

export function isActiveAmoraPlusTransaction(payload: JWSTransactionDecodedPayload, env: Env): boolean {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const environment = env.APP_STORE_ENVIRONMENT ?? "Sandbox";

  if (payload.bundleId !== bundleId) {
    return false;
  }
  if (payload.productId !== PLUS_PRODUCT_ID) {
    return false;
  }
  if (payload.environment !== environment) {
    return false;
  }
  const expiresDate = Number(payload.expiresDate);
  if (!Number.isFinite(expiresDate) || expiresDate <= Date.now()) {
    return false;
  }
  return payload.revocationDate === undefined;
}

async function createVerifier(env: Env): Promise<TransactionVerifier> {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const environment = env.APP_STORE_ENVIRONMENT === "Production" ? Environment.PRODUCTION : Environment.SANDBOX;
  const appAppleId = env.APP_STORE_APP_APPLE_ID ? Number(env.APP_STORE_APP_APPLE_ID) : undefined;
  return new SignedDataVerifier(await loadAppleRootCertificates(), true, environment, bundleId, appAppleId);
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

function required(value: string | undefined): string {
  if (!value) {
    throw new Error("app_store_not_configured");
  }
  return value;
}

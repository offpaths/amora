import { Buffer } from "node:buffer";
import type { Env } from "./openai";

const PLUS_PRODUCT_ID = "amora_plus_monthly";
const RETRYABLE_VERIFICATION_FAILURE = 2;
const ENABLE_APPLE_ONLINE_CERTIFICATE_CHECKS = false;
const STOREKIT_ENVIRONMENTS = ["Sandbox", "Production"] as const;
const APPLE_ROOT_CERTIFICATES_BASE64 = [
  // Apple Root CA - G2, DER from https://www.apple.com/certificateauthority/
  "MIIFkjCCA3qgAwIBAgIIAeDltYNno+AwDQYJKoZIhvcNAQEMBQAwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEcyMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxMDA5WhcNMzkwNDMwMTgxMDA5WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzIxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgREkhI2imKScUcx+xuM23+TfvgHN6sXuI2pyT5f1BrTM65MFQn5bPW7SXmMLYFN14UIhHF6Kob0vuy0gmVOKTvKkmMXT5xZgM4+xb1hYjkWpIMBDLyyED7Ul+f9sDx47pFoFDVEovy3d6RhiPw9bZyLgHaC/YuOQhfGaFjQQscp5TBhsRTL3b2CtcM0YM/GlMZ81fVJ3/8E7j4ko380yhDPLVoACVdJ2LT3VXdRCCQgzWTxb+4Gftr49wIQuavbfqeQMpOhYV4SbHXw8EwOTKrfl+q04tvny0aIWhwZ7Oj8ZhBbZF8+NfbqOdfIRqMM78xdLe40fTgIvS/cjTf94FNcX1RoeKz8NMoFnNvzcytN31O661A4T+B/fc9Cj6i8b0xlilZ3MIZgIxbdMYs0xBTJh0UT8TUgWY8h2czJxQI6bR3hDRSj4n4aJgXv8O7qhOTH11UL6jHfPsNFL4VPSQ08prcdUFmIrQB1guvkJ4M6mL4m1k8COKWNORj3rw31OsMiANDC1CvoDTdUE0V+1ok2Az6DGOeHwOx4e7hqkP0ZmUoNwIx7wHHHtHMn23KVDpA287PT0aLSmWaasZobNfMmRtHsHLDd4/E92GcdB/O/WuhwpyUgquUoue9G7q5cDmVF8Up8zlYNPXEpMZ7YLlmQ1A/bmH8DvmGqmAMQ0uVAgMBAAGjQjBAMB0GA1UdDgQWBBTEmRNsGAPCe8CjoA1/coB6HHcmjTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQwFAAOCAgEAUabz4vS4PZO/Lc4Pu1vhVRROTtHlznldgX/+tvCHM/jvlOV+3Gp5pxy+8JS3ptEwnMgNCnWefZKVfhidfsJxaXwU6s+DDuQUQp50DhDNqxq6EWGBeNjxtUVAeKuowM77fWM3aPbn+6/Gw0vsHzYmE1SGlHKy6gLti23kDKaQwFd1z4xCfVzmMX3zybKSaUYOiPjjLUKyOKimGY3xn83uamW8GrAlvacp/fQ+onVJv57byfenHmOZ4VxG/5IFjPoeIPmGlFYl5bRXOJ3riGQUIUkhOb9iZqmxospvPyFgxYnURTbImHy99v6ZSYA7LNKmp4gDBDEZt7Y6YUX6yfIjyGNzv1aJMbDZfGKnexWoiIqrOEDCzBL/FePwN983csvMmOa/orz6JopxVtfnJBtIRD6e/J/JzBrsQzwBvDR4yGn1xuZW7AYJNpDrFEobXsmII9oDMJELuDY++ee1KG++P+w8j2Ud5cAeh6Squpj9kuNsJnfdBrRkBof0Tta6SqoWqPQFZ2aWuuJVecMsXUmPgEkrihLHdoBR37q9ZV0+N0djMenl9MU/S60EinpxLK8JQzcPqOMyT/RFtm2XNuyE9QoB6he7hY1Ck3DDUOUUi78/w0EP3SIEIwiKum1xRKtzCTrJ+VKACd+66eYWyi4uTLLT3OUEVLLUNIAytbwPF+E=",
  // Apple Root CA - G3, DER from https://www.apple.com/certificateauthority/
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA=="
];

type StoreKitEnvironment = typeof STOREKIT_ENVIRONMENTS[number];

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
type TransactionVerifierFactory = (environment: StoreKitEnvironment) => Promise<TransactionVerifier>;

export async function verifyActiveSubscriptionProof(
  signedTransactionInfo: string,
  env: Env,
  verifier?: TransactionVerifier,
  verifierFactory?: TransactionVerifierFactory
): Promise<boolean> {
  try {
    const config = resolveAppStoreConfig(env);
    const payload = await verifyAndDecodeTransaction(
      signedTransactionInfo,
      config,
      verifier,
      verifierFactory
    );
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

async function verifyAndDecodeTransaction(
  signedTransactionInfo: string,
  config: AppStoreConfig,
  verifier?: TransactionVerifier,
  verifierFactory?: TransactionVerifierFactory
): Promise<TransactionPayload> {
  if (verifier) {
    return verifier.verifyAndDecodeTransaction(signedTransactionInfo);
  }

  let lastEnvironmentMismatch: unknown;
  for (const environment of config.allowedEnvironments) {
    try {
      const environmentVerifier = await createVerifierForEnvironment(config, environment, verifierFactory);
      return await environmentVerifier.verifyAndDecodeTransaction(signedTransactionInfo);
    } catch (error) {
      if (!isAppleInvalidEnvironmentError(error)) {
        throw error;
      }
      lastEnvironmentMismatch = error;
    }
  }

  throw lastEnvironmentMismatch ?? new AppStoreConfigError("app_store_no_allowed_environment_matched");
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
  if (!config.allowedEnvironments.includes(payload.environment as StoreKitEnvironment)) {
    return false;
  }
  const expiresDate = Number(payload.expiresDate);
  if (!Number.isFinite(expiresDate) || expiresDate <= Date.now()) {
    return false;
  }
  return payload.revocationDate === undefined;
}

async function createVerifier(config: AppStoreConfig): Promise<TransactionVerifier> {
  return createVerifierForEnvironment(config, config.allowedEnvironments[0]);
}

async function createVerifierForEnvironment(
  config: AppStoreConfig,
  environment: StoreKitEnvironment,
  verifierFactory?: TransactionVerifierFactory
): Promise<TransactionVerifier> {
  if (verifierFactory) {
    return verifierFactory(environment);
  }

  const cacheKey = `${environment}:${config.bundleId}:${config.appAppleId ?? ""}`;
  const cachedVerifier = cachedVerifiers.get(cacheKey);
  if (cachedVerifier) {
    return cachedVerifier;
  }

  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  const appStoreEnvironment = {
    Sandbox: Environment.SANDBOX,
    Production: Environment.PRODUCTION
  }[environment];
  const verifier = new SignedDataVerifier(
    await loadAppleRootCertificates(),
    ENABLE_APPLE_ONLINE_CERTIFICATE_CHECKS,
    appStoreEnvironment,
    config.bundleId,
    environment === "Production" ? config.appAppleId : undefined
  );
  cachedVerifiers.set(cacheKey, verifier);
  return verifier;
}

async function loadAppleRootCertificates(): Promise<Buffer[]> {
  if (cachedRootCertificates) {
    return cachedRootCertificates;
  }

  cachedRootCertificates = APPLE_ROOT_CERTIFICATES_BASE64.map((certificate) => Buffer.from(certificate, "base64"));
  return cachedRootCertificates;
}

function isAppleVerificationError(error: unknown): error is { status: number } {
  return typeof error === "object"
    && error !== null
    && "status" in error
    && typeof (error as { status?: unknown }).status === "number";
}

function isAppleInvalidEnvironmentError(error: unknown): boolean {
  return isAppleVerificationError(error) && error.status === 4;
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
  allowedEnvironments: StoreKitEnvironment[];
  appAppleId?: number;
}

function resolveAppStoreConfig(env: Env): AppStoreConfig {
  const bundleId = required(env.APP_STORE_BUNDLE_ID);
  const allowedEnvironments = parseAllowedEnvironments(env.APP_STORE_ALLOWED_ENVIRONMENTS ?? env.APP_STORE_ENVIRONMENT);
  const appAppleId = parseAppAppleId(env.APP_STORE_APP_APPLE_ID);

  if (allowedEnvironments.includes("Production") && appAppleId === undefined) {
    throw new AppStoreConfigError("app_store_invalid_app_apple_id");
  }
  return { bundleId, allowedEnvironments, appAppleId };
}

function parseAllowedEnvironments(value: string | undefined): StoreKitEnvironment[] {
  const rawEnvironments = (value ?? "Sandbox")
    .split(",")
    .map((environment) => environment.trim())
    .filter((environment) => environment.length > 0);

  if (rawEnvironments.length === 0) {
    throw new AppStoreConfigError("app_store_invalid_environment");
  }

  const allowedEnvironments: StoreKitEnvironment[] = [];
  for (const environment of rawEnvironments) {
    if (!isStoreKitEnvironment(environment)) {
      throw new AppStoreConfigError("app_store_invalid_environment");
    }
    if (!allowedEnvironments.includes(environment)) {
      allowedEnvironments.push(environment);
    }
  }
  return allowedEnvironments;
}

function isStoreKitEnvironment(value: string): value is StoreKitEnvironment {
  return STOREKIT_ENVIRONMENTS.includes(value as StoreKitEnvironment);
}

function parseAppAppleId(value: string | undefined): number | undefined {
  if (value === undefined) {
    return undefined;
  }

  const appAppleId = Number(value);
  if (!Number.isFinite(appAppleId) || appAppleId <= 0 || !Number.isInteger(appAppleId)) {
    throw new AppStoreConfigError("app_store_invalid_app_apple_id");
  }
  return appAppleId;
}

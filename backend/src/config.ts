import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDir = path.dirname(currentFilePath);
const rootDir = path.resolve(currentDir, "..", "..");
const backendDir = path.resolve(rootDir, "backend");

function readInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readMode<T extends string>(name: string, fallback: T, allowed: readonly T[]): T {
  const value = process.env[name] as T | undefined;
  if (!value || !allowed.includes(value)) {
    return fallback;
  }
  return value;
}

function readStringArray(name: string, fallback: string[]): string[] {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function readBoolean(name: string, fallback: boolean): boolean {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }
  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

const isVercel = Boolean(process.env.VERCEL);
const supabaseURL = process.env.SUPABASE_URL ?? process.env.IOS_BACKEND_SUPABASE_URL ?? "";
const supabaseServiceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.IOS_BACKEND_SUPABASE_SERVICE_ROLE_KEY ?? "";
const storeMode = readMode(
  "IOS_BACKEND_DATABASE_PROVIDER",
  readMode("IOS_BACKEND_STORE", supabaseURL && supabaseServiceRoleKey ? "supabase" : "dev", [
    "dev",
    "supabase",
  ] as const),
  ["file", "dev", "supabase"] as const,
);
const r2AccountId = process.env.R2_ACCOUNT_ID ?? process.env.IOS_BACKEND_R2_ACCOUNT_ID ?? "";
const r2Bucket = process.env.R2_BUCKET ?? process.env.IOS_BACKEND_R2_BUCKET ?? "";
const r2AccessKeyId = process.env.R2_ACCESS_KEY_ID ?? process.env.IOS_BACKEND_R2_ACCESS_KEY_ID ?? "";
const r2SecretAccessKey =
  process.env.R2_SECRET_ACCESS_KEY ?? process.env.IOS_BACKEND_R2_SECRET_ACCESS_KEY ?? "";
const objectStorageMode = readMode(
  "IOS_BACKEND_BLOB_PROVIDER",
  readMode(
    "IOS_BACKEND_OBJECT_STORAGE",
    r2AccountId && r2Bucket && r2AccessKeyId && r2SecretAccessKey ? "r2" : "local",
    ["local", "r2"] as const,
  ),
  ["local", "r2"] as const,
);

export const config = {
  rootDir,
  backendDir,
  mode: process.env.NODE_ENV === "production" ? "production" : "development",
  port: readInt("IOS_BACKEND_PORT", 8787),
  host: process.env.IOS_BACKEND_HOST ?? "127.0.0.1",
  baseURL: process.env.IOS_BACKEND_BASE_URL ?? "",
  dataDir:
    process.env.IOS_BACKEND_DATA_DIR ??
    (isVercel ? "/tmp/photogstudio-ios-backend" : path.resolve(backendDir, "data")),
  accessTokenTTLSeconds: readInt("IOS_BACKEND_ACCESS_TTL_SECONDS", 60 * 30),
  refreshTokenTTLDays: readInt("IOS_BACKEND_REFRESH_TTL_DAYS", 60),
  defaultSubscriptionDays: readInt("IOS_BACKEND_SUBSCRIPTION_DAYS", 30),
  productIDs: readStringArray("IOS_BACKEND_PRODUCT_IDS", ["com.altarisgroup.photogstudio.pro.monthly"]),
  supportEmail: process.env.IOS_BACKEND_SUPPORT_EMAIL ?? "support@example.com",
  privacyURL: process.env.IOS_BACKEND_PRIVACY_URL ?? "https://example.com/privacy",
  termsURL: process.env.IOS_BACKEND_TERMS_URL ?? "https://example.com/terms",
  managementURL:
    process.env.IOS_BACKEND_SUBSCRIPTION_MANAGEMENT_URL ??
    "https://apps.apple.com/account/subscriptions",
  storeMode,
  databaseProvider: storeMode === "supabase" ? "supabase" : "file",
  objectStorageMode,
  blobProvider: objectStorageMode,
  jobMode: readMode(
    "IOS_BACKEND_JOB_MODE",
    isVercel ? "inline" : "delayed",
    ["inline", "delayed"] as const,
  ),
  supabaseURL,
  supabaseServiceRoleKey,
  supabaseSchema: process.env.SUPABASE_SCHEMA ?? "public",
  r2AccountId,
  r2Bucket,
  r2AccessKeyId,
  r2SecretAccessKey,
  r2Endpoint: process.env.IOS_BACKEND_R2_ENDPOINT ?? "",
  r2PublicBaseURL: process.env.R2_PUBLIC_BASE_URL ?? "",
  appleSignInClientId: process.env.IOS_BACKEND_APPLE_SIGN_IN_CLIENT_ID ?? "",
  appleSignInExpectedIssuer:
    process.env.IOS_BACKEND_APPLE_SIGN_IN_EXPECTED_ISSUER ?? "https://appleid.apple.com",
  appleSignInRequireNonce: readBoolean("IOS_BACKEND_APPLE_SIGN_IN_REQUIRE_NONCE", false),
  appleSignInEnforceVerification: readBoolean(
    "IOS_BACKEND_APPLE_SIGN_IN_ENFORCE_VERIFICATION",
    false,
  ),
  appStoreBundleId: process.env.IOS_BACKEND_APP_STORE_BUNDLE_ID ?? "",
  appStoreEnvironment: process.env.IOS_BACKEND_APP_STORE_ENVIRONMENT ?? "",
  appStoreRequireSignedTransactions: readBoolean(
    "IOS_BACKEND_APP_STORE_REQUIRE_SIGNED_TRANSACTIONS",
    false,
  ),
  appStoreIssuerId: process.env.IOS_BACKEND_APP_STORE_ISSUER_ID ?? "",
  appStoreKeyId: process.env.IOS_BACKEND_APP_STORE_KEY_ID ?? "",
  appStorePrivateKeyPem: process.env.IOS_BACKEND_APP_STORE_PRIVATE_KEY_PEM ?? "",
  appStoreEnableServerApi: readBoolean("IOS_BACKEND_APP_STORE_ENABLE_SERVER_API", false),
  waveSpeedAPIKey: process.env.WAVESPEED_API_KEY ?? "",
  waveSpeedAPIBaseURL:
    process.env.WAVESPEED_API_BASE_URL ?? "https://api.wavespeed.ai/api/v3",
  waveSpeedModelAllowlist: readStringArray("WAVESPEED_MODEL_ALLOWLIST", []),
  waveSpeedCatalogCacheTTLSeconds: readInt("WAVESPEED_CATALOG_CACHE_TTL_SECONDS", 300),
};

export function requireConfig(value: string, message: string): string {
  if (!value) {
    throw new Error(message);
  }
  return value;
}

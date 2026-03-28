import crypto from "node:crypto";

export type AppStoreTransactionRecord = {
  transactionId: string;
  originalTransactionId?: string;
  productId?: string;
  bundleId?: string;
  environment?: string;
  appAccountToken?: string;
  expiresAt?: string;
  purchaseDate?: string;
  originalPurchaseDate?: string;
  revokedAt?: string;
  revocationReason?: string;
  webOrderLineItemId?: string;
  ownershipType?: string;
  signedTransactionInfo?: string;
};

type AppStoreServerAPIConfig = {
  issuerId: string;
  keyId: string;
  privateKeyPem: string;
  environment?: string;
};

type TransactionHistoryResponse = {
  signedTransactions?: string[];
  revision?: string;
  hasMore?: boolean;
};

type DecodedTransactionClaims = {
  transactionId?: string;
  originalTransactionId?: string;
  productId?: string;
  bundleId?: string;
  environment?: string;
  appAccountToken?: string;
  expiresDate?: number | string;
  purchaseDate?: number | string;
  originalPurchaseDate?: number | string;
  revocationDate?: number | string;
  revocationReason?: string | number;
  webOrderLineItemId?: string;
  inAppOwnershipType?: string;
};

const APP_STORE_API_AUDIENCE = "appstoreconnect-v1";

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Uint8Array.from(Buffer.from(`${normalized}${padding}`, "base64"));
}

function decodeClaims(token: string): DecodedTransactionClaims {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Apple signed transaction must be a compact JWS");
  }
  return JSON.parse(Buffer.from(decodeBase64Url(parts[1])).toString("utf8")) as DecodedTransactionClaims;
}

function toIsoDate(value: string | number | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  const numeric = typeof value === "number" ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(numeric)) {
    return undefined;
  }
  return new Date(numeric).toISOString();
}

function baseURLForEnvironment(environment: string | undefined): string {
  const normalized = environment?.trim().toLowerCase();
  if (normalized === "sandbox") {
    return "https://api.storekit-sandbox.itunes.apple.com";
  }
  return "https://api.storekit.itunes.apple.com";
}

function createSignedJwt(config: AppStoreServerAPIConfig): string {
  const header = {
    alg: "ES256",
    kid: config.keyId,
    typ: "JWT",
  };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: config.issuerId,
    iat: now,
    exp: now + 60 * 5,
    aud: APP_STORE_API_AUDIENCE,
  };

  const encode = (value: unknown): string =>
    Buffer.from(JSON.stringify(value)).toString("base64url");

  const signingInput = `${encode(header)}.${encode(payload)}`;
  const signature = crypto.sign("sha256", Buffer.from(signingInput), {
    key: config.privateKeyPem,
    dsaEncoding: "ieee-p1363",
  });

  return `${signingInput}.${signature.toString("base64url")}`;
}

function normalizeTransaction(
  signedTransactionInfo: string,
  claims: DecodedTransactionClaims,
): AppStoreTransactionRecord {
  if (!claims.transactionId) {
    throw new Error("Apple transaction response is missing transactionId");
  }
  return {
    transactionId: claims.transactionId,
    originalTransactionId: claims.originalTransactionId,
    productId: claims.productId,
    bundleId: claims.bundleId,
    environment: claims.environment,
    appAccountToken: claims.appAccountToken,
    expiresAt: toIsoDate(claims.expiresDate),
    purchaseDate: toIsoDate(claims.purchaseDate),
    originalPurchaseDate: toIsoDate(claims.originalPurchaseDate),
    revokedAt: toIsoDate(claims.revocationDate),
    revocationReason:
      claims.revocationReason === undefined ? undefined : String(claims.revocationReason),
    webOrderLineItemId: claims.webOrderLineItemId,
    ownershipType: claims.inAppOwnershipType,
    signedTransactionInfo,
  };
}

async function fetchHistoryPage(
  config: AppStoreServerAPIConfig,
  transactionId: string,
  revision?: string,
): Promise<TransactionHistoryResponse> {
  const token = createSignedJwt(config);
  const search = new URLSearchParams();
  search.set("sort", "DESCENDING");
  if (revision) {
    search.set("revision", revision);
  }
  const response = await fetch(
    `${baseURLForEnvironment(config.environment)}/inApps/v1/history/${encodeURIComponent(transactionId)}?${search.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`App Store Server API request failed (${response.status}): ${body}`);
  }

  return (await response.json()) as TransactionHistoryResponse;
}

export async function fetchAppStoreTransactions(
  config: AppStoreServerAPIConfig,
  transactionId: string,
): Promise<AppStoreTransactionRecord[]> {
  const transactions: AppStoreTransactionRecord[] = [];
  let revision: string | undefined;

  for (let page = 0; page < 10; page += 1) {
    const response = await fetchHistoryPage(config, transactionId, revision);
    for (const signedTransactionInfo of response.signedTransactions ?? []) {
      const claims = decodeClaims(signedTransactionInfo);
      transactions.push(normalizeTransaction(signedTransactionInfo, claims));
    }
    if (!response.hasMore || !response.revision) {
      break;
    }
    revision = response.revision;
  }

  return transactions;
}

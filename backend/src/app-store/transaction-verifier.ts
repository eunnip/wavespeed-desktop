type AppStoreTransactionClaims = {
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

type VerifyAppStoreTransactionOptions = {
  signedTransactionInfo?: string;
  transactionId: string;
  originalTransactionId?: string;
  productId: string;
  appAccountToken?: string;
  expectedBundleId?: string;
  expectedEnvironment?: string;
  requireSignedTransaction?: boolean;
};

export type VerifiedAppStoreTransaction = {
  expiresAt?: string;
  purchaseDate?: string;
  originalPurchaseDate?: string;
  revokedAt?: string;
  revocationReason?: string;
  environment?: string;
  ownershipType?: string;
  webOrderLineItemId?: string;
  signedTransactionInfo?: string;
};

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Uint8Array.from(Buffer.from(`${normalized}${padding}`, "base64"));
}

function decodeClaims(part: string): AppStoreTransactionClaims {
  return JSON.parse(Buffer.from(decodeBase64Url(part)).toString("utf8")) as AppStoreTransactionClaims;
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

function normalizeEnvironment(value: string | undefined): string | undefined {
  return value?.trim().toLowerCase() || undefined;
}

export function verifyAppStoreTransaction(
  options: VerifyAppStoreTransactionOptions,
): VerifiedAppStoreTransaction | undefined {
  if (!options.signedTransactionInfo) {
    if (options.requireSignedTransaction) {
      throw new Error("signed_transaction_info is required");
    }
    return undefined;
  }

  const parts = options.signedTransactionInfo.split(".");
  if (parts.length !== 3) {
    throw new Error("signed_transaction_info must be a compact JWS");
  }

  const claims = decodeClaims(parts[1]);
  if (!claims.transactionId || claims.transactionId !== options.transactionId) {
    throw new Error("Transaction ID does not match signed transaction info");
  }
  if (claims.productId !== options.productId) {
    throw new Error("Product ID does not match signed transaction info");
  }
  if (
    options.originalTransactionId &&
    claims.originalTransactionId &&
    claims.originalTransactionId !== options.originalTransactionId
  ) {
    throw new Error("Original transaction ID does not match signed transaction info");
  }
  if (
    options.appAccountToken &&
    claims.appAccountToken &&
    claims.appAccountToken.toLowerCase() !== options.appAccountToken.toLowerCase()
  ) {
    throw new Error("App account token does not match signed transaction info");
  }
  if (options.expectedBundleId && claims.bundleId && claims.bundleId !== options.expectedBundleId) {
    throw new Error("Bundle ID does not match signed transaction info");
  }
  const expectedEnvironment = normalizeEnvironment(options.expectedEnvironment);
  if (
    expectedEnvironment &&
    claims.environment &&
    normalizeEnvironment(claims.environment) !== expectedEnvironment
  ) {
    throw new Error("Environment does not match signed transaction info");
  }

  return {
    expiresAt: toIsoDate(claims.expiresDate),
    purchaseDate: toIsoDate(claims.purchaseDate),
    originalPurchaseDate: toIsoDate(claims.originalPurchaseDate),
    revokedAt: toIsoDate(claims.revocationDate),
    revocationReason:
      claims.revocationReason === undefined ? undefined : String(claims.revocationReason),
    environment: claims.environment,
    ownershipType: claims.inAppOwnershipType,
    webOrderLineItemId: claims.webOrderLineItemId,
    signedTransactionInfo: options.signedTransactionInfo,
  };
}

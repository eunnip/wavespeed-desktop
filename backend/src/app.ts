import crypto from "node:crypto";
import path from "node:path";

import { verifyAppleIdentityToken, type AppleIdentity } from "./apple/verify-identity-token.ts";
import {
  fetchAppStoreTransactions,
  type AppStoreTransactionRecord,
} from "./app-store/server-api.ts";
import {
  verifyAppStoreTransaction,
  type VerifiedAppStoreTransaction,
} from "./app-store/transaction-verifier.ts";
import { defaultCatalogModels } from "./fixtures.ts";
import { parseMultipartFile } from "./multipart.ts";
import { type ObjectStorage } from "./object-storage.ts";
import {
  type AccessSessionRecord,
  type JobRecord,
  type PurchaseRecord,
  type RefreshSessionRecord,
  type Store,
  type UploadRecord,
  type UserRecord,
} from "./store.ts";

type BackendConfig = {
  baseURL: string;
  mode: "development" | "production";
  accessTokenTTLSeconds: number;
  refreshTokenTTLDays: number;
  defaultSubscriptionDays: number;
  productIDs: string[];
  supportEmail: string;
  privacyURL: string;
  termsURL: string;
  managementURL: string;
  appleSignInClientId: string;
  appleSignInExpectedIssuer: string;
  appleSignInRequireNonce: boolean;
  appleSignInEnforceVerification: boolean;
  appStoreBundleId: string;
  appStoreEnvironment: string;
  appStoreRequireSignedTransactions: boolean;
  appStoreIssuerId: string;
  appStoreKeyId: string;
  appStorePrivateKeyPem: string;
  appStoreEnableServerApi: boolean;
};

type Dependencies = {
  config: BackendConfig;
  store: Store;
  objectStorage: ObjectStorage;
};

type RequestContext = {
  requestId: string;
  url: URL;
  method: string;
  user?: UserRecord;
  accessSession?: AccessSessionRecord;
};

type AppError = {
  status: number;
  message: string;
  code?: number;
};

export type BackendApp = {
  handle(request: Request): Promise<Response>;
};

function nowIso(): string {
  return new Date().toISOString();
}

function addSeconds(date: Date, seconds: number): string {
  return new Date(date.getTime() + seconds * 1000).toISOString();
}

function addDays(date: Date, days: number): string {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

function createToken(): string {
  return crypto.randomBytes(32).toString("base64url");
}

function createId(prefix: string): string {
  return `${prefix}_${crypto.randomUUID()}`;
}

function sha256(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function tokenHint(token: string): string {
  return token.slice(-6);
}

function jsonResponse(requestId: string, statusCode: number, payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: statusCode,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "X-Request-ID": requestId,
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    },
  });
}

function binaryResponse(
  requestId: string,
  body: Uint8Array,
  contentType: string,
): Response {
  return new Response(Buffer.from(body), {
    status: 200,
    headers: {
      "Content-Type": contentType,
      "X-Request-ID": requestId,
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function errorResponse(requestId: string, error: AppError): Response {
  return jsonResponse(requestId, error.status, {
    error: error.message,
    code: error.code,
    request_id: requestId,
  });
}

async function parseJsonBody<T>(request: Request): Promise<T> {
  const text = await request.text();
  if (!text.trim()) {
    return {} as T;
  }
  return JSON.parse(text) as T;
}

async function readBodyBuffer(request: Request): Promise<Buffer> {
  return Buffer.from(await request.arrayBuffer());
}

function ensureAuthenticated(context: RequestContext): UserRecord {
  if (!context.user) {
    throw { status: 401, message: "Unauthorized" } satisfies AppError;
  }
  return context.user;
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) {
    return null;
  }
  return header.slice("Bearer ".length).trim();
}

function deriveBaseURL(request: Request, config: BackendConfig): string {
  if (config.baseURL) {
    return config.baseURL;
  }
  return new URL(request.url).origin;
}

function humanizeProductId(productId: string): string {
  return (
    productId
      .split(".")
      .at(-1)
      ?.split("-")
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ") ?? productId
  );
}

function createPromptSvg(prompt: string, modelName: string): string {
  const safePrompt = prompt.replace(/[<>&"]/g, (char) => {
    switch (char) {
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case "&":
        return "&amp;";
      case '"':
        return "&quot;";
      default:
        return char;
    }
  });

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#102542"/>
      <stop offset="100%" stop-color="#f87060"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect x="64" y="64" width="896" height="896" rx="40" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.28)"/>
  <text x="100" y="170" font-family="Helvetica, Arial, sans-serif" font-size="44" fill="#ffffff">${modelName}</text>
  <foreignObject x="100" y="230" width="824" height="620">
    <div xmlns="http://www.w3.org/1999/xhtml" style="color:#ffffff;font-family:Helvetica,Arial,sans-serif;font-size:34px;line-height:1.4;">
      ${safePrompt}
    </div>
  </foreignObject>
</svg>`;
}

export function createBackendApp(dependencies: Dependencies): BackendApp {
  const { config, store, objectStorage } = dependencies;

  function shouldVerifyAppleIdentity(): boolean {
    return config.appleSignInEnforceVerification || Boolean(config.appleSignInClientId);
  }

  function shouldUseAppStoreServerApi(): boolean {
    return (
      config.appStoreEnableServerApi &&
      Boolean(config.appStoreIssuerId) &&
      Boolean(config.appStoreKeyId) &&
      Boolean(config.appStorePrivateKeyPem)
    );
  }

  async function resolveAppleIdentity(
    identityToken: string,
    nonce?: string,
  ): Promise<AppleIdentity | undefined> {
    if (!shouldVerifyAppleIdentity()) {
      return undefined;
    }
    return verifyAppleIdentityToken({
      identityToken,
      expectedIssuer: config.appleSignInExpectedIssuer,
      expectedAudience: config.appleSignInClientId || undefined,
      rawNonce: nonce,
      requireNonce: config.appleSignInRequireNonce,
    });
  }

  async function verifyTransactionWithAppleServer(
    transactionId: string,
    productId: string,
    appAccountToken?: string,
  ): Promise<VerifiedAppStoreTransaction | undefined> {
    if (!shouldUseAppStoreServerApi()) {
      return undefined;
    }

    const transactions = await fetchAppStoreTransactions(
      {
        issuerId: config.appStoreIssuerId,
        keyId: config.appStoreKeyId,
        privateKeyPem: config.appStorePrivateKeyPem,
        environment: config.appStoreEnvironment || undefined,
      },
      transactionId,
    );

    const match = transactions.find((candidate) => candidate.transactionId === transactionId);
    if (!match) {
      throw new Error("Apple server verification could not find the requested transaction");
    }
    if (match.productId && match.productId !== productId) {
      throw new Error("Apple server verification returned a mismatched product");
    }
    if (config.appStoreBundleId && match.bundleId && match.bundleId !== config.appStoreBundleId) {
      throw new Error("Apple server verification returned a mismatched bundle ID");
    }
    if (
      appAccountToken &&
      match.appAccountToken &&
      match.appAccountToken.toLowerCase() !== appAccountToken.toLowerCase()
    ) {
      throw new Error("Apple server verification returned a mismatched app account token");
    }

    return {
      expiresAt: match.expiresAt,
      purchaseDate: match.purchaseDate,
      originalPurchaseDate: match.originalPurchaseDate,
      revokedAt: match.revokedAt,
      revocationReason: match.revocationReason,
      environment: match.environment,
      ownershipType: match.ownershipType,
      webOrderLineItemId: match.webOrderLineItemId,
      signedTransactionInfo: match.signedTransactionInfo,
    };
  }

  function chooseLatestRestorableTransaction(
    transactions: AppStoreTransactionRecord[],
    originalTransactionId: string,
  ): AppStoreTransactionRecord | undefined {
    return transactions
      .filter((candidate) => candidate.originalTransactionId === originalTransactionId)
      .sort((left, right) => (right.expiresAt ?? right.purchaseDate ?? "").localeCompare(left.expiresAt ?? left.purchaseDate ?? ""))
      .at(0);
  }

  async function activePurchaseForUser(userId: string): Promise<PurchaseRecord | undefined> {
    const now = Date.now();
    const purchases = await store.listPurchasesForUser(userId);
    return purchases
      .filter((purchase) => !purchase.revokedAt)
      .sort((a, b) => b.expiresAt.localeCompare(a.expiresAt))
      .find((purchase) => new Date(purchase.expiresAt).getTime() > now);
  }

  async function entitlementSummary(userId: string) {
    const purchase = await activePurchaseForUser(userId);
    return {
      is_active: Boolean(purchase),
      tier_name: purchase ? humanizeProductId(purchase.productId) : null,
      renewal_date: purchase?.expiresAt ?? null,
      usage_description: purchase
        ? "Subscription is active."
        : "No active subscription was found for this user.",
      management_url: config.managementURL,
    };
  }

  function createAccessSession(userId: string, refreshToken?: string): { token: string; record: AccessSessionRecord } {
    const token = createToken();
    return {
      token,
      record: {
        tokenHash: sha256(token),
        tokenHint: tokenHint(token),
        userId,
        expiresAt: addSeconds(new Date(), config.accessTokenTTLSeconds),
        createdAt: nowIso(),
        refreshTokenHash: refreshToken ? sha256(refreshToken) : undefined,
      },
    };
  }

  function createRefreshSession(userId: string): { token: string; record: RefreshSessionRecord } {
    const token = createToken();
    return {
      token,
      record: {
        tokenHash: sha256(token),
        tokenHint: tokenHint(token),
        userId,
        expiresAt: addDays(new Date(), config.refreshTokenTTLDays),
        createdAt: nowIso(),
      },
    };
  }

  async function sessionPayload(
    user: UserRecord,
    accessToken: string,
    access: AccessSessionRecord,
    refreshToken?: string,
  ) {
    return {
      access_token: accessToken,
      refresh_token: refreshToken ?? null,
      expires_at: access.expiresAt,
      token_type: "Bearer",
      user: {
        id: user.id,
        display_name: user.displayName ?? null,
        email: user.email ?? null,
      },
      entitlements: await entitlementSummary(user.id),
    };
  }

  async function ensureUserFromApple(
    identityToken: string,
    identity?: AppleIdentity,
  ): Promise<UserRecord> {
    const appleSubject = identity?.subject ?? sha256(identityToken);
    const existing = await store.findUserByAppleSubject(appleSubject);
    if (existing) {
      const updated: UserRecord = {
        ...existing,
        email: identity?.email ?? existing.email,
        emailVerified: identity?.emailVerified ?? existing.emailVerified,
        isPrivateEmail: identity?.isPrivateEmail ?? existing.isPrivateEmail,
        updatedAt: nowIso(),
      };
      await store.saveUser(updated);
      return updated;
    }

    const createdAt = nowIso();
    const user: UserRecord = {
      id: createId("usr"),
      appleSubject,
      email: identity?.email,
      emailVerified: identity?.emailVerified,
      isPrivateEmail: identity?.isPrivateEmail,
      displayName: identity?.email ?? "iOS User",
      createdAt,
      updatedAt: createdAt,
    };
    await store.saveUser(user);
    return user;
  }

  async function requireAccessSession(request: Request, context: RequestContext): Promise<void> {
    const token = bearerToken(request);
    if (!token) {
      throw { status: 401, message: "Missing bearer token" } satisfies AppError;
    }

    const accessSession = await store.findAccessSessionByTokenHash(sha256(token));
    if (!accessSession || accessSession.revokedAt) {
      throw { status: 401, message: "Access token is invalid" } satisfies AppError;
    }
    if (new Date(accessSession.expiresAt).getTime() <= Date.now()) {
      throw { status: 401, message: "Access token has expired" } satisfies AppError;
    }

    const user = await store.findUserById(accessSession.userId);
    if (!user) {
      throw { status: 401, message: "User session is invalid" } satisfies AppError;
    }

    context.user = user;
    context.accessSession = accessSession;
  }

  async function materializeJobIfReady(job: JobRecord): Promise<JobRecord> {
    if (job.status === "completed" || job.status === "failed" || job.status === "canceled") {
      return job;
    }

    const createdAtMs = new Date(job.createdAt).getTime();
    if (Date.now() - createdAtMs < 1500) {
      if (job.status !== "running") {
        const running: JobRecord = {
          ...job,
          status: "running",
          updatedAt: nowIso(),
        };
        await store.saveJob(running);
        return running;
      }
      return job;
    }

    const modelName =
      defaultCatalogModels.find((model) => model.id === job.modelId)?.name ?? job.modelId;
    const outputId = createId("out");
    const storageKey = `outputs/${job.userId}/${job.id}/${outputId}.svg`;
    await objectStorage.putObject(
      storageKey,
      new TextEncoder().encode(createPromptSvg(job.prompt ?? "Generated output", modelName)),
      "image/svg+xml",
    );

    const completed: JobRecord = {
      ...job,
      status: "completed",
      updatedAt: nowIso(),
      outputs: [
        {
          id: outputId,
          mimeType: "image/svg+xml",
          storageKey,
        },
      ],
    };
    await store.saveJob(completed);
    return completed;
  }

  function publicJob(job: JobRecord, request: Request) {
    const baseURL = deriveBaseURL(request, config);
    return {
      id: job.id,
      model_id: job.modelId,
      model_name: job.modelName ?? null,
      prompt: job.prompt ?? null,
      status: job.status,
      created_at: job.createdAt,
      updated_at: job.updatedAt,
      error_message: job.errorMessage ?? null,
      outputs: job.outputs.map((output) => ({
        id: output.id,
        url: `${baseURL}/v1/jobs/${job.id}/outputs/${output.id}`,
        mime_type: output.mimeType,
      })),
    };
  }

  function publicUpload(upload: UploadRecord, request: Request) {
    const baseURL = deriveBaseURL(request, config);
    return {
      id: upload.id,
      file_url: `${baseURL}/v1/uploads/${upload.id}/content`,
      mime_type: upload.mimeType,
    };
  }

  async function route(request: Request, context: RequestContext): Promise<Response> {
    if (context.method === "OPTIONS") {
      return jsonResponse(context.requestId, 200, { data: { ok: true } });
    }

    if (context.method === "GET" && context.url.pathname === "/health") {
      return jsonResponse(context.requestId, 200, {
        data: {
          ok: true,
        },
      });
    }

    if (context.method === "POST" && context.url.pathname === "/v1/auth/sign-in/apple") {
      const body = await parseJsonBody<{
        identity_token?: string;
        authorization_code?: string;
        nonce?: string;
      }>(request);
      if (!body.identity_token) {
        throw { status: 422, message: "identity_token is required" } satisfies AppError;
      }

      const appleIdentity = await resolveAppleIdentity(body.identity_token, body.nonce);
      const user = await ensureUserFromApple(body.identity_token, appleIdentity);
      const refresh = createRefreshSession(user.id);
      const access = createAccessSession(user.id, refresh.token);

      await store.insertRefreshSession(refresh.record);
      await store.insertAccessSession(access.record);

      return jsonResponse(context.requestId, 200, {
        data: await sessionPayload(user, access.token, access.record, refresh.token),
      });
    }

    if (context.method === "POST" && context.url.pathname === "/v1/auth/refresh") {
      const body = await parseJsonBody<{ refresh_token?: string }>(request);
      if (!body.refresh_token) {
        throw { status: 422, message: "refresh_token is required" } satisfies AppError;
      }

      const refresh = await store.findRefreshSessionByTokenHash(sha256(body.refresh_token));
      if (!refresh || refresh.revokedAt) {
        throw { status: 401, message: "Refresh token is invalid" } satisfies AppError;
      }
      if (new Date(refresh.expiresAt).getTime() <= Date.now()) {
        throw { status: 401, message: "Refresh token has expired" } satisfies AppError;
      }

      const user = await store.findUserById(refresh.userId);
      if (!user) {
        throw { status: 401, message: "Refresh session has no valid user" } satisfies AppError;
      }

      const access = createAccessSession(user.id, body.refresh_token);
      await store.insertAccessSession(access.record);

      return jsonResponse(context.requestId, 200, {
        data: await sessionPayload(user, access.token, access.record, body.refresh_token),
      });
    }

    if (
      context.method === "POST" &&
      (context.url.pathname === "/v1/auth/sign-out" || context.url.pathname === "/v1/auth/revoke")
    ) {
      const body = await parseJsonBody<{
        refresh_token?: string;
        revoke_all_sessions?: boolean;
      }>(request);
      await requireAccessSession(request, context);

      if (body.revoke_all_sessions) {
        await store.revokeRefreshSessionsForUser(context.user!.id, nowIso());
        await store.revokeAccessSessionsForUser(context.user!.id, nowIso());
      } else {
        if (body.refresh_token) {
          await store.revokeRefreshSessionByTokenHash(sha256(body.refresh_token), nowIso());
        }
        const accessToken = bearerToken(request);
        if (accessToken) {
          await store.revokeAccessSessionByTokenHash(sha256(accessToken), nowIso());
        }
      }

      return jsonResponse(context.requestId, 200, { data: {} });
    }

    await requireAccessSession(request, context);

    if (context.method === "POST" && context.url.pathname === "/v1/me/delete") {
      const user = ensureAuthenticated(context);
      const deletedAt = nowIso();
      await store.markUserDeleted(user.id, deletedAt);
      await store.revokeAccessSessionsForUser(user.id, deletedAt);
      await store.revokeRefreshSessionsForUser(user.id, deletedAt);
      return jsonResponse(context.requestId, 200, { data: {} });
    }

    if (context.method === "GET" && context.url.pathname === "/v1/me") {
      const user = ensureAuthenticated(context);
      return jsonResponse(context.requestId, 200, {
        data: {
          id: user.id,
          display_name: user.displayName ?? null,
          email: user.email ?? null,
        },
      });
    }

    if (context.method === "GET" && context.url.pathname === "/v1/me/entitlements") {
      const user = ensureAuthenticated(context);
      return jsonResponse(context.requestId, 200, { data: await entitlementSummary(user.id) });
    }

    if (context.method === "POST" && context.url.pathname === "/v1/iap/apple/sync") {
      const user = ensureAuthenticated(context);
      const body = await parseJsonBody<{
        product_id?: string;
        transaction_id?: string;
        original_transaction_id?: string;
        app_account_token?: string;
        signed_transaction_info?: string;
      }>(request);

      if (!body.product_id || !body.transaction_id) {
        throw {
          status: 422,
          message: "product_id and transaction_id are required",
        } satisfies AppError;
      }

      let verifiedTransaction: VerifiedAppStoreTransaction | undefined;
      try {
        verifiedTransaction =
          (await verifyTransactionWithAppleServer(
            body.transaction_id,
            body.product_id,
            body.app_account_token,
          )) ??
          verifyAppStoreTransaction({
            signedTransactionInfo: body.signed_transaction_info,
            transactionId: body.transaction_id,
            originalTransactionId: body.original_transaction_id,
            productId: body.product_id,
            appAccountToken: body.app_account_token,
            expectedBundleId: config.appStoreBundleId || undefined,
            expectedEnvironment: config.appStoreEnvironment || undefined,
            requireSignedTransaction: config.appStoreRequireSignedTransactions,
          });
      } catch (error) {
        throw {
          status: 422,
          message: error instanceof Error ? error.message : "StoreKit transaction is invalid",
        } satisfies AppError;
      }

      const existing = await store.findPurchaseByTransactionId(body.transaction_id);
      if (!existing) {
        await store.insertPurchase({
          id: createId("iap"),
          userId: user.id,
          productId: body.product_id,
          transactionId: body.transaction_id,
          originalTransactionId: body.original_transaction_id,
          appAccountToken: body.app_account_token,
          signedTransactionInfo:
            verifiedTransaction?.signedTransactionInfo ?? body.signed_transaction_info,
          expiresAt:
            verifiedTransaction?.expiresAt ?? addDays(new Date(), config.defaultSubscriptionDays),
          source: "sync",
          environment:
            verifiedTransaction?.environment ??
            (config.mode === "production" ? "production" : "sandbox"),
          createdAt: nowIso(),
          purchaseDate: verifiedTransaction?.purchaseDate,
          originalPurchaseDate: verifiedTransaction?.originalPurchaseDate,
          webOrderLineItemId: verifiedTransaction?.webOrderLineItemId,
          ownershipType: verifiedTransaction?.ownershipType,
          revocationReason: verifiedTransaction?.revocationReason,
          revokedAt: verifiedTransaction?.revokedAt,
        });
      }

      return jsonResponse(context.requestId, 200, {
        data: {
          accepted: true,
          message:
            shouldUseAppStoreServerApi()
              ? "Transaction accepted and verified with Apple."
              : verifiedTransaction
                ? "Transaction accepted and validated against signed StoreKit payload fields."
              : config.mode === "production"
                ? "Transaction accepted. Configure signed transaction enforcement before production launch."
                : "Transaction accepted in local development mode.",
          entitlement: await entitlementSummary(user.id),
        },
      });
    }

    if (context.method === "POST" && context.url.pathname === "/v1/iap/apple/restore") {
      const user = ensureAuthenticated(context);
      const body = await parseJsonBody<{ original_transaction_ids?: string[] }>(request);
      const originalIds = body.original_transaction_ids ?? [];
      const existing = (await store.listPurchasesForUser(user.id)).find((purchase) => {
        return (
          purchase.originalTransactionId &&
          originalIds.includes(purchase.originalTransactionId) &&
          !purchase.revokedAt
        );
      });

      if (!existing && originalIds.length > 0 && shouldUseAppStoreServerApi()) {
        for (const originalTransactionId of originalIds) {
          const transactions = await fetchAppStoreTransactions(
            {
              issuerId: config.appStoreIssuerId,
              keyId: config.appStoreKeyId,
              privateKeyPem: config.appStorePrivateKeyPem,
              environment: config.appStoreEnvironment || undefined,
            },
            originalTransactionId,
          );
          const latest = chooseLatestRestorableTransaction(transactions, originalTransactionId);
          if (!latest || !latest.productId || !latest.transactionId) {
            continue;
          }
          const current = await store.findPurchaseByTransactionId(latest.transactionId);
          if (current) {
            continue;
          }
          await store.insertPurchase({
            id: createId("iap"),
            userId: user.id,
            productId: latest.productId,
            transactionId: latest.transactionId,
            originalTransactionId: latest.originalTransactionId,
            appAccountToken: latest.appAccountToken,
            signedTransactionInfo: latest.signedTransactionInfo,
            expiresAt: latest.expiresAt ?? addDays(new Date(), config.defaultSubscriptionDays),
            source: "restore",
            environment:
              latest.environment ?? (config.mode === "production" ? "production" : "sandbox"),
            createdAt: nowIso(),
            purchaseDate: latest.purchaseDate,
            originalPurchaseDate: latest.originalPurchaseDate,
            webOrderLineItemId: latest.webOrderLineItemId,
            ownershipType: latest.ownershipType,
            revocationReason: latest.revocationReason,
            revokedAt: latest.revokedAt,
          });
        }
      }

      return jsonResponse(context.requestId, 200, {
        data: {
          accepted: true,
          message:
            shouldUseAppStoreServerApi()
              ? "Restore processed with Apple transaction history."
              : config.mode === "production"
                ? "Restore processed. Configure Apple server verification before production launch."
              : "Restore processed in local development mode.",
          entitlement: await entitlementSummary(user.id),
        },
      });
    }

    if (context.method === "GET" && context.url.pathname === "/v1/catalog/models") {
      return jsonResponse(context.requestId, 200, {
        data: defaultCatalogModels.map((model) => ({
          id: model.id,
          name: model.name,
          summary: model.summary,
          kind: model.kind,
          thumbnail_url: model.thumbnailUrl ?? null,
          requires_image_input: model.requiresImageInput ?? false,
        })),
      });
    }

    if (context.method === "GET" && context.url.pathname === "/v1/app/config") {
      return jsonResponse(context.requestId, 200, {
        data: {
          support_email: config.supportEmail,
          privacy_url: config.privacyURL,
          terms_url: config.termsURL,
          subscription_management_url: config.managementURL,
          featured_model_ids: defaultCatalogModels.slice(0, 2).map((model) => model.id),
          subscription_product_ids: config.productIDs,
        },
      });
    }

    if (context.method === "POST" && context.url.pathname === "/v1/jobs") {
      const user = ensureAuthenticated(context);
      const entitlement = await entitlementSummary(user.id);
      if (!entitlement.is_active) {
        throw {
          status: 403,
          message: "An active subscription is required to create a job.",
        } satisfies AppError;
      }

      const body = await parseJsonBody<{
        model_id?: string;
        prompt?: string;
        negative_prompt?: string;
        image_url?: string;
      }>(request);
      if (!body.model_id || !body.prompt) {
        throw { status: 422, message: "model_id and prompt are required" } satisfies AppError;
      }

      const model = defaultCatalogModels.find((candidate) => candidate.id === body.model_id);
      const createdAt = nowIso();
      const job: JobRecord = {
        id: createId("job"),
        userId: user.id,
        modelId: body.model_id,
        modelName: model?.name,
        prompt: body.prompt,
        negativePrompt: body.negative_prompt,
        imageUrl: body.image_url,
        status: "queued",
        createdAt,
        updatedAt: createdAt,
        outputs: [],
      };

      await store.insertJob(job);
      return jsonResponse(context.requestId, 200, { data: publicJob(job, request) });
    }

    if (context.method === "GET" && context.url.pathname === "/v1/jobs") {
      const user = ensureAuthenticated(context);
      const jobs = (await store.listJobsForUser(user.id)).sort((a, b) =>
        b.createdAt.localeCompare(a.createdAt),
      );
      const materialized = await Promise.all(jobs.map((job) => materializeJobIfReady(job)));
      return jsonResponse(context.requestId, 200, {
        data: {
          items: materialized.map((job) => publicJob(job, request)),
          next_cursor: null,
        },
      });
    }

    if (context.method === "GET" && /^\/v1\/jobs\/[^/]+$/.test(context.url.pathname)) {
      const user = ensureAuthenticated(context);
      const jobId = context.url.pathname.split("/").at(-1) ?? "";
      const job = await store.findJobById(jobId, user.id);
      if (!job) {
        throw { status: 404, message: "Job not found" } satisfies AppError;
      }
      const materialized = await materializeJobIfReady(job);
      return jsonResponse(context.requestId, 200, { data: publicJob(materialized, request) });
    }

    if (context.method === "POST" && /^\/v1\/jobs\/[^/]+\/cancel$/.test(context.url.pathname)) {
      const user = ensureAuthenticated(context);
      const jobId = context.url.pathname.split("/")[3] ?? "";
      const job = await store.findJobById(jobId, user.id);
      if (!job) {
        throw { status: 404, message: "Job not found" } satisfies AppError;
      }
      const canceledJob = {
        ...job,
        status: "canceled" as const,
        updatedAt: nowIso(),
      };
      await store.saveJob(canceledJob);
      return jsonResponse(context.requestId, 200, { data: publicJob(canceledJob, request) });
    }

    if (context.method === "GET" && /^\/v1\/jobs\/[^/]+\/outputs\/[^/]+$/.test(context.url.pathname)) {
      const user = ensureAuthenticated(context);
      const segments = context.url.pathname.split("/");
      const jobId = segments[3] ?? "";
      const outputId = segments[5] ?? "";
      const job = await store.findJobById(jobId, user.id);
      const output = job?.outputs.find((candidate) => candidate.id === outputId);
      if (!job || !output) {
        throw { status: 404, message: "Output not found" } satisfies AppError;
      }
      const object = await objectStorage.getObject(output.storageKey);
      if (!object) {
        throw { status: 404, message: "Output binary not found" } satisfies AppError;
      }
      return binaryResponse(context.requestId, object.body, output.mimeType || object.contentType || "application/octet-stream");
    }

    if (context.method === "POST" && context.url.pathname === "/v1/uploads") {
      const user = ensureAuthenticated(context);
      const body = await readBodyBuffer(request);
      const file = parseMultipartFile(request.headers.get("content-type") ?? undefined, body);
      if (!file) {
        throw { status: 422, message: "A multipart file upload is required" } satisfies AppError;
      }

      const uploadId = createId("upl");
      const extension = path.extname(file.filename) || ".bin";
      const storageKey = `uploads/${user.id}/${uploadId}${extension}`;

      await objectStorage.putObject(storageKey, file.data, file.mimeType);

      const record: UploadRecord = {
        id: uploadId,
        userId: user.id,
        filename: file.filename,
        mimeType: file.mimeType,
        storageKey,
        createdAt: nowIso(),
      };

      await store.insertUpload(record);
      return jsonResponse(context.requestId, 200, { data: publicUpload(record, request) });
    }

    if (context.method === "GET" && /^\/v1\/uploads\/[^/]+\/content$/.test(context.url.pathname)) {
      const user = ensureAuthenticated(context);
      const uploadId = context.url.pathname.split("/")[3] ?? "";
      const upload = await store.findUploadById(uploadId, user.id);
      if (!upload) {
        throw { status: 404, message: "Upload not found" } satisfies AppError;
      }
      const object = await objectStorage.getObject(upload.storageKey);
      if (!object) {
        throw { status: 404, message: "Upload binary not found" } satisfies AppError;
      }
      return binaryResponse(context.requestId, object.body, upload.mimeType || object.contentType || "application/octet-stream");
    }

    throw { status: 404, message: "Route not found" } satisfies AppError;
  }

  return {
    async handle(request: Request): Promise<Response> {
      const requestId = createId("req");
      const context: RequestContext = {
        requestId,
        url: new URL(request.url),
        method: request.method.toUpperCase(),
      };

      try {
        return await route(request, context);
      } catch (error) {
        const appError = (error ?? {}) as Partial<AppError>;
        return errorResponse(requestId, {
          status: appError.status ?? 500,
          message: appError.message ?? "Internal server error",
          code: appError.code,
        });
      }
    },
  };
}

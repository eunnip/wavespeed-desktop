import fs from "node:fs";
import path from "node:path";

export type UserRecord = {
  id: string;
  appleSubject: string;
  email?: string;
  emailVerified?: boolean;
  isPrivateEmail?: boolean;
  displayName?: string;
  deletedAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type RefreshSessionRecord = {
  tokenHash: string;
  tokenHint?: string;
  userId: string;
  expiresAt: string;
  createdAt: string;
  revokedAt?: string;
};

export type AccessSessionRecord = {
  tokenHash: string;
  tokenHint?: string;
  userId: string;
  expiresAt: string;
  createdAt: string;
  refreshTokenHash?: string;
  revokedAt?: string;
};

export type PurchaseRecord = {
  id: string;
  userId: string;
  productId: string;
  transactionId: string;
  originalTransactionId?: string;
  appAccountToken?: string;
  signedTransactionInfo?: string;
  expiresAt: string;
  source: "sync" | "restore";
  environment?: string;
  createdAt: string;
  purchaseDate?: string;
  originalPurchaseDate?: string;
  webOrderLineItemId?: string;
  ownershipType?: string;
  revocationReason?: string;
  revokedAt?: string;
};

export type UploadRecord = {
  id: string;
  userId: string;
  filename: string;
  mimeType: string;
  storageKey: string;
  createdAt: string;
};

export type JobOutputRecord = {
  id: string;
  mimeType: string;
  storageKey: string;
};

export type JobRecord = {
  id: string;
  userId: string;
  modelId: string;
  modelName?: string;
  prompt?: string;
  negativePrompt?: string;
  imageUrl?: string;
  status: "queued" | "running" | "completed" | "failed" | "canceled";
  createdAt: string;
  updatedAt: string;
  errorMessage?: string;
  outputs: JobOutputRecord[];
};

export type StoreData = {
  users: UserRecord[];
  refreshSessions: RefreshSessionRecord[];
  accessSessions: AccessSessionRecord[];
  purchases: PurchaseRecord[];
  uploads: UploadRecord[];
  jobs: JobRecord[];
};

export type Store = {
  findUserByAppleSubject(appleSubject: string): Promise<UserRecord | undefined>;
  findUserById(userId: string): Promise<UserRecord | undefined>;
  saveUser(user: UserRecord): Promise<void>;
  markUserDeleted(userId: string, deletedAt: string): Promise<void>;
  insertRefreshSession(session: RefreshSessionRecord): Promise<void>;
  findRefreshSessionByTokenHash(tokenHash: string): Promise<RefreshSessionRecord | undefined>;
  revokeRefreshSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void>;
  revokeRefreshSessionsForUser(userId: string, revokedAt: string): Promise<void>;
  insertAccessSession(session: AccessSessionRecord): Promise<void>;
  findAccessSessionByTokenHash(tokenHash: string): Promise<AccessSessionRecord | undefined>;
  revokeAccessSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void>;
  revokeAccessSessionsForUser(userId: string, revokedAt: string): Promise<void>;
  listPurchasesForUser(userId: string): Promise<PurchaseRecord[]>;
  findPurchaseByTransactionId(transactionId: string): Promise<PurchaseRecord | undefined>;
  insertPurchase(purchase: PurchaseRecord): Promise<void>;
  insertUpload(upload: UploadRecord): Promise<void>;
  findUploadById(uploadId: string, userId: string): Promise<UploadRecord | undefined>;
  insertJob(job: JobRecord): Promise<void>;
  listJobsForUser(userId: string): Promise<JobRecord[]>;
  findJobById(jobId: string, userId: string): Promise<JobRecord | undefined>;
  saveJob(job: JobRecord): Promise<void>;
};

function emptyStore(): StoreData {
  return {
    users: [],
    refreshSessions: [],
    accessSessions: [],
    purchases: [],
    uploads: [],
    jobs: [],
  };
}

function mapLegacyStore(data: StoreData): StoreData {
  data.refreshSessions = data.refreshSessions.map((record) => ({
    ...record,
    tokenHash: record.tokenHash ?? (record as { token?: string }).token ?? "",
  }));

  data.accessSessions = data.accessSessions.map((record) => ({
    ...record,
    tokenHash: record.tokenHash ?? (record as { token?: string }).token ?? "",
  }));

  data.uploads = data.uploads.map((record) => ({
    ...record,
    storageKey: record.storageKey ?? (record as { relativePath?: string }).relativePath ?? "",
  }));

  data.jobs = data.jobs.map((job) => ({
    ...job,
    outputs: (job.outputs ?? []).map((output) => ({
      ...output,
      storageKey: output.storageKey ?? (output as { relativePath?: string }).relativePath ?? "",
    })),
  }));

  return data;
}

export class DevStore implements Store {
  filePath: string;
  cache: StoreData;

  constructor(dataDir: string) {
    fs.mkdirSync(dataDir, { recursive: true });
    this.filePath = path.resolve(dataDir, "store.json");
    this.cache = this.load();
  }

  read(): StoreData {
    return this.cache;
  }

  write(next: StoreData): void {
    this.cache = next;
    fs.writeFileSync(this.filePath, JSON.stringify(next, null, 2));
  }

  update(mutator: (current: StoreData) => void): void {
    const current = this.read();
    mutator(current);
    this.write(current);
  }

  async findUserByAppleSubject(appleSubject: string): Promise<UserRecord | undefined> {
    return this.read().users.find((user) => user.appleSubject === appleSubject && !user.deletedAt);
  }

  async findUserById(userId: string): Promise<UserRecord | undefined> {
    return this.read().users.find((user) => user.id === userId && !user.deletedAt);
  }

  async saveUser(user: UserRecord): Promise<void> {
    this.update((data) => {
      const index = data.users.findIndex((record) => record.id === user.id);
      if (index >= 0) {
        data.users[index] = user;
      } else {
        data.users.push(user);
      }
    });
  }

  async markUserDeleted(userId: string, deletedAt: string): Promise<void> {
    this.update((data) => {
      const user = data.users.find((record) => record.id === userId);
      if (!user) {
        return;
      }
      user.deletedAt = deletedAt;
      user.updatedAt = deletedAt;
    });
  }

  async insertRefreshSession(session: RefreshSessionRecord): Promise<void> {
    this.update((data) => {
      data.refreshSessions.push(session);
    });
  }

  async findRefreshSessionByTokenHash(tokenHash: string): Promise<RefreshSessionRecord | undefined> {
    return this.read().refreshSessions.find((record) => record.tokenHash === tokenHash);
  }

  async revokeRefreshSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void> {
    this.update((data) => {
      const record = data.refreshSessions.find((candidate) => candidate.tokenHash === tokenHash);
      if (record && !record.revokedAt) {
        record.revokedAt = revokedAt;
      }
    });
  }

  async revokeRefreshSessionsForUser(userId: string, revokedAt: string): Promise<void> {
    this.update((data) => {
      data.refreshSessions.forEach((record) => {
        if (record.userId === userId && !record.revokedAt) {
          record.revokedAt = revokedAt;
        }
      });
    });
  }

  async insertAccessSession(session: AccessSessionRecord): Promise<void> {
    this.update((data) => {
      data.accessSessions.push(session);
    });
  }

  async findAccessSessionByTokenHash(tokenHash: string): Promise<AccessSessionRecord | undefined> {
    return this.read().accessSessions.find((record) => record.tokenHash === tokenHash);
  }

  async revokeAccessSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void> {
    this.update((data) => {
      const record = data.accessSessions.find((candidate) => candidate.tokenHash === tokenHash);
      if (record && !record.revokedAt) {
        record.revokedAt = revokedAt;
      }
    });
  }

  async revokeAccessSessionsForUser(userId: string, revokedAt: string): Promise<void> {
    this.update((data) => {
      data.accessSessions.forEach((record) => {
        if (record.userId === userId && !record.revokedAt) {
          record.revokedAt = revokedAt;
        }
      });
    });
  }

  async listPurchasesForUser(userId: string): Promise<PurchaseRecord[]> {
    return this.read().purchases.filter((purchase) => purchase.userId === userId);
  }

  async findPurchaseByTransactionId(transactionId: string): Promise<PurchaseRecord | undefined> {
    return this.read().purchases.find((purchase) => purchase.transactionId === transactionId);
  }

  async insertPurchase(purchase: PurchaseRecord): Promise<void> {
    this.update((data) => {
      data.purchases.push(purchase);
    });
  }

  async insertUpload(upload: UploadRecord): Promise<void> {
    this.update((data) => {
      data.uploads.push(upload);
    });
  }

  async findUploadById(uploadId: string, userId: string): Promise<UploadRecord | undefined> {
    return this.read().uploads.find((upload) => upload.id === uploadId && upload.userId === userId);
  }

  async insertJob(job: JobRecord): Promise<void> {
    this.update((data) => {
      data.jobs.unshift(job);
    });
  }

  async listJobsForUser(userId: string): Promise<JobRecord[]> {
    return this.read().jobs.filter((job) => job.userId === userId);
  }

  async findJobById(jobId: string, userId: string): Promise<JobRecord | undefined> {
    return this.read().jobs.find((job) => job.id === jobId && job.userId === userId);
  }

  async saveJob(job: JobRecord): Promise<void> {
    this.update((data) => {
      const index = data.jobs.findIndex((record) => record.id === job.id);
      if (index >= 0) {
        data.jobs[index] = job;
      } else {
        data.jobs.unshift(job);
      }
    });
  }

  load(): StoreData {
    if (!fs.existsSync(this.filePath)) {
      const initial = emptyStore();
      fs.writeFileSync(this.filePath, JSON.stringify(initial, null, 2));
      return initial;
    }

    const raw = fs.readFileSync(this.filePath, "utf8");
    if (!raw.trim()) {
      return emptyStore();
    }

    return mapLegacyStore(JSON.parse(raw) as StoreData);
  }
}

type SupabaseConfig = {
  url: string;
  serviceRoleKey: string;
  schema: string;
};

type QueryValue = string | number | boolean;

function buildQuery(params: Record<string, QueryValue | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) {
      continue;
    }
    search.set(key, String(value));
  }
  const query = search.toString();
  return query ? `?${query}` : "";
}

export class SupabaseStore implements Store {
  url: string;
  serviceRoleKey: string;
  schema: string;

  constructor(config: SupabaseConfig) {
    this.url = config.url.replace(/\/$/, "");
    this.serviceRoleKey = config.serviceRoleKey;
    this.schema = config.schema;
  }

  headers(extra?: Record<string, string>): Record<string, string> {
    return {
      apikey: this.serviceRoleKey,
      Authorization: `Bearer ${this.serviceRoleKey}`,
      "Content-Type": "application/json",
      "Accept-Profile": this.schema,
      "Content-Profile": this.schema,
      ...extra,
    };
  }

  async request<T>(pathname: string, init?: RequestInit): Promise<T> {
    const response = await fetch(`${this.url}/rest/v1/${pathname}`, {
      ...init,
      headers: this.headers(init?.headers as Record<string, string> | undefined),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Supabase request failed (${response.status}): ${body}`);
    }

    if (response.status === 204) {
      return undefined as T;
    }

    const text = await response.text();
    if (!text.trim()) {
      return undefined as T;
    }

    return JSON.parse(text) as T;
  }

  async findUserByAppleSubject(appleSubject: string): Promise<UserRecord | undefined> {
    const rows = await this.request<UserRecord[]>(
      `ios_users${buildQuery({
        select: "*",
        apple_subject: `eq.${appleSubject}`,
        deleted_at: "is.null",
        limit: 1,
      })}`,
    );
    return rows[0] ? mapUserRow(rows[0] as unknown as SupabaseUserRow) : undefined;
  }

  async findUserById(userId: string): Promise<UserRecord | undefined> {
    const rows = await this.request<UserRecord[]>(
      `ios_users${buildQuery({
        select: "*",
        id: `eq.${userId}`,
        deleted_at: "is.null",
        limit: 1,
      })}`,
    );
    return rows[0] ? mapUserRow(rows[0] as unknown as SupabaseUserRow) : undefined;
  }

  async saveUser(user: UserRecord): Promise<void> {
    await this.request(
      "ios_users",
      withBody("POST", [userToRow(user)], {
        Prefer: "resolution=merge-duplicates,return=minimal",
      }),
    );
  }

  async markUserDeleted(userId: string, deletedAt: string): Promise<void> {
    await this.request(
      `ios_users${buildQuery({ id: `eq.${userId}` })}`,
      withBody("PATCH", { deleted_at: deletedAt, updated_at: deletedAt }, { Prefer: "return=minimal" }),
    );
  }

  async insertRefreshSession(session: RefreshSessionRecord): Promise<void> {
    await this.request("ios_refresh_sessions", withBody("POST", [refreshSessionToRow(session)], { Prefer: "return=minimal" }));
  }

  async findRefreshSessionByTokenHash(tokenHash: string): Promise<RefreshSessionRecord | undefined> {
    const rows = await this.request<SupabaseRefreshSessionRow[]>(
      `ios_refresh_sessions${buildQuery({
        select: "*",
        token_hash: `eq.${tokenHash}`,
        limit: 1,
      })}`,
    );
    return rows[0] ? mapRefreshSessionRow(rows[0]) : undefined;
  }

  async revokeRefreshSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void> {
    await this.request(
      `ios_refresh_sessions${buildQuery({ token_hash: `eq.${tokenHash}` })}`,
      withBody("PATCH", { revoked_at: revokedAt }, { Prefer: "return=minimal" }),
    );
  }

  async revokeRefreshSessionsForUser(userId: string, revokedAt: string): Promise<void> {
    await this.request(
      `ios_refresh_sessions${buildQuery({ user_id: `eq.${userId}`, revoked_at: "is.null" })}`,
      withBody("PATCH", { revoked_at: revokedAt }, { Prefer: "return=minimal" }),
    );
  }

  async insertAccessSession(session: AccessSessionRecord): Promise<void> {
    await this.request("ios_access_sessions", withBody("POST", [accessSessionToRow(session)], { Prefer: "return=minimal" }));
  }

  async findAccessSessionByTokenHash(tokenHash: string): Promise<AccessSessionRecord | undefined> {
    const rows = await this.request<SupabaseAccessSessionRow[]>(
      `ios_access_sessions${buildQuery({
        select: "*",
        token_hash: `eq.${tokenHash}`,
        limit: 1,
      })}`,
    );
    return rows[0] ? mapAccessSessionRow(rows[0]) : undefined;
  }

  async revokeAccessSessionByTokenHash(tokenHash: string, revokedAt: string): Promise<void> {
    await this.request(
      `ios_access_sessions${buildQuery({ token_hash: `eq.${tokenHash}` })}`,
      withBody("PATCH", { revoked_at: revokedAt }, { Prefer: "return=minimal" }),
    );
  }

  async revokeAccessSessionsForUser(userId: string, revokedAt: string): Promise<void> {
    await this.request(
      `ios_access_sessions${buildQuery({ user_id: `eq.${userId}`, revoked_at: "is.null" })}`,
      withBody("PATCH", { revoked_at: revokedAt }, { Prefer: "return=minimal" }),
    );
  }

  async listPurchasesForUser(userId: string): Promise<PurchaseRecord[]> {
    const rows = await this.request<SupabasePurchaseRow[]>(
      `ios_purchases${buildQuery({
        select: "*",
        user_id: `eq.${userId}`,
        order: "expires_at.desc",
      })}`,
    );
    return rows.map(mapPurchaseRow);
  }

  async findPurchaseByTransactionId(transactionId: string): Promise<PurchaseRecord | undefined> {
    const rows = await this.request<SupabasePurchaseRow[]>(
      `ios_purchases${buildQuery({
        select: "*",
        transaction_id: `eq.${transactionId}`,
        limit: 1,
      })}`,
    );
    return rows[0] ? mapPurchaseRow(rows[0]) : undefined;
  }

  async insertPurchase(purchase: PurchaseRecord): Promise<void> {
    await this.request("ios_purchases", withBody("POST", [purchaseToRow(purchase)], { Prefer: "return=minimal" }));
  }

  async insertUpload(upload: UploadRecord): Promise<void> {
    await this.request("ios_uploads", withBody("POST", [uploadToRow(upload)], { Prefer: "return=minimal" }));
  }

  async findUploadById(uploadId: string, userId: string): Promise<UploadRecord | undefined> {
    const rows = await this.request<SupabaseUploadRow[]>(
      `ios_uploads${buildQuery({
        select: "*",
        id: `eq.${uploadId}`,
        user_id: `eq.${userId}`,
        limit: 1,
      })}`,
    );
    return rows[0] ? mapUploadRow(rows[0]) : undefined;
  }

  async insertJob(job: JobRecord): Promise<void> {
    await this.request("ios_jobs", withBody("POST", [jobToRow(job)], { Prefer: "return=minimal" }));
  }

  async listJobsForUser(userId: string): Promise<JobRecord[]> {
    const rows = await this.request<SupabaseJobRow[]>(
      `ios_jobs${buildQuery({
        select: "*",
        user_id: `eq.${userId}`,
        order: "created_at.desc",
      })}`,
    );
    return rows.map(mapJobRow);
  }

  async findJobById(jobId: string, userId: string): Promise<JobRecord | undefined> {
    const rows = await this.request<SupabaseJobRow[]>(
      `ios_jobs${buildQuery({
        select: "*",
        id: `eq.${jobId}`,
        user_id: `eq.${userId}`,
        limit: 1,
      })}`,
    );
    return rows[0] ? mapJobRow(rows[0]) : undefined;
  }

  async saveJob(job: JobRecord): Promise<void> {
    await this.request(
      `ios_jobs${buildQuery({ id: `eq.${job.id}` })}`,
      withBody("PATCH", jobToRow(job), { Prefer: "return=minimal" }),
    );
  }
}

function withBody(method: string, body: unknown, headers?: Record<string, string>): RequestInit {
  return {
    method,
    headers,
    body: JSON.stringify(body),
  };
}

type SupabaseUserRow = {
  id: string;
  apple_subject: string;
  email?: string | null;
  email_verified?: boolean | null;
  is_private_email?: boolean | null;
  display_name?: string | null;
  deleted_at?: string | null;
  created_at: string;
  updated_at: string;
};

type SupabaseRefreshSessionRow = {
  token_hash: string;
  token_hint?: string | null;
  user_id: string;
  expires_at: string;
  created_at: string;
  revoked_at?: string | null;
};

type SupabaseAccessSessionRow = {
  token_hash: string;
  token_hint?: string | null;
  user_id: string;
  expires_at: string;
  created_at: string;
  refresh_token_hash?: string | null;
  revoked_at?: string | null;
};

type SupabasePurchaseRow = {
  id: string;
  user_id: string;
  product_id: string;
  transaction_id: string;
  original_transaction_id?: string | null;
  app_account_token?: string | null;
  signed_transaction_info?: string | null;
  expires_at: string;
  source: "sync" | "restore";
  environment?: string | null;
  created_at: string;
  purchase_date?: string | null;
  original_purchase_date?: string | null;
  web_order_line_item_id?: string | null;
  ownership_type?: string | null;
  revocation_reason?: string | null;
  revoked_at?: string | null;
};

type SupabaseUploadRow = {
  id: string;
  user_id: string;
  filename: string;
  mime_type: string;
  storage_key: string;
  created_at: string;
};

type SupabaseJobOutputRow = {
  id: string;
  mime_type: string;
  storage_key: string;
};

type SupabaseJobRow = {
  id: string;
  user_id: string;
  model_id: string;
  model_name?: string | null;
  prompt?: string | null;
  negative_prompt?: string | null;
  image_url?: string | null;
  status: JobRecord["status"];
  created_at: string;
  updated_at: string;
  error_message?: string | null;
  outputs?: SupabaseJobOutputRow[] | null;
};

function mapUserRow(row: SupabaseUserRow): UserRecord {
  return {
    id: row.id,
    appleSubject: row.apple_subject,
    email: row.email ?? undefined,
    emailVerified: row.email_verified ?? undefined,
    isPrivateEmail: row.is_private_email ?? undefined,
    displayName: row.display_name ?? undefined,
    deletedAt: row.deleted_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function userToRow(user: UserRecord): SupabaseUserRow {
  return {
    id: user.id,
    apple_subject: user.appleSubject,
    email: user.email ?? null,
    email_verified: user.emailVerified ?? null,
    is_private_email: user.isPrivateEmail ?? null,
    display_name: user.displayName ?? null,
    deleted_at: user.deletedAt ?? null,
    created_at: user.createdAt,
    updated_at: user.updatedAt,
  };
}

function mapRefreshSessionRow(row: SupabaseRefreshSessionRow): RefreshSessionRecord {
  return {
    tokenHash: row.token_hash,
    tokenHint: row.token_hint ?? undefined,
    userId: row.user_id,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    revokedAt: row.revoked_at ?? undefined,
  };
}

function refreshSessionToRow(session: RefreshSessionRecord): SupabaseRefreshSessionRow {
  return {
    token_hash: session.tokenHash,
    token_hint: session.tokenHint ?? null,
    user_id: session.userId,
    expires_at: session.expiresAt,
    created_at: session.createdAt,
    revoked_at: session.revokedAt ?? null,
  };
}

function mapAccessSessionRow(row: SupabaseAccessSessionRow): AccessSessionRecord {
  return {
    tokenHash: row.token_hash,
    tokenHint: row.token_hint ?? undefined,
    userId: row.user_id,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    refreshTokenHash: row.refresh_token_hash ?? undefined,
    revokedAt: row.revoked_at ?? undefined,
  };
}

function accessSessionToRow(session: AccessSessionRecord): SupabaseAccessSessionRow {
  return {
    token_hash: session.tokenHash,
    token_hint: session.tokenHint ?? null,
    user_id: session.userId,
    expires_at: session.expiresAt,
    created_at: session.createdAt,
    refresh_token_hash: session.refreshTokenHash ?? null,
    revoked_at: session.revokedAt ?? null,
  };
}

function mapPurchaseRow(row: SupabasePurchaseRow): PurchaseRecord {
  return {
    id: row.id,
    userId: row.user_id,
    productId: row.product_id,
    transactionId: row.transaction_id,
    originalTransactionId: row.original_transaction_id ?? undefined,
    appAccountToken: row.app_account_token ?? undefined,
    signedTransactionInfo: row.signed_transaction_info ?? undefined,
    expiresAt: row.expires_at,
    source: row.source,
    environment: row.environment ?? undefined,
    createdAt: row.created_at,
    purchaseDate: row.purchase_date ?? undefined,
    originalPurchaseDate: row.original_purchase_date ?? undefined,
    webOrderLineItemId: row.web_order_line_item_id ?? undefined,
    ownershipType: row.ownership_type ?? undefined,
    revocationReason: row.revocation_reason ?? undefined,
    revokedAt: row.revoked_at ?? undefined,
  };
}

function purchaseToRow(purchase: PurchaseRecord): SupabasePurchaseRow {
  return {
    id: purchase.id,
    user_id: purchase.userId,
    product_id: purchase.productId,
    transaction_id: purchase.transactionId,
    original_transaction_id: purchase.originalTransactionId ?? null,
    app_account_token: purchase.appAccountToken ?? null,
    signed_transaction_info: purchase.signedTransactionInfo ?? null,
    expires_at: purchase.expiresAt,
    source: purchase.source,
    environment: purchase.environment ?? "sandbox",
    created_at: purchase.createdAt,
    purchase_date: purchase.purchaseDate ?? null,
    original_purchase_date: purchase.originalPurchaseDate ?? null,
    web_order_line_item_id: purchase.webOrderLineItemId ?? null,
    ownership_type: purchase.ownershipType ?? null,
    revocation_reason: purchase.revocationReason ?? null,
    revoked_at: purchase.revokedAt ?? null,
  };
}

function mapUploadRow(row: SupabaseUploadRow): UploadRecord {
  return {
    id: row.id,
    userId: row.user_id,
    filename: row.filename,
    mimeType: row.mime_type,
    storageKey: row.storage_key,
    createdAt: row.created_at,
  };
}

function uploadToRow(upload: UploadRecord): SupabaseUploadRow {
  return {
    id: upload.id,
    user_id: upload.userId,
    filename: upload.filename,
    mime_type: upload.mimeType,
    storage_key: upload.storageKey,
    created_at: upload.createdAt,
  };
}

function mapJobRow(row: SupabaseJobRow): JobRecord {
  return {
    id: row.id,
    userId: row.user_id,
    modelId: row.model_id,
    modelName: row.model_name ?? undefined,
    prompt: row.prompt ?? undefined,
    negativePrompt: row.negative_prompt ?? undefined,
    imageUrl: row.image_url ?? undefined,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    errorMessage: row.error_message ?? undefined,
    outputs: (row.outputs ?? []).map((output) => ({
      id: output.id,
      mimeType: output.mime_type,
      storageKey: output.storage_key,
    })),
  };
}

function jobToRow(job: JobRecord): SupabaseJobRow {
  return {
    id: job.id,
    user_id: job.userId,
    model_id: job.modelId,
    model_name: job.modelName ?? null,
    prompt: job.prompt ?? null,
    negative_prompt: job.negativePrompt ?? null,
    image_url: job.imageUrl ?? null,
    status: job.status,
    created_at: job.createdAt,
    updated_at: job.updatedAt,
    error_message: job.errorMessage ?? null,
    outputs: job.outputs.map((output) => ({
      id: output.id,
      mime_type: output.mimeType,
      storage_key: output.storageKey,
    })),
  };
}

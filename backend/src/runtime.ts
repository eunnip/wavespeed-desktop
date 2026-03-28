import { createBackendApp, type BackendApp } from "./app.ts";
import { config, requireConfig } from "./config.ts";
import { LocalObjectStorage, R2ObjectStorage, type ObjectStorage } from "./object-storage.ts";
import { DevStore, SupabaseStore, type Store } from "./store.ts";

let cachedApp: BackendApp | undefined;

function createStore(): Store {
  if (config.databaseProvider === "supabase") {
    return new SupabaseStore({
      url: requireConfig(config.supabaseURL, "SUPABASE_URL is required."),
      serviceRoleKey: requireConfig(
        config.supabaseServiceRoleKey,
        "SUPABASE_SERVICE_ROLE_KEY is required.",
      ),
      schema: config.supabaseSchema,
    });
  }

  return new DevStore(config.dataDir);
}

function createObjectStorage(): ObjectStorage {
  if (config.blobProvider === "r2") {
    return new R2ObjectStorage({
      accountId: requireConfig(config.r2AccountId, "R2_ACCOUNT_ID is required."),
      bucket: requireConfig(config.r2Bucket, "R2_BUCKET is required."),
      accessKeyId: requireConfig(config.r2AccessKeyId, "R2_ACCESS_KEY_ID is required."),
      secretAccessKey: requireConfig(
        config.r2SecretAccessKey,
        "R2_SECRET_ACCESS_KEY is required.",
      ),
      endpoint: config.r2Endpoint || undefined,
    });
  }

  return new LocalObjectStorage(config.dataDir);
}

export function getBackendApp(): BackendApp {
  if (!cachedApp) {
    cachedApp = createBackendApp({
      config,
      store: createStore(),
      objectStorage: createObjectStorage(),
    });
  }

  return cachedApp;
}

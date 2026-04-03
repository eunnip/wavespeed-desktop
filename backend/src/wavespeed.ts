type WaveSpeedConfig = {
  apiKey: string;
  apiBaseURL: string;
  modelAllowlist: string[];
  catalogCacheTTLSeconds: number;
};

type WaveSpeedJSONSchemaProperty = {
  type?: string;
  default?: unknown;
  description?: string;
};

type WaveSpeedRequestSchema = {
  properties?: Record<string, WaveSpeedJSONSchemaProperty>;
  required?: string[];
};

type WaveSpeedModelRunSchema = {
  type?: string;
  method?: string;
  server?: string;
  api_path?: string;
  request_schema?: WaveSpeedRequestSchema;
};

type WaveSpeedModelRecord = {
  model_id?: string;
  name?: string;
  description?: string;
  type?: string;
  thumbnail_url?: string;
  api_schema?: {
    api_schemas?: WaveSpeedModelRunSchema[];
  };
};

type WaveSpeedEnvelope<T> = {
  code?: number;
  message?: string;
  error?: string;
  data?: T;
};

type WaveSpeedCreatePredictionData = {
  id?: string;
  status?: string;
  urls?: {
    get?: string;
  };
};

type WaveSpeedPredictionData = {
  id?: string;
  status?: string;
  outputs?: unknown[];
  urls?: {
    get?: string;
  };
  error?: string;
};

type WaveSpeedUploadData = {
  type?: string;
  download_url?: string;
  filename?: string;
  size?: number;
};

type WaveSpeedDeletePredictionsData = {
  deleted_count?: number;
};

export type WaveSpeedCatalogModel = {
  id: string;
  name: string;
  summary: string;
  kind: "image" | "video" | "edit";
  thumbnailUrl?: string;
  requiresImageInput: boolean;
  apiPath: string;
  promptField: string;
  negativePromptField?: string;
  imageField?: string;
};

export type WaveSpeedCreatePredictionResult = {
  id: string;
  status: string;
  resultUrl?: string;
};

export type WaveSpeedPredictionResult = {
  id: string;
  status: string;
  outputs: string[];
  errorMessage?: string;
  resultUrl?: string;
};

export type WaveSpeedUploadResult = {
  type?: string;
  downloadUrl: string;
  filename?: string;
  size?: number;
};

export class WaveSpeedAPIError extends Error {
  readonly status: number;
  readonly details?: string;

  constructor(status: number, message: string, details?: string) {
    super(message);
    this.name = "WaveSpeedAPIError";
    this.status = status;
    this.details = details;
  }
}

const PROMPT_FIELD_CANDIDATES = ["prompt", "text", "text_prompt"];
const NEGATIVE_PROMPT_FIELD_CANDIDATES = ["negative_prompt"];
const IMAGE_FIELD_CANDIDATES = [
  "image_url",
  "image",
  "input_image",
  "start_image",
  "first_frame_image",
  "reference_image",
  "source_image",
];
const SUPPORTED_MODEL_TYPES = new Set([
  "text-to-image",
  "image-to-image",
  "text-to-video",
  "image-to-video",
]);

let cachedModelRecords:
  | {
      expiresAt: number;
      models: WaveSpeedModelRecord[];
    }
  | undefined;

function normalizeBaseURL(value: string): string {
  return value.replace(/\/+$/, "");
}

function apiOrigin(baseURL: string): string {
  return new URL(baseURL).origin;
}

function formatProviderError(text: string): string {
  return text.trim() || "WaveSpeed request failed.";
}

function sanitizeSummary(value: string | undefined): string {
  return value?.trim() || "AI generation model available through WaveSpeed.";
}

function pickFieldName(
  properties: Record<string, WaveSpeedJSONSchemaProperty> | undefined,
  candidates: readonly string[],
): string | undefined {
  if (!properties) {
    return undefined;
  }
  return candidates.find((candidate) => properties[candidate] !== undefined);
}

function humanizeModelId(modelID: string): string {
  return modelID
    .split("/")
    .at(-1)
    ?.split(/[-_]/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ") ?? modelID;
}

function normalizeKind(type: string | undefined, requiresImageInput: boolean): "image" | "video" | "edit" {
  const normalized = (type ?? "").toLowerCase();
  if (normalized.includes("video")) {
    return "video";
  }
  if (normalized === "image-to-image" || requiresImageInput) {
    return "edit";
  }
  return "image";
}

function resolveAPIPath(baseURL: string, schema: WaveSpeedModelRunSchema): string | undefined {
  if (!schema.api_path) {
    return undefined;
  }
  if (/^https?:\/\//i.test(schema.api_path)) {
    return schema.api_path;
  }
  const base = schema.server ? normalizeBaseURL(schema.server) : apiOrigin(baseURL);
  return `${base}${schema.api_path.startsWith("/") ? schema.api_path : `/${schema.api_path}`}`;
}

function selectRunSchema(model: WaveSpeedModelRecord): WaveSpeedModelRunSchema | undefined {
  return (model.api_schema?.api_schemas ?? []).find((schema) => {
    return schema.type === "model_run" && (schema.method ?? "POST").toUpperCase() === "POST";
  });
}

function isSupportedSchema(
  requestSchema: WaveSpeedRequestSchema | undefined,
  promptField: string | undefined,
  imageField: string | undefined,
): boolean {
  if (!requestSchema || !promptField) {
    return false;
  }

  const required = requestSchema.required ?? [];
  const supportedRequiredFields = new Set([promptField]);
  if (imageField) {
    supportedRequiredFields.add(imageField);
  }

  return required.every((field) => supportedRequiredFields.has(field));
}

function toCatalogModel(
  baseURL: string,
  model: WaveSpeedModelRecord,
): WaveSpeedCatalogModel | undefined {
  const normalizedType = (model.type ?? "").toLowerCase();
  if (!SUPPORTED_MODEL_TYPES.has(normalizedType)) {
    return undefined;
  }

  const runSchema = selectRunSchema(model);
  if (!runSchema) {
    return undefined;
  }

  const properties = runSchema.request_schema?.properties;
  const promptField = pickFieldName(properties, PROMPT_FIELD_CANDIDATES);
  const imageField = pickFieldName(properties, IMAGE_FIELD_CANDIDATES);
  if (!isSupportedSchema(runSchema.request_schema, promptField, imageField)) {
    return undefined;
  }

  const apiPath = resolveAPIPath(baseURL, runSchema);
  if (!apiPath) {
    return undefined;
  }

  const requiresImageInput =
    normalizedType === "image-to-image" ||
    normalizedType === "image-to-video" ||
    Boolean(imageField && (runSchema.request_schema?.required ?? []).includes(imageField));

  return {
    id: model.model_id ?? "",
    name:
      model.name && model.name !== model.model_id
        ? model.name
        : humanizeModelId(model.model_id ?? "WaveSpeed Model"),
    summary: sanitizeSummary(model.description),
    kind: normalizeKind(model.type, requiresImageInput),
    thumbnailUrl: model.thumbnail_url ?? undefined,
    requiresImageInput,
    apiPath,
    promptField,
    negativePromptField: pickFieldName(properties, NEGATIVE_PROMPT_FIELD_CANDIDATES),
    imageField,
  };
}

function uniqueStrings(values: Array<string | undefined>): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

async function parseEnvelope<T>(response: Response): Promise<WaveSpeedEnvelope<T>> {
  const text = await response.text();
  if (!text.trim()) {
    return {};
  }

  try {
    return JSON.parse(text) as WaveSpeedEnvelope<T>;
  } catch {
    throw new WaveSpeedAPIError(response.status, formatProviderError(text), text);
  }
}

async function fetchWaveSpeed<T>(
  config: WaveSpeedConfig,
  url: string,
  init: RequestInit,
): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      ...(init.headers ?? {}),
    },
  });

  const envelope = await parseEnvelope<T>(response);
  if (!response.ok) {
    throw new WaveSpeedAPIError(
      response.status,
      formatProviderError(envelope.error ?? envelope.message ?? ""),
      JSON.stringify(envelope),
    );
  }

  if (envelope.data === undefined) {
    throw new WaveSpeedAPIError(
      response.status,
      formatProviderError(envelope.error ?? envelope.message ?? "WaveSpeed returned no data."),
      JSON.stringify(envelope),
    );
  }

  return envelope.data;
}

async function listModelRecords(config: WaveSpeedConfig): Promise<WaveSpeedModelRecord[]> {
  if (cachedModelRecords && Date.now() < cachedModelRecords.expiresAt) {
    return cachedModelRecords.models;
  }

  const models = await fetchWaveSpeed<WaveSpeedModelRecord[]>(
    config,
    `${normalizeBaseURL(config.apiBaseURL)}/models`,
    {
      method: "GET",
    },
  );

  cachedModelRecords = {
    expiresAt: Date.now() + config.catalogCacheTTLSeconds * 1000,
    models,
  };

  return models;
}

function sortCatalogModels(
  models: WaveSpeedCatalogModel[],
  allowlist: string[],
): WaveSpeedCatalogModel[] {
  if (allowlist.length === 0) {
    return [...models].sort((left, right) => {
      const leftKey = `${left.kind}:${left.name.toLowerCase()}`;
      const rightKey = `${right.kind}:${right.name.toLowerCase()}`;
      return leftKey.localeCompare(rightKey);
    });
  }

  const order = new Map(allowlist.map((id, index) => [id, index]));
  return [...models].sort((left, right) => {
    return (order.get(left.id) ?? Number.MAX_SAFE_INTEGER) - (order.get(right.id) ?? Number.MAX_SAFE_INTEGER);
  });
}

function ensurePlainObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return { ...(value as Record<string, unknown>) };
}

function normalizePredictionStatus(status: string | undefined): string {
  return (status ?? "created").toLowerCase();
}

function extractOutputUrls(outputs: unknown): string[] {
  if (!Array.isArray(outputs)) {
    return [];
  }

  return outputs.flatMap((output) => {
    if (typeof output === "string") {
      return [output];
    }

    if (!output || typeof output !== "object") {
      return [];
    }

    const candidate = output as {
      url?: string;
      download_url?: string;
      uri?: string;
    };

    return [candidate.url, candidate.download_url, candidate.uri].filter(
      (value): value is string => Boolean(value),
    );
  });
}

export async function listCatalogModels(config: WaveSpeedConfig): Promise<WaveSpeedCatalogModel[]> {
  const records = await listModelRecords(config);
  const allowlist = config.modelAllowlist;
  const filteredRecords =
    allowlist.length === 0
      ? records
      : records.filter((record) => allowlist.includes(record.model_id ?? ""));

  const catalog = filteredRecords
    .map((record) => toCatalogModel(config.apiBaseURL, record))
    .filter((record): record is WaveSpeedCatalogModel => Boolean(record && record.id));

  if (allowlist.length > 0 && catalog.length === 0) {
    throw new WaveSpeedAPIError(
      500,
      "No compatible WaveSpeed models matched WAVESPEED_MODEL_ALLOWLIST.",
    );
  }

  return sortCatalogModels(catalog, allowlist);
}

export function buildPredictionInput(
  model: WaveSpeedCatalogModel,
  request: {
    prompt: string;
    negativePrompt?: string;
    imageUrl?: string;
    parameters?: unknown;
  },
): Record<string, unknown> {
  const payload = ensurePlainObject(request.parameters);
  payload[model.promptField] = request.prompt;

  if (model.negativePromptField && request.negativePrompt?.trim()) {
    payload[model.negativePromptField] = request.negativePrompt.trim();
  }

  if (model.requiresImageInput && !request.imageUrl) {
    throw new WaveSpeedAPIError(422, "This model requires an uploaded reference image.");
  }

  if (model.imageField && request.imageUrl) {
    payload[model.imageField] = request.imageUrl;
  }

  return payload;
}

export async function createPrediction(
  config: WaveSpeedConfig,
  model: WaveSpeedCatalogModel,
  input: Record<string, unknown>,
): Promise<WaveSpeedCreatePredictionResult> {
  const data = await fetchWaveSpeed<WaveSpeedCreatePredictionData>(config, model.apiPath, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(input),
  });

  if (!data.id) {
    throw new WaveSpeedAPIError(502, "WaveSpeed did not return a task ID.");
  }

  return {
    id: data.id,
    status: normalizePredictionStatus(data.status),
    resultUrl: data.urls?.get,
  };
}

export async function getPrediction(
  config: WaveSpeedConfig,
  taskID: string,
  resultUrl?: string,
): Promise<WaveSpeedPredictionResult> {
  const baseURL = normalizeBaseURL(config.apiBaseURL);
  const candidateURLs = uniqueStrings([
    resultUrl,
    `${baseURL}/predictions/${encodeURIComponent(taskID)}`,
    `${baseURL}/predictions/${encodeURIComponent(taskID)}/result`,
  ]);

  let lastError: Error | undefined;

  for (const candidateURL of candidateURLs) {
    try {
      const data = await fetchWaveSpeed<WaveSpeedPredictionData>(config, candidateURL, {
        method: "GET",
      });

      return {
        id: data.id ?? taskID,
        status: normalizePredictionStatus(data.status),
        outputs: extractOutputUrls(data.outputs),
        errorMessage: data.error ?? undefined,
        resultUrl: data.urls?.get ?? resultUrl,
      };
    } catch (error) {
      if (
        error instanceof WaveSpeedAPIError &&
        error.status === 404 &&
        candidateURL !== candidateURLs.at(-1)
      ) {
        lastError = error;
        continue;
      }
      throw error;
    }
  }

  throw lastError ?? new WaveSpeedAPIError(404, "WaveSpeed task could not be found.");
}

export async function uploadBinary(
  config: WaveSpeedConfig,
  file: {
    filename: string;
    mimeType: string;
    data: Uint8Array;
  },
): Promise<WaveSpeedUploadResult> {
  const form = new FormData();
  form.append("file", new Blob([file.data], { type: file.mimeType }), file.filename);

  const data = await fetchWaveSpeed<WaveSpeedUploadData>(
    config,
    `${normalizeBaseURL(config.apiBaseURL)}/media/upload/binary`,
    {
      method: "POST",
      body: form,
    },
  );

  if (!data.download_url) {
    throw new WaveSpeedAPIError(502, "WaveSpeed did not return an uploaded file URL.");
  }

  return {
    type: data.type,
    downloadUrl: data.download_url,
    filename: data.filename,
    size: data.size,
  };
}

export async function deletePredictions(
  config: WaveSpeedConfig,
  taskIDs: string[],
): Promise<number> {
  if (taskIDs.length === 0) {
    return 0;
  }

  const data = await fetchWaveSpeed<WaveSpeedDeletePredictionsData>(
    config,
    `${normalizeBaseURL(config.apiBaseURL)}/predictions/delete`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ ids: taskIDs }),
    },
  );

  return data.deleted_count ?? 0;
}

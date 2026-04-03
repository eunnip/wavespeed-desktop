import type { IncomingMessage, ServerResponse } from "node:http";

import type { BackendApp } from "./app.ts";

async function toRequest(request: IncomingMessage): Promise<Request> {
  const protocol = request.headers["x-forwarded-proto"] ?? "http";
  const host = request.headers.host ?? "127.0.0.1";
  const url = new URL(`${protocol}://${host}${request.url ?? "/"}`);
  const pathnameOverride = url.searchParams.get("__pathname");
  if (pathnameOverride) {
    url.pathname = pathnameOverride.startsWith("/") ? pathnameOverride : `/${pathnameOverride}`;
    url.searchParams.delete("__pathname");
  }

  const headers = new Headers();
  for (const [key, value] of Object.entries(request.headers)) {
    if (Array.isArray(value)) {
      for (const entry of value) {
        headers.append(key, entry);
      }
      continue;
    }
    if (typeof value === "string") {
      headers.set(key, value);
    }
  }

  const hasBody = !["GET", "HEAD"].includes((request.method ?? "GET").toUpperCase());
  const body = hasBody ? Buffer.from(await readNodeBody(request)) : undefined;

  return new Request(url, {
    method: request.method ?? "GET",
    headers,
    body,
    duplex: "half",
  } as RequestInit);
}

function readNodeBody(request: IncomingMessage): Promise<Uint8Array> {
  const requestPath = request.url ?? "";
  const knownBody = (request as IncomingMessage & {
    body?: unknown;
    rawBody?: Buffer | Uint8Array | string;
  }).body;
  const rawBody = (request as IncomingMessage & {
    body?: unknown;
    rawBody?: Buffer | Uint8Array | string;
  }).rawBody;

  const isBinaryBody = (value: unknown): value is Buffer | Uint8Array | ArrayBuffer =>
    value instanceof Uint8Array || value instanceof ArrayBuffer;

  if (rawBody !== undefined) {
    if (typeof rawBody === "string") {
      return Promise.resolve(Buffer.from(rawBody));
    }
    return Promise.resolve(Buffer.from(rawBody));
  }

  if (knownBody !== undefined) {
    if (typeof knownBody === "string") {
      return Promise.resolve(Buffer.from(knownBody));
    }
    if (isBinaryBody(knownBody)) {
      return Promise.resolve(Buffer.from(knownBody));
    }
    if (
      knownBody &&
      typeof knownBody === "object" &&
      (knownBody as { constructor?: { name?: string } }).constructor?.name === "Object"
    ) {
      return Promise.resolve(Buffer.from(JSON.stringify(knownBody)));
    }
  }

  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    request.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

async function writeResponse(response: ServerResponse, result: Response): Promise<void> {
  response.statusCode = result.status;
  result.headers.forEach((value, key) => {
    response.setHeader(key, value);
  });

  const body = new Uint8Array(await result.arrayBuffer());
  response.end(body);
}

export async function handleNodeRequest(
  request: IncomingMessage,
  response: ServerResponse,
  app: BackendApp,
): Promise<void> {
  const webRequest = await toRequest(request);
  const result = await app.handle(webRequest);
  await writeResponse(response, result);
}

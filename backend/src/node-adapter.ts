import type { IncomingMessage, ServerResponse } from "node:http";

import type { BackendApp } from "./app.ts";

async function toRequest(request: IncomingMessage): Promise<Request> {
  const protocol = request.headers["x-forwarded-proto"] ?? "http";
  const host = request.headers.host ?? "127.0.0.1";
  const url = `${protocol}://${host}${request.url ?? "/"}`;

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
  });
}

function readNodeBody(request: IncomingMessage): Promise<Uint8Array> {
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

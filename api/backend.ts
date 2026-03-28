// @ts-nocheck
import { handleNodeRequest } from "../backend/src/node-adapter.ts";
import { getBackendApp } from "../backend/src/runtime.ts";

const app = getBackendApp();

export const config = {
  api: {
    bodyParser: false,
  },
};

export default async function handler(request: any, response: any): Promise<void> {
  if (request?.method === "POST") {
    console.log(
      JSON.stringify({
        path: request.url,
        hasBodyProperty: Object.prototype.hasOwnProperty.call(request, "body"),
        bodyType: typeof request.body,
        hasRawBodyProperty: Object.prototype.hasOwnProperty.call(request, "rawBody"),
        rawBodyType: typeof request.rawBody,
        contentType: request.headers?.["content-type"] ?? null,
        contentLength: request.headers?.["content-length"] ?? null,
      }),
    );
  }
  await handleNodeRequest(request, response, app);
}

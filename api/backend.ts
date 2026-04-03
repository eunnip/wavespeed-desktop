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
  await handleNodeRequest(request, response, app);
}

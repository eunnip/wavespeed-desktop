import http from "node:http";

import { config } from "./config.ts";
import { handleNodeRequest } from "./node-adapter.ts";
import { getBackendApp } from "./runtime.ts";

const app = getBackendApp();

const server = http.createServer(async (request, response) => {
  await handleNodeRequest(request, response, app);
});

server.listen(config.port, config.host, () => {
  const address = config.baseURL || `http://${config.host}:${config.port}`;
  // eslint-disable-next-line no-console
  console.log(`iOS backend listening on ${address}`);
});

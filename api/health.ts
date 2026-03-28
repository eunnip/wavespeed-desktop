// Vercel executes these Node functions as CommonJS in this project layout.
// Use require/module.exports here to avoid ESM loader issues at runtime.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { handleNodeRequest } = require("../backend/src/node-adapter.ts");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { getBackendApp } = require("../backend/src/runtime.ts");

const app = getBackendApp();

module.exports = async function handler(request, response) {
  await handleNodeRequest(request, response, app);
};

import { createServer } from "node:http";

const authRequests = [];
const offerInserts = [];
const offerFailures = [];

const session = {
  access_token: "qa251-access-token",
  token_type: "bearer",
  expires_in: 3600,
  refresh_token: "qa251-refresh-token",
  user: {
    id: "00000000-0000-4000-8000-00000000251",
    aud: "authenticated",
    role: "authenticated",
    email: "qa251@example.test",
    app_metadata: { provider: "google", providers: ["google"] },
    user_metadata: {},
    created_at: "2026-11-07T00:00:00.000Z",
    updated_at: "2026-11-07T00:00:00.000Z",
  },
};

const profile = {
  actor_id: "30000000-0000-4000-8000-00000000336",
};

function sendJson(response, status, body) {
  response.writeHead(status, {
    "content-type": "application/json",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(body));
}

function sendEmpty(response, status, headers = {}) {
  response.writeHead(status, {
    "cache-control": "no-store",
    ...headers,
  });
  response.end();
}

async function readJsonBody(request) {
  let rawBody = "";
  for await (const chunk of request) rawBody += chunk;
  return JSON.parse(rawBody);
}

function hasSyntheticAuthorization(request) {
  return request.headers.authorization === `Bearer ${session.access_token}`;
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url ?? "/", "http://127.0.0.1:54321");

  if (request.method === "GET" && url.pathname === "/health") {
    response.writeHead(200, { "content-type": "text/plain" });
    response.end("ok");
    return;
  }

  if (request.method === "GET" && url.pathname === "/auth/v1/user") {
    if (!hasSyntheticAuthorization(request)) {
      sendJson(response, 401, {
        code: "invalid_token",
        message: "Invalid synthetic access token",
      });
      return;
    }

    sendJson(response, 200, session.user);
    return;
  }

  if (request.method === "GET" && url.pathname === "/__test/requests") {
    sendJson(response, 200, authRequests);
    return;
  }

  if (request.method === "GET" && url.pathname === "/__test/offers") {
    const name = url.searchParams.get("name");
    if (!name) {
      sendJson(response, 400, { error: "OFFER_NAME_REQUIRED" });
      return;
    }
    const matchingInserts = offerInserts.filter((entry) => entry.payload.name === name);
    sendJson(response, 200, matchingInserts);
    return;
  }

  if (request.method === "GET" && url.pathname === "/__test/offer-failures") {
    const name = url.searchParams.get("name");
    if (!name) {
      sendJson(response, 400, { error: "OFFER_NAME_REQUIRED" });
      return;
    }
    sendJson(response, 200, offerFailures.filter((entry) => entry.name === name));
    return;
  }

  if (request.method === "DELETE" && url.pathname === "/__test/offers") {
    const name = url.searchParams.get("name");
    let deleted = 0;
    for (let index = offerInserts.length - 1; index >= 0; index -= 1) {
      if (!name || offerInserts[index].payload.name === name) {
        offerInserts.splice(index, 1);
        deleted += 1;
      }
    }
    let failuresDeleted = 0;
    for (let index = offerFailures.length - 1; index >= 0; index -= 1) {
      if (!name || offerFailures[index].name === name) {
        offerFailures.splice(index, 1);
        failuresDeleted += 1;
      }
    }
    sendJson(response, 200, { deleted, failuresDeleted });
    return;
  }

  if (request.method === "GET" && url.pathname === "/rest/v1/profiles") {
    if (!hasSyntheticAuthorization(request)) {
      sendJson(response, 401, { code: "PGRST301", message: "Unauthorized synthetic request" });
      return;
    }

    if (
      url.searchParams.get("select") !== "actor_id" ||
      url.searchParams.get("auth_user_id") !== `eq.${session.user.id}`
    ) {
      sendJson(response, 400, { code: "PGRST100", message: "Unexpected synthetic profile query" });
      return;
    }

    sendJson(response, 200, profile);
    return;
  }

  if (request.method === "POST" && url.pathname === "/rest/v1/offers") {
    if (!hasSyntheticAuthorization(request)) {
      sendJson(response, 401, { code: "PGRST301", message: "Unauthorized synthetic request" });
      return;
    }

    try {
      const payload = await readJsonBody(request);
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        sendJson(response, 400, { code: "PGRST102", message: "Expected one offer object" });
        return;
      }

      const transientRetryMatch = /^QA338 transient retry retry-\d+$/.exec(payload.name);
      if (transientRetryMatch && !offerFailures.some((entry) => entry.name === payload.name)) {
        offerFailures.push({ name: payload.name, status: 503, code: "PGRST_QA338" });
        sendJson(response, 503, {
          code: "PGRST_QA338",
          message: "SYNTHETIC_DATABASE_INTERNAL_DETAIL",
        });
        return;
      }

      const failureMatch = /^QA337 PostgREST failure (400|403|500) retry-\d+$/.exec(payload.name);
      if (failureMatch) {
        const status = Number(failureMatch[1]);
        offerFailures.push({ name: payload.name, status, code: "PGRST_QA337" });
        sendJson(response, status, {
          code: "PGRST_QA337",
          message: "SYNTHETIC_DATABASE_INTERNAL_DETAIL",
        });
        return;
      }

      offerInserts.push({
        payload,
        contentType: request.headers["content-type"] ?? null,
        prefer: request.headers.prefer ?? null,
        authorizationValid: true,
      });
      sendEmpty(response, 201, { "content-range": "*/0" });
    } catch {
      sendJson(response, 400, { code: "PGRST102", message: "Invalid synthetic offer JSON" });
    }
    return;
  }

  if (
    request.method === "POST" &&
    url.pathname === "/auth/v1/token" &&
    url.searchParams.get("grant_type") === "pkce"
  ) {
    let rawBody = "";
    for await (const chunk of request) rawBody += chunk;
    const body = JSON.parse(rawBody);
    const record = {
      auth_code: body.auth_code,
      code_verifier: body.code_verifier,
    };
    authRequests.push(record);

    if (body.auth_code === "qa251-invalid-code") {
      sendJson(response, 400, {
        code: "invalid_grant",
        error: "invalid_grant",
        error_description: "Synthetic invalid authorization code",
      });
      return;
    }

    if (
      body.auth_code === "qa251-valid-code" &&
      body.code_verifier === "fresh-verifier"
    ) {
      sendJson(response, 200, session);
      return;
    }

    sendJson(response, 400, {
      code: "invalid_grant",
      error: "invalid_grant",
      error_description: "Unexpected test authorization payload",
    });
    return;
  }

  sendJson(response, 404, { error: "NOT_FOUND" });
});

server.listen(54321, "127.0.0.1", () => {
  process.stdout.write("Mock Supabase Auth/PostgREST server listening on 127.0.0.1:54321\\n");
});

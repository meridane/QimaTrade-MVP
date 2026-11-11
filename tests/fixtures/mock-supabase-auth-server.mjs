import { createServer } from "node:http";

const authRequests = [];

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

function sendJson(response, status, body) {
  response.writeHead(status, {
    "content-type": "application/json",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(body));
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url ?? "/", "http://127.0.0.1:54321");

  if (request.method === "GET" && url.pathname === "/health") {
    response.writeHead(200, { "content-type": "text/plain" });
    response.end("ok");
    return;
  }

  if (request.method === "GET" && url.pathname === "/auth/v1/user") {
    if (request.headers.authorization !== `Bearer ${session.access_token}`) {
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
  process.stdout.write("Mock Supabase Auth server listening on 127.0.0.1:54321\\n");
});

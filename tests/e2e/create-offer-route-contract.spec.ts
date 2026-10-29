test("CREATE_OFFER route rejects missing or non-Bearer authorization before database access", async () => {
  for (const authorizationHeader of [null, "Basic invalid-token"]) {
    const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", authorizationHeader);

    expect(result.status, String(authorizationHeader)).toBe(401);
    expect(result.body, String(authorizationHeader)).toMatchObject({ error: "UNAUTHENTICATED" });
    expect(result.requests, String(authorizationHeader)).toEqual([]);
  }
});

test("CREATE_OFFER route accepts case-insensitive Bearer schemes", async () => {
  for (const authorizationHeader of ["bearer qima-route-test-token", "bEaReR qima-route-test-token"]) {
    const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", authorizationHeader);

    expect(result.status, authorizationHeader).toBe(200);
    expect(
      result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
      authorizationHeader,
    ).toBe(true);
  }
});
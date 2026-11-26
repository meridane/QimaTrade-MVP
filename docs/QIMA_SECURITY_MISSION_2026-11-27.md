# QimaTrade — security mission checkpoint

Date: 2026-11-27 (Asia/Seoul)

## Provenance

- Repository: `meridane/QimaTrade-MVP`
- PR under observation: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
- Verified source HEAD: `61002cb21aaa738a7f018794ab84bff41a2c6eb2`
- Mission branch: `work/qima-security-error-boundary-20261127-0441`
- Branch base: exact verified PR HEAD above

## Finding SEC-ROUTE-01 — product-request publish error boundary

Reviewed `app/api/product-requests/publish/route.ts` and `lib/actions/runtime.ts`.

The route's previous catch block returned `error.message` for unexpected failures. The runtime passes Supabase RPC error messages into thrown `Error` objects, so an upstream PostgREST/SQL diagnostic could cross the public HTTP boundary. The previous `message.includes(code)` check could also classify a longer diagnostic string as a public domain error and return that full string.

This is a **confirmed source-level error-disclosure path**. No live exploit, production response, or production vulnerability was tested or confirmed.

## Change on this isolated branch

1. Reject malformed JSON and non-object JSON bodies with stable HTTP 400 `INVALID_REQUEST_BODY` before authentication or database access.
2. Keep the existing required-`requestId` contract.
3. Expose only exact matches from the existing public domain-code allowlist.
4. Replace all other exception messages with the generic HTTP 500 response `Unable to publish product request.`.
5. Add Playwright coverage for malformed JSON, null/array/primitive bodies, non-string request IDs, and the source-level no-raw-error contract.

Files changed:
- `app/api/product-requests/publish/route.ts`
- `tests/e2e/product-request-publish-route-contract.spec.ts`

No SQL, migration, schema, RLS policy, grant, secret, or production setting was changed.

## Validation and evidence limits

- The parent PR HEAD's QIMA CI run #2036 is **SUCCESS**; CodeQL #1962 is **SUCCESS**; the combined Vercel status is **SUCCESS**.
- The new branch has not yet run CI. The new Playwright tests are **pending execution**; this connector session cannot execute the repository's local npm/Playwright commands.
- The canonical register is a 2.9 MB file. Its exact Git blob was readable, but the normal file reader returns an empty body. This append-only companion avoids replacing or truncating the canonical register.
- Existing security documentation records that live Supabase catalog verification is blocked by PostgreSQL authentication error `28P01`. That remains a separate production-evidence blocker; synthetic fixtures do not establish production ACL state.

## Risks and next step

- Confirmed: the old source returned unfiltered exception text from the publish route's catch block.
- Not confirmed: whether any production caller can trigger a particular sensitive database diagnostic, or whether a live production deployment contains this branch's route.
- Next: run the new Playwright file and the full relevant CI on this branch, review the exact diff, then compare this branch with the independent TESTS branch before any integration.

No Supabase Production data or migrations were touched. No Production deployment, PR merge, force-push, or branch-protection change was performed.

## Validation update — 2026-11-27

- QIMA CodeQL run [45891103720](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891103720): **SUCCESS** on the earlier security branch head.
- QIMA CI run [45891103428](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891103428): TypeScript, production build, dependency audit and the isolated QIMA security fixture passed; the Playwright step failed before executing this file because the source-reading test used an ESM-incompatible loader path (require is not defined). This was a test-harness failure, not a confirmed application vulnerability.
- The test now reads the route source using Node's built-in module access and the repository root path. Current branch head at this update: e4570b440b953819e3fca182a0e4d1a8e7f2ba9d.
- Revalidation: QIMA CI [45891442647](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891442647) is queued; CodeQL [45891442644](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891442644) is in progress.
- PostgreSQL 16 and 17.6 integration jobs from the earlier run remain in progress. Vercel Preview for the updated commit is blocked by the provider's 24-hour build-rate limit.
- The original code finding remains a confirmed source-level error-message exposure path in the prior implementation. No real-world exploitation or Production disclosure has been established.


# QIMA V1 Function Register — QA332

## QA332 — legacy offers INSERT RETURNING and SELECT-policy mechanics

**Statut : CLOSED — runtime validation complete in QIMA CI #1504 on code HEAD `8f73e671f49130a4d35e47551fc3d16ca0e3c2ba`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.

### Contract exercised

- Runtime file: `tests/sql/legacy-offer-returning-select-rls-regression.sql`.
- The SQL guard requires database `qima_test` and application name `qima-ci-legacy-offer-returning`; CI supplies the exact application name.
- The test applies the existing actor-bound INSERT policy inside an outer disposable transaction and first verifies that no SELECT policy exists.
- Under the authenticated role, an `INSERT ... RETURNING` probe must not expose a row without a SELECT policy. The probe is rolled back inside a nested block whether PostgreSQL rejects it or returns no visible row.
- A plain INSERT without RETURNING must still create one row. This characterizes the distinction between INSERT permission and row visibility required for RETURNING.
- The test then creates `qa332_offers_select_own_provider`, a deliberately synthetic, transaction-scoped SELECT policy that exposes rows only where `provider_actor_id = current_profile_actor_id()`. Two actors sharing one synthetic demand must each be able to INSERT ... RETURNING and SELECT their own rows, while seeing zero rows for the other actor.
- Final assertions require the two seed rows and two successful RETURNING rows; the outer transaction ends with `ROLLBACK`.

### Application call-site cross-check

- `lib/offers/create-legacy-offer.ts` generates the offer UUID before INSERT, passes that ID in the insert payload, and uses the preassigned ID for the redirect. The offers INSERT does not chain `.select()` or request a returned row.
- `tests/e2e/legacy-offers-route-contract.spec.ts` contains the regression “legacy offers route redirects to its preassigned UUID without INSERT RETURNING and preserves draft fields”; it checks the UUID, 303 redirect, and preserved draft fields.
- This is the route behavior characterized by QA332; it avoids making the redirect depend on SELECT visibility of the newly inserted row.

### CI wiring and final evidence

- `.github/workflows/ci.yml` runs this SQL file directly with `psql -v ON_ERROR_STOP=1` in both PostgreSQL 16 and PostgreSQL 17.6 jobs.
- QIMA CI [#1504](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799845) completed overall **SUCCESS** on code HEAD `8f73e671f49130a4d35e47551fc3d16ca0e3c2ba`.
- PostgreSQL 16 job `132936425918` and PostgreSQL 17.6 job `132936425732` each contain exactly one `QA332 legacy offers INSERT RETURNING and synthetic actor-scoped SELECT regression PASS; transaction rolled back` marker.
- Both versions confirmed that the no-SELECT-policy RETURNING probe exposes no row, plain INSERT succeeds, and the synthetic actor-scoped SELECT policy permits each actor to see only its own rows.
- Verify job `132936425981` completed SUCCESS; TypeScript, Next.js build, configured npm audit gate, and Playwright **347 passed**.
- CodeQL [#1438](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799934) completed SUCCESS; Vercel status on code HEAD `8f73e671` was success.
- CI [#1505](https://github.com/meridane/QimaTrade-MVP/actions/runs/43755496218) and CodeQL [#1439](https://github.com/meridane/QimaTrade-MVP/actions/runs/43755496181) are the subsequent checks for documentation HEAD `0d5f7c89`; #1505 is still in progress at this note.

### Scope and limitations

- The synthetic SELECT policy is a mechanics fixture only. It is not a proposed or approved production SELECT policy and does not define supplier/buyer conversation visibility.
- The test runs only on the guarded disposable `qima_test` database and rolls back its policy, grants, and rows.
- It does not establish the live Supabase Production RLS state or prove a Production vulnerability.
- No production data/migration, secret, grant, policy, persistent configuration, production deployment, merge, force-push, or protection rule is changed.
### Final runtime validation — QIMA CI #1504 (16 novembre 2026 KST)

- QA332 is **CLOSED** on code HEAD `8f73e671f49130a4d35e47551fc3d16ca0e3c2ba`. QIMA CI [#1504](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799845) completed with overall **SUCCESS**.
- PostgreSQL 16 job `132936425918` contains exactly one marker: `QA332 legacy offers INSERT RETURNING and synthetic actor-scoped SELECT regression PASS; transaction rolled back`.
- PostgreSQL 17.6 job `132936425732` contains exactly one identical QA332 PASS marker.
- In both versions, the no-SELECT-policy RETURNING probe exposed no row, plain INSERT succeeded, and the transaction-scoped synthetic actor policy allowed each actor to read only its own rows. Both outer transactions rolled back.
- Verify job `132936425981` completed **SUCCESS**, including the configured npm audit gate, TypeScript, Next.js production build and Playwright **347 passed**.
- CodeQL [#1438](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799934) completed **SUCCESS**; the combined Vercel status on code HEAD `8f73e671` was **success**.
- QIMA CI [#1505](https://github.com/meridane/QimaTrade-MVP/actions/runs/43755496218) and CodeQL [#1439](https://github.com/meridane/QimaTrade-MVP/actions/runs/43755496181) are the subsequent checks for documentation HEAD `0d5f7c89`; #1505 is still in progress at the time of this note. No result from #1505 is inferred here.
- The synthetic SELECT policy remains a test-only mechanics fixture. It does not define the live supplier/buyer visibility policy or establish the Production RLS state.


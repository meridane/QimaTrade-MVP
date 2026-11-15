# QIMA V1 Function Register — QA330 / QA331

## QA330 — legacy offers INSERT RLS binds provider actor to the authenticated profile

**Statut : IMPLEMENTED — runtime validation pending in QIMA CI #1504 on HEAD `8f73e671f49130a4d35e47551fc3d16ca0e3c2ba`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.

### Contract exercised

- Runtime file: `tests/sql/legacy-offer-insert-rls-regression.sql`.
- The SQL guard requires database `qima_test` and application name `qima-ci-legacy-offer-rls`; the CI workflow supplies that exact application name.
- The test enables RLS on `public.offers`, grants only the INSERT privilege needed by the authenticated test role, and applies the repository migration `supabase/migrations/20260829130000_fix_offers_insert_rls_actor_lookup.sql` inside the surrounding disposable transaction.
- The policy preflight requires the existing `offers_insert_own_provider` INSERT policy for `authenticated`, with a check binding non-NULL `provider_actor_id` to `public.current_profile_actor_id()`.
- Two synthetic authenticated users are mapped to distinct profile actor IDs. Each actor can insert its own provider ID; an actor cannot insert the other actor's ID; a NULL provider actor is rejected.
- Final assertions require exactly two allowed rows and zero rows from the cross-actor/NULL attempts. The outer transaction ends with `ROLLBACK`.

### QA331 — fixture ACL boundary

QA331 is an invariant block inside the same QA330 SQL file, not a separate runtime script.

- The fixture must preserve authenticated SELECT/INSERT needed by the reviewed legacy call sites and the QA330 INSERT test.
- It rejects authenticated UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER and column-level UPDATE.
- It requires anon to have no table or column UPDATE privileges and requires the fixture to contain only the single QA330 INSERT policy, with no SELECT/UPDATE/DELETE/ALL policy.
- These assertions describe the disposable fixture's intended privilege shape; they do not report the live Supabase ACL state.

### CI wiring and current evidence

- `.github/workflows/ci.yml` runs this SQL file directly with `psql -v ON_ERROR_STOP=1` in both the PostgreSQL 16 and PostgreSQL 17.6 jobs.
- QIMA CI [#1504](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799845) is still in progress on HEAD `8f73e671`. Verify job `132936425981` completed SUCCESS; its log confirms the QA373–QA381 static contract, the configured npm-audit gate, TypeScript, Next.js build, and Playwright **347 passed**.
- PostgreSQL 16 job `132936425918` and PostgreSQL 17.6 job `132936425732` are still in progress at the preceding full CREATE_OFFER runner write-privilege characterization step. The QA330 step has not started in either job; no QA330 runtime pass is claimed.
- CodeQL [#1438](https://github.com/meridane/QimaTrade-MVP/actions/runs/43754799934) completed SUCCESS. The combined Vercel status on this HEAD is success.

### Scope and limitations

- The migration is read from the repository and applied only inside the disposable `qima_test` transaction, which is rolled back.
- The test characterizes the repository migration and synthetic actor/profile fixtures. It does not inspect or change Supabase Production data, migrations, grants, or RLS policies.
- It is not a production vulnerability finding and does not establish the live Production policy state.
- No production deployment, merge, force-push, or branch-protection change.

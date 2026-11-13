# QA379 — indirect SET membership chain boundaries

## Scope

Characterize PostgreSQL's documented transitive SET ROLE semantics for the non-superuser CREATE_OFFER integration runner. The positive case uses a NOLOGIN bridge role. The negative case keeps the bridge-to-client edges SET-enabled but changes the runner-to-bridge edge to SET FALSE.

## Positive runtime setup

- Disposable PostgreSQL 16 and 17.6 containers only.
- Create qa379_indirect_bridge as NOLOGIN NOINHERIT.
- Create qa379_indirect_runner as LOGIN, CREATEROLE, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS and owner of qima_test.
- Grant anon and authenticated to the bridge with ADMIN FALSE, INHERIT FALSE, SET TRUE.
- Grant the bridge to the runner with ADMIN FALSE, INHERIT FALSE, SET TRUE.
- Assert pg_has_role(..., 'SET') is true for the bridge and both client roles, while direct runner-to-anon and runner-to-authenticated membership rows are absent.
- Invoke the real run-create-offer-integration.sh using the loopback-only qima_test URL.
- Explicitly execute SET ROLE anon and SET ROLE authenticated in a runner-authenticated psql session after the full runner completes.

## Positive expected result

The read-only runner guard accepts the transitive SET-enabled chain. The fixture does not create redundant direct memberships for anon or authenticated. The full fixture, migrations, SECURITY DEFINER checks, and same-tenant advisory-lock concurrency observation complete successfully. The final state retains the bridge path, both client roles remain non-members of the runner, and no direct target memberships are added.

## Negative runtime setup

- Recreate qima_test as an empty database owned by qa379_blocked_runner, a non-superuser LOGIN role with CREATEROLE and NOINHERIT.
- Grant anon and authenticated to qa379_blocked_bridge with SET TRUE.
- Grant the bridge to qa379_blocked_runner with ADMIN FALSE, INHERIT FALSE, SET FALSE.
- Assert the runner is a member of the bridge but cannot SET ROLE to the bridge or either client role.
- Run the real runner and require exit code 4 before fixture DDL/DML.
- Compare an empty-database/catalog/ownership/role/membership snapshot before and after the rejection.

## Interpretation and safety

PostgreSQL 16 documentation states that indirect SET ROLE is allowed only when every edge in the membership chain has SET TRUE; this test verifies that behavior against the pinned PostgreSQL 16 and 17.6 runtime versions. This is a synthetic characterization, not evidence that a Production runner has this role configuration.

All roles, memberships, databases, fixtures, migrations, and temporary files are confined to disposable Docker PostgreSQL containers. The EXIT trap removes the container and temporary files. No Supabase Production data, credentials, migrations, persistent PostgreSQL settings, remote publisher, or branch-protection configuration is accessed or modified.

## QA379 code-validation evidence

- QIMA CI [#1372](https://github.com/meridane/QimaTrade-MVP/actions/runs/43337660012): PostgreSQL 16 and PostgreSQL 17.6 runtime jobs succeeded, but Verify failed because the static contract expected a level-two heading while this standalone appendix correctly uses a level-one title. The audit-enforcement step then failed because the audit was skipped; npm audit, TypeScript, Next.js build, and Playwright did not run in that Verify job. No dependency-vulnerability conclusion is implied.
- The static contract was corrected in commit [215c25e](https://github.com/meridane/QimaTrade-MVP/commit/215c25e1f865d71d8a14d6e9f95330d9ac41e6d3) to check the exact level-one appendix title.
- QIMA CI [#1373](https://github.com/meridane/QimaTrade-MVP/actions/runs/43345563566): **SUCCESS**. PostgreSQL 16 and 17.6 emitted both explicit QA379 markers. Verify passed the static contract, high-threshold npm audit, TypeScript, Next.js build, Chromium installation, and 347 Playwright tests.
- CodeQL [#1322](https://github.com/meridane/QimaTrade-MVP/actions/runs/43345563717): **SUCCESS** on the final code HEAD.
- Vercel Preview checks: **SUCCESS**. Preview only; no Production deployment.

## QA379 CodeQL evidence

- CodeQL [#1321](https://github.com/meridane/QimaTrade-MVP/actions/runs/43337660127): **SUCCESS** on the preceding code HEAD.
- CodeQL [#1322](https://github.com/meridane/QimaTrade-MVP/actions/runs/43345563717): **SUCCESS** on the corrected code HEAD.

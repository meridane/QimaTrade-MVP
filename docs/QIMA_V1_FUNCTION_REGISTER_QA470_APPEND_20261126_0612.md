# QIMA V1 Function Register — QA470 append (2026-11-26)

## Scope

QA470 adds positive compatibility coverage for the exact disposable PostgreSQL URL allowlist in `tests/sql/restore-prepared-transactions-config.sh`. It does not change the restore script or connect to a real database.

The runtime harness now tests all six combinations accepted by the existing guard:

| Scheme | Host | Expected |
|---|---|---|
| `postgresql://` | `localhost` | accepted |
| `postgres://` | `localhost` | accepted |
| `postgresql://` | `127.0.0.1` | accepted |
| `postgres://` | `127.0.0.1` | accepted |
| `postgresql://` | `[::1]` | accepted |
| `postgres://` | `[::1]` | accepted |

The mock `psql` receives `MOCK_PSQL_EXPECTED_URL` and rejects any URL that differs from the case under test. Docker, readiness, reset, restart, and postcondition calls remain inert mocks.

## CI evidence and correction

- CI run [#1988](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702507061), commit `09b8cf07e659dd847e9e6687fa39bf1ebe3eb04b): the dedicated runtime job printed the QA470 success marker for all six URL forms.
- The Verify job then failed in `test-prepared-transactions-harness-isolation.sh`: the newly appended positive restore cases correctly ended with mock state `0`, but they contaminated the enclosing QA355 sentinel, which expected its initial state `10` after the later no-mutation checks. This was a test-harness isolation failure, not a production database finding.
- Commit `02de49936fab149a431d94e20a3b4ccbd7c3ba03` captures the initial QA470 state and restores it after the six cases.
- Commit `af38ee93399f2be069d178f19da68b0de0577cb5` corrects the state-restore `printf` escape.
- Corrected CI run [#1989](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702685944) is queued behind the still-running prior PR workflow. Its result is pending.
- CodeQL run [#1989](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702685865) is in progress; initialization and autobuild have passed, analysis is still running.
- The Vercel check suite for the corrected head was queued at the last inspection; no new Preview result is confirmed.

## Files and commits

Code file: `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`.

QA470 commit sequence:
- `12cea60f790b5591223d2c198b719ae394e11e1e` — add six supported-loopback cases and parameterize the psql mock URL.
- `09b8cf07e659dd847e9e6687fa39bf1ebe3eb04b` — correct the initial QA470 shell escaping.
- `02de49936fab149a431d94e20a3b4ccbd7c3ba03` — preserve the enclosing runtime harness state.
- `af38ee93399f2be069d178f19da68b0de0577cb5` — correct the state-restore printf escape.

## Safety and interpretation

All QA470 database and Docker interactions use CI mocks. The six success-path checks establish only that the current URL allowlist accepts and forwards these forms unchanged in the mocked restore contract. They are not evidence of a production vulnerability or of a real network connection.

No Supabase production data, production migrations, production secrets, persistent grants, RLS policies, production deployment, PR merge, or branch-protection settings were changed.

## Next action

Wait for CI #1989 and CodeQL #1989. Confirm that QA355 harness isolation passes with the original state restored, then record the final PostgreSQL 16/17.6 and Verify results. Keep the PR open and unmerged.

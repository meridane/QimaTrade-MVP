# QIMA QUALITY — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-quality-review-20261127-0441`
- Tested code head: `688b563b1fe044bfba9c4d7d93fdd6f18588f4a2`
- Mission PR: [#30](https://github.com/meridane/QimaTrade-MVP/pull/30), OPEN / DRAFT.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New accessibility regression
- File: `tests/e2e/offer-creation-confirmation.spec.ts`.
- Commit: `688b563b1fe044bfba9c4d7d93fdd6f18588f4a2`.
- The existing generic PostgREST submission-failure test now resolves the message through the accessible `alert` role, asserts its exact generic text and requires `aria-live="assertive"`.
- No production component behavior was changed.

## Validation
- Previous snapshot `864c4df6`: QIMA CI [run 46094839888](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094839888) SUCCESS, 441 Playwright tests, PostgreSQL 16 and 17.6 SUCCESS; CodeQL [run 46094839871](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094839871) SUCCESS.
- Current QIMA CI [run 46098398812](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098398812): IN PROGRESS; Verify and PostgreSQL 16/17.6 jobs active.
- CodeQL [run 46098398780](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098398780): IN PROGRESS.
- Vercel status for the current branch snapshot reports the external `build-rate-limit` failure.

## Interpretation
This asserts the existing error announcement semantics in a browser test. It is not a full WCAG or screen-reader certification.

## Next step
Verify the new `aria-live` assertion in the browser test, then complete PostgreSQL 16/17.6 and CodeQL checks.


## First Verify attempt and selector correction
- QIMA CI [run 46098398812](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098398812), code head `688b563b`: npm audit, TypeScript and production build passed, but Playwright failed in the existing submission-error test because `getByRole("alert")` matched both the form's alert paragraph and Next.js's route-announcer alert.
- This was a strict-mode ambiguity in the test locator, not an application behavior failure.
- Corrected in commit [`2d196854`](https://github.com/meridane/QimaTrade-MVP/commit/2d196854266a1f821b55374b53948a5a233e528f): scope the locator to `p[role="alert"]`, then assert the exact generic message and `aria-live="assertive"`.
- Replacement QIMA CI [run 46098624833](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098624833) is PENDING with no jobs published at the latest read; no passing Playwright result is claimed for the correction yet.
- CodeQL [run 46098398780](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098398780) for the first code head completed SUCCESS; CodeQL for the corrected head [run 46098624871](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098624871) is IN PROGRESS.

 
## Keyboard submission of generic error state — 2026-11-28

- Changed the existing PostgREST draft-insert failure regression to submit the form with Enter instead of a mouse click, while retaining the generic p[role=alert] text and aria-live=assertive assertions.
- Commit: https://github.com/meridane/QimaTrade-MVP/commit/d5cb6758377cd9a7f0e92efb582499320e4f9727.
- Previous corrected code head 2d196854 is fully validated by QIMA CI #46098624833: 441 Playwright passed, including the scoped alert selector; Verify succeeded; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 succeeded. CodeQL #46098624871 succeeded.
- No QIMA CI or CodeQL run was visible for new head d5cb6758 at this checkpoint. The workflow is configured for push to main, pull requests targeting main, schedule and workflow_dispatch; this mission PR targets the temporary validation base. The new Enter-submission case remains unvalidated pending an authorized CI trigger.
- This is a keyboard interaction regression, not a complete WCAG or screen-reader certification. No application runtime or Production data was changed.

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
- CI run [#1989](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702685944) was cancelled after the PR head advanced to the append-only register update; no test result is attributed to that run.
- CodeQL run [#1915](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702685865) for the corrected code head `af38ee93` completed successfully.
- CodeQL run [#1916](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702873026) for the current register head is in progress; initialization and autobuild passed, analysis is still running.
- Corrected CI run [#1990](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702873168) is pending behind the still-running prior PR workflow.
- CI run [#1988](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702507061) remains in progress. Its Verify job failed only at the QA355 outer-state assertion; the PostgreSQL 16 and 17.6 jobs were still at runner write-privilege characterization when last inspected.
- The Vercel combined status currently reports `build-rate-limit`; this is a provider/quota status, not evidence of an application compilation failure. No successful Preview for the current head is confirmed.

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


---

## Clôture QA470 — CI #1991 et isolation QA355 confirmées — 26 novembre 2026 (KST)

### État GitHub relu avant actualisation

- PR #26 « fix: align CREATE_OFFER execution statuses » : **OPEN / DRAFT / non fusionnée**, merged=false, mergeable=true.
- Branche officielle : fix/create-offer-status-contract, base main.
- HEAD avant cette actualisation : f3a235a8c4772e2314dfa615ed7e7471cf61cedd ; base SHA : 0d35c13db81019867fe9929420b0a6916285fbf6.
- Comparaison main...fix/create-offer-status-contract : **2 514 commits en avance, 0 en retard** ; 308 fichiers modifiés (97 187 insertions / 266 suppressions).
- Dernier commit relu : f3a235a8, documentaire uniquement, actualisant le supplément QA470. La branche de travail work/qima-restore-loopback-url-allowlist-qa470-20261126-0612 était identique à la branche PR (0 ahead / 0 behind).

### Résultat définitif de QA470

- Les six formes explicitement autorisées ont été exécutées dans le job runtime de QIMA CI [#1991](https://github.com/meridane/QimaTrade-MVP/actions/runs/45703051885). Le journal contient le marqueur exact : QA470 supported-loopback URL allowlist passed: postgres/postgresql schemes with localhost, IPv4 loopback, and IPv6 loopback completed the mocked restoration sequence; psql received each URL unchanged.
- La régression d'isolation QA355 qui avait fait échouer Verify dans CI [#1988](https://github.com/meridane/QimaTrade-MVP/actions/runs/45702507061) est corrigée par la capture puis la restauration de l'état initial du harness. Dans #1991, le journal Verify confirme : QA355 passed ; l'état sentinelle 10 est préservé après les cas QA470.
- QIMA CI [#1991](https://github.com/meridane/QimaTrade-MVP/actions/runs/45703051885) a terminé **SUCCESS**. Verify : npm audit **0 vulnérabilité (total 0)**, TypeScript, build Next.js, Chromium, fixture de sécurité QIMA et **423/423 Playwright (37,6 s)** réussis.
- PostgreSQL 16 integration et PostgreSQL 17.6 compatibility ont tous deux terminé **SUCCESS**. Le nettoyage prepared-transactions et ses postconditions ont passé.
- CodeQL [#1917](https://github.com/meridane/QimaTrade-MVP/actions/runs/45703051888) a terminé **SUCCESS**.
- Les jobs de simulation setup/cleanup terminent volontairement avec les codes injectés 47 et 52 ; leurs assertions bloquantes dédiées ont **SUCCESS**. Le job skipped reste intentionnellement **SKIPPED**. Ces résultats ne sont pas des échecs inattendus du workflow.

### Vercel — statut distinct

- Le statut combiné du HEAD exact f3a235a8 rapporte Vercel **FAILURE** avec la cible upgradeToPro=build-rate-limit. Il s'agit d'une limite de quota du fournisseur, pas d'un échec de compilation démontré.
- Aucun Preview réussi pour ce HEAD exact n'est confirmé dans les checks récupérés. Un commentaire Vercel antérieur signalant un déploiement Ready concernait un déploiement plus ancien et n'est pas utilisé comme preuve pour ce SHA.

### Commits et fichiers QA470

- 12cea60f — six cas positifs d'allowlist loopback et mock psql paramétré.
- 09b8cf07 — correction de l'échappement shell initial.
- 02de4993 — capture/restauration de l'état extérieur QA355.
- af38ee93 — correction de l'échappement printf.
- 3fb8cf44 et f3a235a8 — snapshots documentaires QA470.
- Code modifié : tests/ci/test-prepared-transactions-always-cleanup-runtime.sh.
- Documentation complémentaire : docs/QIMA_V1_FUNCTION_REGISTER_QA470_APPEND_20261126_0612.md.

### Décisions API/métier qui restent ouvertes

Les points ci-dessous ne sont pas approuvés et ne doivent pas être figés par de nouveaux tests normatifs ni par des changements SQL :
- grammaire exacte des chaînes numériques CREATE_OFFER ;
- types acceptés pour les champs métier facultatifs ;
- source officielle de correlationId ;
- sémantique objectType/objectId ;
- caractère obligatoire ou facultatif de idempotencyKey côté client ;
- MKT-1.3 numeric canonicalization, toujours **CHARACTERIZATION / DECISION REQUIRED — NOT APPROVED**.

### Prochaine étape non bloquante

- Ne pas ajouter une nouvelle matrice synthétique redondante au script de restauration après la clôture QA470.
- Continuer la revue indépendante des tests/contrats CREATE_OFFER et des frontières HTTP qui ne figent pas les décisions ci-dessus ; documenter tout point qui exige une approbation produit/API.
- Réexaminer le statut Vercel uniquement lorsque le quota fournisseur le permet.
- Conserver les checks liés au SHA exact et mettre à jour le registre après chaque changement.

### Sécurité et interprétation

- Les cas QA470 utilisent des mocks inertes et caractérisent uniquement le contrat du script CI de restauration. Ils ne démontrent pas une vulnérabilité exploitable en Production.
- Aucun test local n'est revendiqué.
- Aucune donnée ou migration Supabase Production, aucun secret, grant ou policy RLS persistante, aucune configuration PostgreSQL Production, aucun déploiement Production, merge, force-push ou changement des protections GitHub n'a été effectué.

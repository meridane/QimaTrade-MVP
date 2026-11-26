# QIMA V1 Function Register — QA427

## QA427 — exact replay of an omitted geography default across committed PostgreSQL sessions

**Statut : CLOSED — validation complète confirmée par QIMA CI #1491 sur le HEAD `3239f1643b5203991c8f2f08ce9fd6c34f8a8b14`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `e2a2d12d72f82fd13e35fe5df63be4415d651d57`.  
**Branche de travail :** `work/qa427-geography-default-committed-replay-20261115-1951`.

## Constat et portée
- Le scénario QA413 vérifie déjà qu'un appel qui omet `p_geography` peut être rejoué avec `p_geography => NULL`, et qu'il conserve le hash, le résultat, l'offre et l'événement.
- Dans `create-offer-geography-default-replay.sql`, les deux appels sont toutefois contenus dans un même bloc `DO`. Ce scénario ne démontre donc pas à lui seul que la ligne d'idempotence validée par COMMIT est retrouvée depuis une nouvelle connexion PostgreSQL.
- QA427 ajoute `tests/sql/run-create-offer-geography-default-committed-replay.sh`. Le premier processus psql crée l'offre en omettant `p_geography`, vérifie les quatre tables et termine par COMMIT. Un second processus psql, avec un `application_name` distinct, rejoue exactement les mêmes paramètres métier en fournissant explicitement NULL.
- Le second processus vérifie que le hash, le résultat JSON, l'exécution, l'offre et l'événement originaux sont inchangés, et que les comptes des quatre tables restent identiques à 1.
- Le runner refuse toute `DATABASE_URL` autre que `postgresql://postgres:postgres@localhost:5432/qima_test`, l'URL loopback jetable déclarée dans les deux jobs CI. Aucun environnement Supabase distant ou production n'est accepté.
- `tests/sql/test-create-offer-geography-default-committed-replay-contract.sh` vérifie les deux processus psql, les BEGIN/COMMIT explicites, les noms de session distincts, l'omission du paramètre dans le premier appel, le NULL explicite dans le second, l'identité des autres paramètres et l'absence de DML direct.
- Le contrôle statique est intégré au job Verify. Le runner runtime est intégré après QA413 et avant le repeat-run guard dans PostgreSQL 16 et PostgreSQL 17.6.
- Aucun changement de migration, de fonction, de règle métier ou de données persistantes n'est nécessaire.

## Validation initiale
- La validation de départ du HEAD `e2a2d12d72f82fd13e35fe5df63be4415d651d57` est QIMA CI [#1488](https://github.com/meridane/QimaTrade-MVP/actions/runs/43698923008) : SUCCESS. Le job Verify, PostgreSQL 16, PostgreSQL 17.6, npm audit, TypeScript, build Next.js et Playwright 347/347 ont réussi. Les journaux Verify contiennent exactement un marqueur QA426 statique et un marqueur QA413 statique ; les journaux PostgreSQL contiennent exactement un marqueur QA413 runtime chacun.
- CodeQL [#1423](https://github.com/meridane/QimaTrade-MVP/actions/runs/43698923016) : SUCCESS.
- Vercel sur le HEAD de base : SUCCESS.
- À ce stade initial, QA427 était IMPLEMENTED mais non encore validé en runtime ; les preuves définitives sont consignées dans la section de clôture ci-dessous.

## Sécurité et limites
- Le runner n'émet aucun INSERT, UPDATE, DELETE, DDL, GRANT ou REVOKE direct ; toute écriture applicative passe par `execute_create_offer_v1` sur la base PostgreSQL jetable de CI.
- Aucun SQL de migration, aucune donnée Supabase Production, aucun secret, grant, policy RLS ou configuration PostgreSQL persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- QA427 est un test de contrat de replay inter-session ; il ne constitue pas un constat de vulnérabilité ni une preuve de comportement de la fonction basse couche sur le projet Supabase Production.

- Pre-CI review corrected the shell parameter-expansion guard to use the actual required-variable expansion; the static contract now protects that exact guard.

## First CI attempt and correction
- QIMA CI [#1489](https://github.com/meridane/QimaTrade-MVP/actions/runs/43706451155), HEAD `615d63fe5f81504dc9bc253dbccccdb9f955a913`: the PostgreSQL 16 and PostgreSQL 17.6 QA427 runtime steps both completed SUCCESS. Verify failed only because the static contract incorrectly expected the fixture-key string at least four times; the key is declared exactly twice, while the request-input case string is separate. This was a test assertion defect, not a runtime SQL failure or a vulnerability finding.
- The static assertion was corrected to require exactly two matching key declarations and exactly two matching request-input and offer-name declarations. The corrected required-DATABASE_URL guard is also protected by the static contract.
- QIMA CI [#1490](https://github.com/meridane/QimaTrade-MVP/actions/runs/43706557817) was queued on the intermediate HEAD `f2dd8d85f4f4b64a2c6fabe2d0b5647c0c0a6a4d`, before this fixture-count correction; it is not evidence for the corrected static contract.


## Final validation — QIMA CI #1491

- QIMA CI [#1491](https://github.com/meridane/QimaTrade-MVP/actions/runs/43706667678) completed **SUCCESS** on the exact PR HEAD `3239f1643b5203991c8f2f08ce9fd6c34f8a8b14`.
- Verify job `132790231211`: **SUCCESS**. The full log contains exactly one `QA427 static contract PASS` marker. Dependency audit at the high threshold, TypeScript, Next.js production build, Chromium installation and Playwright **347/347** all succeeded.
- PostgreSQL 16 job `132790231298`: **SUCCESS**. The full log contains exactly one `QA427 FIRST COMMITTED SESSION PASS` marker (backend PID `390`) and exactly one `QA427 PASS` marker (backend PID `391`). The different backend PIDs confirm the two committed calls used distinct PostgreSQL sessions.
- PostgreSQL 17.6 job `132790231234`: **SUCCESS**. The full log contains exactly one `QA427 FIRST COMMITTED SESSION PASS` marker (backend PID `366`) and exactly one `QA427 PASS` marker (backend PID `367`), again confirming distinct sessions.
- CodeQL [#1426](https://github.com/meridane/QimaTrade-MVP/actions/runs/43706667642): **SUCCESS**. The combined Vercel status on the validated HEAD is **SUCCESS**.
- The two prepared-transaction simulation jobs `132790231063` and `132790231228` intentionally concluded FAILURE to exercise expected setup/cleanup failure paths; their dedicated assertion jobs `132790231419`, `132790255473` and `132790260107` succeeded. The deliberately skipped cleanup job `132790232189` was SKIPPED and its assertion passed. The overall QIMA CI conclusion remains SUCCESS.
- QA427 is therefore **CLOSED** for the documented test scope: committed omitted-geography creation followed by exact explicit-NULL replay from a distinct PostgreSQL session, with unchanged idempotency hash/result and one row in each of the four persistence tables, on PostgreSQL 16 and 17.6.
- This is disposable-fixture regression evidence only; it is not a production Supabase runtime assessment and does not establish a vulnerability.
- No production data, migration, secret, grant, RLS policy, persistent database configuration, production deployment, merge, force-push or protection-rule change.

# QIMA V1 Function Register — QA427

## QA427 — exact replay of an omitted geography default across committed PostgreSQL sessions

**Statut : IMPLEMENTED — validation CI runtime en attente.**  
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
- QA427 est IMPLEMENTED ; aucun marqueur runtime QA427 n'est revendiqué avant l'exécution de la nouvelle CI.

## Sécurité et limites
- Le runner n'émet aucun INSERT, UPDATE, DELETE, DDL, GRANT ou REVOKE direct ; toute écriture applicative passe par `execute_create_offer_v1` sur la base PostgreSQL jetable de CI.
- Aucun SQL de migration, aucune donnée Supabase Production, aucun secret, grant, policy RLS ou configuration PostgreSQL persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- QA427 est un test de contrat de replay inter-session ; il ne constitue pas un constat de vulnérabilité ni une preuve de comportement de la fonction basse couche sur le projet Supabase Production.

- Pre-CI review corrected the shell parameter-expansion guard to use the actual required-variable expansion; the static contract now protects that exact guard.

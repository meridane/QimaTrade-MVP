# QIMA V1 Function Register — QA428

## QA428 — concurrent successful first request wins; queued changed-payload retry is rejected

**Statut : IMPLEMENTED — validation runtime en attente sur la CI du HEAD courant.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `9d911be0eea79c568491ac9aeb89736e7c184507`.  
**Branche de travail :** `work/qa428-concurrent-success-mismatch-20261115-2139`.

## Constat et portée

- QA104 couvre déjà un cas concurrent où le premier appel détient le verrou puis échoue volontairement avant l'insertion de l'offre ; le second payload en attente devient alors le gagnant.
- Les tests de replay couvrent aussi le rejet séquentiel d'un payload modifié après une réussite.
- Il manquait le cas complémentaire où le premier payload termine avec succès et COMMIT, tandis qu'un deuxième payload différent attend sur le même verrou tenant/clé.
- QA428 ajoute ce scénario dans `tests/sql/run-create-offer-integration.sh`, déjà exécuté par les jobs PostgreSQL 16 et PostgreSQL 17.6.
- La première requête utilise le prix 23 et la seconde le prix 24 ; tous les autres paramètres métier, le tenant et la clé d'idempotence sont identiques.
- Le test observe le premier backend pendant le délai fixture avec le verrou advisory accordé, puis observe le second backend en attente du même verrou. Après le COMMIT du premier appel, le second doit échouer avec `IDEMPOTENCY_KEY_REUSE`.
- Le replay du premier payload doit restituer exactement le résultat original. Le replay du second payload doit rester rejeté.
- Les assertions SQL vérifient le hash gagnant, le résultat persistant, un seul enregistrement dans chacune des tables `idempotency_keys`, `action_executions`, `offers` et `action_events`, et l'absence d'offre au prix perdant.

## Contrôles et intégration

- Nouveau contrôle statique : `tests/sql/test-create-offer-concurrent-success-mismatch-contract.sh`.
- Le contrôle statique est intégré au job Verify.
- Le scénario runtime est exécuté par le runner commun dans PostgreSQL 16 et PostgreSQL 17.6.
- La validation de ce nouveau HEAD reste en attente de GitHub Actions ; aucun résultat runtime n'est revendiqué avant lecture des journaux correspondants.

## Sécurité et limites

- Le scénario utilise uniquement la base PostgreSQL jetable `qima_test` du runner existant, qui refuse les URL non-loopback avant toute connexion ou écriture de fixture.
- Le nouveau bloc n'émet aucun DML direct : les écritures applicatives passent uniquement par `execute_create_offer_v1`; les assertions sont en lecture seule.
- Aucun changement de fonction, migration, règle métier, privilège, grant, policy RLS ou donnée persistante.
- Il s'agit d'une régression de concurrence/idempotence sur fixture synthétique, pas d'un constat de vulnérabilité ni d'une évaluation de Supabase Production.
- Aucun déploiement Production, merge, force-push ou changement des règles de protection.


## First CI attempt and static-contract correction

- QIMA CI [#1493](https://github.com/meridane/QimaTrade-MVP/actions/runs/43715598192) started on HEAD `f57de87354b98ae5c3aeb374f9538955b61b374b`. Verify job `132816329767` failed at the new QA428 static contract because three required strings omitted the quoted Bash variable expansions used by the runner. The runner itself contains the intended lock snapshots and exit-status checks; this was a static assertion mismatch.
- The dependency-audit enforcement step also concluded FAILURE because the audit step was skipped after Verify stopped at QA428. No npm audit result was produced by that job; this is not an npm vulnerability finding.
- The static contract has been corrected to match the exact `[[ "$variable" ... ]]` expressions. The replacement CI must pass Verify before QA428 is considered validated.
- PostgreSQL 16 and PostgreSQL 17.6 jobs from #1493 were still running when this correction was prepared; their final runtime results are not inferred here.

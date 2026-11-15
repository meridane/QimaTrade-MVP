# QIMA V1 Function Register — QA428

## QA428 — concurrent successful first request wins; queued changed-payload retry is rejected

**Statut : CLOSED — QIMA CI #1494 SUCCESS sur le HEAD exact b17dc3ac672d0ef54ea8d38a16197d19dc5e83b0.**  
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
- L'attente initiale est levée par la validation finale QIMA CI #1494, détaillée ci-dessous.

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


## Validation finale — QIMA CI #1494 (2026-11-15)

- QA428 est **CLOSED** sur le HEAD exact de la PR b17dc3ac672d0ef54ea8d38a16197d19dc5e83b0. QIMA CI [#1494](https://github.com/meridane/QimaTrade-MVP/actions/runs/43715751146) a terminé avec la conclusion globale **SUCCESS**.
- Verify job 132818238544 : SUCCESS ; exactement un marqueur QA428 static contract PASS. npm audit au seuil high, TypeScript, build Next.js, installation Chromium et Playwright **347/347** : SUCCESS.
- PostgreSQL 16 job 132818238527 : SUCCESS ; exactement un marqueur QA428 PASS.
- PostgreSQL 17.6 job 132818238555 : SUCCESS ; exactement un marqueur QA428 PASS.
- Les deux environnements ont observé la requête initiale tenant/clé détentrice du verrou et la requête à prix modifié en attente ; la première a commité, la seconde et son replay ont été rejetés avec IDEMPOTENCY_KEY_REUSE. Une seule ligne d'idempotence, exécution, offre et événement de succès a été conservée.
- CodeQL [#1429](https://github.com/meridane/QimaTrade-MVP/actions/runs/43715751139) : SUCCESS. Le statut combiné Vercel sur le HEAD validé : SUCCESS.
- Les jobs de simulation négative préparée 132818238337 et 132818238620 ont la conclusion failure attendue ; les assertions de nettoyage 132818272062 et 132818286874 sont SUCCESS. Le job volontairement skipped 132818239596 est accompagné de son assertion SUCCESS 132818238648. La conclusion globale CI #1494 reste SUCCESS.
- Les deux échecs attendus de simulation ne sont pas des échecs de QA428 ni des constats de vulnérabilité.
- Portée limitée aux fixtures PostgreSQL jetables de CI. Aucun résultat n'est extrapolé à Supabase Production. Aucune donnée/migration production, secret, grant, policy RLS, configuration persistante, production deployment, merge, force-push ou règle de protection n'a été modifié.

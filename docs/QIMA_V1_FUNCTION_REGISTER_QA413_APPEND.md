# QIMA V1 Function Register — QA413

## QA413 — omission de p_geography et replay avec NULL explicite

**Statut : IMPLEMENTED — validation GitHub Actions en attente sur le nouveau HEAD.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa413-geography-default-replay-20261115-0233`.
**Commit de base :** `0543731c297b1925956bcda3286ea5d44741e2b8`.

## Portée

- Caractériser la signature existante `p_geography text DEFAULT NULL::text` sans modifier la migration.
- Le premier appel CREATE_OFFER de la fixture PostgreSQL jetable omet réellement l'argument nommé `p_geography`.
- Les deux appels fournissent explicitement `p_market => NULL` et conservent identiques tous les autres paramètres effectifs.
- Le replay avec le même tenant et la même clé fournit explicitement `p_geography => NULL`.
- Exiger un résultat JSON exactement identique et préserver le hash, l'exécution `COMPLETED`, l'offre avec `geography IS NULL`, l'événement `ACTION_SUCCEEDED` et les quatre compteurs de persistance.
- Vérifier une seule ligne initiale dans `idempotency_keys`, `action_executions`, `offers` et un seul événement de succès, puis les mêmes compteurs après replay.
- Le contrôle statique vérifie le défaut dans la migration existante, l'omission dans le premier appel, NULL explicite dans le replay, la stabilité de tous les autres paramètres et les trois points d'intégration CI.

## Validation

- QA412 prerequisite : CLOSED. QIMA CI [#1446](https://github.com/meridane/QimaTrade-MVP/actions/runs/43615260933) SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 ainsi que les deux marqueurs explicites QA412 PASS sont confirmés.
- La signature existante contient `p_geography text DEFAULT NULL::text` ; aucune migration n'est modifiée.
- Le scénario QA413 est ajouté à Verify, PostgreSQL 16 et PostgreSQL 17.6, après l'initialisation de la fixture jetable.
- Les résultats QA413, npm audit, TypeScript, build, Playwright, CodeQL et Vercel seront consignés après la CI déclenchée par la mise à jour de la branche PR.
- Aucun résultat QA413 n'est revendiqué avant l'exécution des jobs.

## Sécurité et limites

- Les tests runtime n'utilisent que les bases PostgreSQL jetables CI et une URL loopback.
- Aucun accès ou changement aux données ou migrations Supabase Production, secrets, grants, RLS ou paramètres PostgreSQL persistants.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Les valeurs utilisées sont des fixtures synthétiques ; ce test caractérise le contrat PostgreSQL existant et ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent en attente d'approbation métier.

# QIMA V1 Function Register — QA412

## QA412 — omission de p_market et replay avec NULL explicite

**Statut : IMPLEMENTED — validation GitHub Actions en attente sur le nouveau HEAD.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa412-market-default-replay-20261115-0118`.
**Commit de base :** `da8bb94ed6deb14720bb9b3c3f61cfd3a7de9ede`.

## Portée

- Caractériser la signature existante `p_market text DEFAULT NULL::text` sans modifier la migration.
- Le premier appel CREATE_OFFER de la fixture PostgreSQL jetable omet réellement l'argument nommé `p_market`.
- Les deux appels fournissent explicitement `p_conditions => NULL` et conservent identiques tous les autres paramètres effectifs.
- Le replay avec le même tenant et la même clé fournit explicitement `p_market => NULL`.
- Exiger un résultat JSON exactement identique et préserver le hash, l'exécution `COMPLETED`, l'offre avec `market IS NULL`, l'événement `ACTION_SUCCEEDED` et les quatre compteurs de persistance.
- Vérifier une seule ligne initiale dans `idempotency_keys`, `action_executions`, `offers` et un seul événement de succès, puis les mêmes compteurs après replay.
- Le contrôle statique vérifie le défaut dans la migration existante, l'omission dans le premier appel, NULL explicite dans le replay, la stabilité de tous les autres paramètres et les trois points d'intégration CI.

## Validation

- QA411 prerequisite : CLOSED. QIMA CI [#1443](https://github.com/meridane/QimaTrade-MVP/actions/runs/43611188057) SUCCESS ; les deux marqueurs runtime sont confirmés.
- Le scénario QA412 est ajouté à Verify, PostgreSQL 16 et PostgreSQL 17.6, après l'initialisation du fixture jetable.
- Les résultats runtime QA412, npm audit, TypeScript, build, Playwright, CodeQL et Vercel seront consignés après la CI déclenchée par ce commit.
- Aucun résultat QA412 n'est revendiqué avant l'exécution des jobs.

## Sécurité et limites

- Les tests runtime n'utilisent que les bases PostgreSQL jetables CI et une URL loopback.
- Aucun accès ou changement aux données ou migrations Supabase Production, secrets, grants, RLS ou paramètres PostgreSQL persistants.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Les valeurs utilisées sont des fixtures synthétiques ; ce test caractérise le contrat PostgreSQL existant et ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent en attente d'approbation métier.

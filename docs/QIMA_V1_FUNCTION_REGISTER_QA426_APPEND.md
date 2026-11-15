# QIMA V1 Function Register — QA426

## QA426 — correct and protect CREATE_OFFER default-replay diagnostics

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `4f35e3424d7beee21ab3a2e06a7fdb7850338408`.  
**Branche de travail :** `work/qa426-geography-default-diagnostics-20261115-1635`.

## Constat et portée
- Le contrat statique QA413 utilisait encore le diagnostic `runtime is missing the QA413 market-default replay block`, alors que le bloc cible `p_geography`.
- Son diagnostic de paramètres identiques disait `all non-market effective parameters`, ce qui désignait le mauvais paramètre.
- Le contrôle d'existence du bloc était exécuté après l'extraction de `INPUT_LINE` ; il est maintenant effectué immédiatement après l'extraction du bloc, afin de produire le diagnostic le plus précis si le bloc manque.
- QA426 corrige ces deux diagnostics en `geography` et ajoute `tests/sql/test-create-offer-default-replay-diagnostics-contract.sh`.
- Le nouveau contrôle vérifie que QA410, QA411, QA412 et QA413 identifient chacun leur propre paramètre dans les diagnostics de bloc manquant et de paramètres non ciblés.
- Le nouveau contrôle vérifie également que QA413 vérifie l'existence du bloc avant de lire sa ligne `v_input`.
- Le script est intégré une seule fois au job Verify, immédiatement après le contrôle statique QA413. Aucun nouveau job PostgreSQL ni modification de migration n'est nécessaire.

## Validation
- Prévalidation structurelle : les deux anciens diagnostics QA413 sont absents, les deux nouveaux diagnostics sont présents, et le garde de bloc précède l'extraction de `INPUT_LINE`.
- La validation GitHub Actions sur le nouveau HEAD reste en attente ; aucun résultat QA426 PASS n'est revendiqué avant le journal Verify.
- Le runtime QA413 déjà validé sur PostgreSQL 16 et 17.6 par CI #1483 constitue une preuve de QA425, pas une preuve d'exécution du nouveau contrôle QA426.

## Sécurité et limites
- QA426 modifie uniquement les diagnostics d'un test shell et ajoute un contrôle statique de cohérence.
- Aucun SQL runtime, fonction, migration, hash, statut, règle métier ou donnée applicative n'est modifié.
- Aucun DML direct, aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Il s'agit d'une amélioration de qualité des tests, pas d'un constat de vulnérabilité.

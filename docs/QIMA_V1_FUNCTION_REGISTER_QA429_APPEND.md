# QIMA V1 Function Register — QA429

## QA429 — concurrent identical same-key requests both return one committed success result

**Statut : IMPLEMENTED — validation runtime en attente sur la CI du HEAD courant.**  
**Target :** PR #26, branche fix/create-offer-status-contract.  
**HEAD de base :** b17dc3ac672d0ef54ea8d38a16197d19dc5e83b0.  
**Branche de travail :** work/qa429-concurrent-identical-success-20261115-2301.

## Constat et portée

- QA103 couvre déjà le cas où le premier appel identique échoue volontairement puis où le second appel identique réussit après rollback.
- QA288 et QA428 couvrent des requêtes concurrentes utilisant la même tenant/key avec des payloads différents ; la requête en attente est rejetée.
- Les tests de replay séquentiel vérifient le retour du résultat après COMMIT, mais ne caractérisent pas directement deux requêtes identiques simultanées dont les deux clients reçoivent un succès.
- QA429 ajoute ce cas complémentaire : la première requête détient le verrou advisory tenant/key pendant le délai fixture ; la deuxième requête strictement identique attend le même verrou ; après le COMMIT de la première, la deuxième doit réussir en rejouant le résultat persisté.
- Les deux appels utilisent le même tenant, la même clé d'idempotence, le même input JSONB et les mêmes paramètres métier. Les noms de session PostgreSQL sont distincts pour prouver l'attente concurrente.
- Le test compare byte-for-byte les résultats des deux appels, le résultat stocké dans idempotency_keys et un replay séquentiel ultérieur.
- Les assertions vérifient le hash canonique, un seul enregistrement dans chacune des tables idempotency_keys, action_executions, offers et action_events, ainsi que le résultat de succès identique.

## Contrôles et intégration

- Nouveau scénario runtime : bloc QA429 dans tests/sql/run-create-offer-integration.sh.
- Nouveau contrôle statique : tests/sql/test-create-offer-concurrent-identical-success-contract.sh.
- Le contrôle statique est intégré au job Verify.
- Le runner partagé existant exécute le scénario sur PostgreSQL 16 et PostgreSQL 17.6.
- La validation du nouveau HEAD reste en attente ; aucun résultat runtime QA429 n'est revendiqué avant lecture des journaux de la nouvelle CI.

## Sécurité et limites

- Le runner commun refuse toute URL DATABASE_URL qui ne cible pas le service PostgreSQL jetable qima_test sur loopback.
- QA429 n'effectue aucun DML direct ni changement de schéma, de rôle, de grant ou de policy. Les écritures applicatives passent uniquement par execute_create_offer_v1 ; les assertions sont en lecture seule.
- Le test caractérise le comportement du wrapper et des fixtures synthétiques de CI, pas la fonction basse couche dans Supabase Production.
- Il ne constitue pas un constat de vulnérabilité.
- Aucun déploiement Production, merge, force-push ou changement des règles de protection.

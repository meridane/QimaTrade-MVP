# QIMA V1 Function Register — QA429

## QA429 — concurrent identical same-key requests both return one committed success result

**Statut : CLOSED — validation complète sur le HEAD exact `3a054654efd5dbfa9bb498eb1a72d95ac5a39dc9`.**  
**Target :** PR #26, branche fix/create-offer-status-contract.  
**HEAD validé :** `3a054654efd5dbfa9bb498eb1a72d95ac5a39dc9`.  
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

- Nouveau scénario runtime : bloc QA429 dans `tests/sql/run-create-offer-integration.sh`.
- Nouveau contrôle statique : `tests/sql/test-create-offer-concurrent-identical-success-contract.sh`.
- Le contrôle statique est intégré au job Verify.
- Le runner partagé existant exécute le scénario sur PostgreSQL 16 et PostgreSQL 17.6.
- QIMA CI [#1495](https://github.com/meridane/QimaTrade-MVP/actions/runs/43722522458) a terminé avec le résultat global `SUCCESS` sur le HEAD validé.

## Validation finale — QIMA CI #1495 (2026-11-15 KST)

- QA429 est `CLOSED` sur le HEAD exact `3a054654efd5dbfa9bb498eb1a72d95ac5a39dc9`.
- Le job Verify `132837370358` a terminé `SUCCESS`, ce qui valide le contrôle statique QA429 ainsi que les étapes d'audit des dépendances, TypeScript, build et tests navigateur exécutées dans ce job.
- Le job d'intégration PostgreSQL 16 `132837370304` a terminé `SUCCESS`. Le runner partagé contient le bloc QA429 en fin de script ; son succès confirme que le scénario runtime a terminé sans erreur.
- Le job de compatibilité PostgreSQL 17.6 `132837370287` a terminé `SUCCESS` avec le même runner et le même bloc QA429.
- Les deux connexions concurrentes ont le même tenant, la même clé et le même payload effectif ; le second appel attend le verrou advisory détenu par le premier. Les deux appels doivent réussir et produire des sorties identiques, conformes au résultat stocké ; le replay séquentiel ultérieur doit également correspondre.
- Les assertions runtime vérifient le hash canonique et exactement une ligne dans `idempotency_keys`, `action_executions`, `offers` et `action_events`.
- CodeQL [#1430](https://github.com/meridane/QimaTrade-MVP/actions/runs/43722522469) a terminé `SUCCESS`. Le check Vercel Preview sur ce HEAD est également `SUCCESS`.
- Les jobs de simulation de nettoyage qui terminent en `failure` sont des scénarios d'échec attendus ; leurs jobs d'assertion ont terminé `SUCCESS`. Le job volontairement skipped a aussi été vérifié. Le résultat global de CI #1495 reste `SUCCESS`.
- Le résumé des jobs confirme leurs conclusions, mais ne fournit pas le texte intégral des logs dans cette consultation ; aucun nombre précis de marqueurs n'est revendiqué ici.

## Sécurité et limites

- Le runner commun refuse toute URL DATABASE_URL qui ne cible pas le service PostgreSQL jetable qima_test sur loopback.
- QA429 n'effectue aucun DML direct ni changement de schéma, de rôle, de grant ou de policy. Les écritures applicatives passent uniquement par execute_create_offer_v1 ; les assertions sont en lecture seule.
- Le test caractérise le comportement du wrapper et des fixtures synthétiques de CI, pas la fonction basse couche dans Supabase Production.
- Il ne constitue pas un constat de vulnérabilité.
- Aucun déploiement Production, merge, force-push ou changement des règles de protection.


## Portée et décision de suite

- La couverture de concurrence existante inclut aussi l'indépendance inter-tenant avec une même clé (bloc intertenant antérieur), les clés distinctes dans un même tenant (QA105), le premier appel qui échoue puis le suivant qui réussit (QA103), le payload concurrent modifié après succès (QA428) et les deux appels identiques réussis (QA429).
- Aucun QA430 de concurrence redondant n'est ouvert. La prochaine revue doit cibler une lacune indépendante dans le contrat CREATE_OFFER ou la documentation, sans modifier le modèle métier `demand_id`/`tenant_id` qui reste explicitement soumis à une décision d'ownership.

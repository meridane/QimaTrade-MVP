# QIMA V1 Function Register — QA421

## QA421 — pre-persistence validation failures leave no persisted side effects

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `2975138456c1c7d289a75d7faf2dbaf9b4d2fdaa`.  
**Branche de travail :** `work/qa421-pre-persistence-rejection-no-writes-20261115-1139`.

## Portée
- Caractériser trois gardes déjà présents dans `execute_create_offer_v1` : mismatch de `p_provider_actor_id`, quantité nulle/non positive et demande absente.
- Chaque appel utilise un tenant membre valide, un sujet JWT synthétique connu, une clé d'idempotence dédiée et des références de fixture jetables.
- Les erreurs attendues sont respectivement `INVALID_PROVIDER_ACTOR`, `INVALID_QUANTITY` et `DEMAND_NOT_FOUND`.
- Le scénario prend un snapshot des comptes de `idempotency_keys`, `action_executions`, `offers` et `action_events` avant les appels, puis exige que les quatre comptes restent strictement identiques après les rejets.
- Il vérifie également l'absence de chaque clé, exécution, offre sentinelle et événement associé.
- Le test SQL appelle uniquement `execute_create_offer_v1` et effectue des assertions SELECT ; aucun DML direct ni changement de schéma n'est utilisé.
- Le contrat statique vérifie que les gardes concernés précèdent le hash, le verrou d'idempotence et les premières écritures, puis vérifie le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.

## Distinction avec les tests existants
- QA95 caractérise déjà le rollback transactionnel après un échec CHECK lors de l'insertion de l'offre.
- QA96 caractérise déjà le rollback lorsque l'insertion finale de `ACTION_SUCCEEDED` échoue.
- QA421 couvre un autre point : les rejets de validation qui doivent survenir avant le hash, le verrou et toute création de ligne d'exécution/idempotence.
- Ce scénario ne remplace pas QA95/QA96 et n'ajoute aucune règle d'autorisation demand/tenant.

## Validation et limites
- QIMA CI [#1473](https://github.com/meridane/QimaTrade-MVP/actions/runs/43665095980) a validé le HEAD de base `29751384` : Verify, PostgreSQL 16, PostgreSQL 17.6, npm audit au seuil high, TypeScript, build Next.js et Playwright 347/347 SUCCESS. Ce run est un état de référence antérieur ; il ne valide pas QA421.
- CodeQL [#1408](https://github.com/meridane/QimaTrade-MVP/actions/runs/43665096013) SUCCESS sur le HEAD de base.
- Aucun marqueur QA421 PASS n'est revendiqué avant l'exécution du nouveau SQL dans les deux environnements PostgreSQL.
- Le test utilise uniquement les fixtures synthétiques et les bases jetables de CI. Il ne constitue pas un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié. Aucun déploiement Production, merge, force-push ou changement de règle de protection.

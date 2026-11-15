# QIMA V1 Function Register — QA421

## QA421 — pre-persistence validation failures leave no persisted side effects

**Statut : CLOSED — QIMA CI #1477 SUCCESS sur le HEAD `0b2962711b7d321eebdcf4080dc81ac7b2428cf3`.**  
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

## Validation définitive
- QIMA CI [#1477](https://github.com/meridane/QimaTrade-MVP/actions/runs/43669377735) : **SUCCESS** sur le HEAD `0b296271`.
- Verify job `132676597613` : SUCCESS ; le step `Verify CREATE_OFFER pre-persistence validation rejection is write-free` a réussi. Le journal contient exactement un marqueur de contrat statique QA421 PASS.
- PostgreSQL 16 job `132676597763` : SUCCESS ; le step runtime QA421 a réussi et le journal contient exactement un marqueur `QA421 PASS`.
- PostgreSQL 17.6 job `132676597862` : SUCCESS ; le step runtime QA421 a réussi et le journal contient exactement un marqueur `QA421 PASS`.
- npm audit : SUCCESS, 0 vulnérabilité reportée aux niveaux info, low, moderate, high et critical. TypeScript : SUCCESS. Build Next.js : SUCCESS. Playwright : **347/347**.
- CodeQL [#1412](https://github.com/meridane/QimaTrade-MVP/actions/runs/43669377722) : SUCCESS.
- Statut Vercel combiné sur le HEAD `0b296271` : `failure`, cible `build-rate-limit`. Cette limitation du fournisseur n'est pas un échec du build Next.js, qui a réussi dans Verify.
- Les jobs de simulation négative du nettoyage ont présenté les échecs attendus ; leurs assertions dédiées ont réussi. Le job volontairement skipped a été reconnu comme tel.

## Limites et sécurité
- Le test utilise uniquement les fixtures synthétiques et les bases jetables de CI. Il ne constitue pas un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

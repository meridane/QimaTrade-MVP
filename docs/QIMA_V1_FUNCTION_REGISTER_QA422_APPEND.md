# QIMA V1 Function Register — QA422

## QA422 — invalid currency variants leave all persistence tables unchanged

**Statut : CLOSED — QIMA CI #1478 SUCCESS sur le HEAD `ccacb9890546c243916f11567a07ca1356848d66`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `0b2962711b7d321eebdcf4080dc81ac7b2428cf3`.  
**Branche de travail :** `work/qa422-currency-rejection-no-writes-20261115-1236`.

## Portée
- Caractériser le garde `INVALID_CURRENCY` déjà présent dans `execute_create_offer_v1` sans modifier la migration.
- Tester cinq entrées invalides : code non pris en charge (`XYZ`), SQL NULL, espaces seuls, code paddé (` USD `) et code en minuscules (`usd`).
- Chaque appel utilise un tenant membre valide, l'acteur authentifié correspondant, un produit actif, une demande existante et une clé d'idempotence dédiée.
- Chaque appel doit retourner exactement `INVALID_CURRENCY`.
- Les comptes de `idempotency_keys`, `action_executions`, `offers` et `action_events` sont comparés avant/après ; les clés, exécutions, offres et événements sentinelles restent absents.
- Le SQL appelle uniquement `execute_create_offer_v1` et utilise des assertions SELECT ; aucun DML direct ni changement de schéma n'est utilisé.

## Distinction avec la couverture existante
- Le bloc historique vérifiait déjà les erreurs de devise et l'absence d'offres.
- QA422 renforce cette couverture en exigeant l'absence de toute écriture dans les quatre tables, pas seulement dans `offers`.
- Les régressions numériques QA384–QA390 et QA421 restent distinctes ; aucun comportement de devise valide n'est modifié.

## Validation définitive
- QIMA CI [#1478](https://github.com/meridane/QimaTrade-MVP/actions/runs/43673391449) : **SUCCESS** sur le HEAD `ccacb989`.
- Verify job `132688153810` : SUCCESS ; exactement un marqueur `QA422 static contract PASS`.
- PostgreSQL 16 job `132688153560` : SUCCESS ; exactement un marqueur runtime `QA422 PASS`.
- PostgreSQL 17.6 job `132688153797` : SUCCESS ; exactement un marqueur runtime `QA422 PASS`.
- npm audit au seuil high : SUCCESS. TypeScript : SUCCESS. Build Next.js : SUCCESS. Playwright : **347/347**.
- CodeQL [#1413](https://github.com/meridane/QimaTrade-MVP/actions/runs/43673391361) : SUCCESS.
- Statut combiné Vercel sur le HEAD `ccacb989` : SUCCESS ([Preview](https://vercel.com/bmk1/qimatrade-mvp/9ZCsqjUF4GpiKjbsi5LX6uGevfxi)).
- Les jobs de simulation négative du nettoyage ont présenté leurs échecs attendus ; leurs assertions dédiées ont réussi. Le job volontairement skipped a été reconnu comme tel.

## Limites et sécurité
- Le test utilise uniquement des fixtures synthétiques et les bases jetables de CI. Il ne constitue pas un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

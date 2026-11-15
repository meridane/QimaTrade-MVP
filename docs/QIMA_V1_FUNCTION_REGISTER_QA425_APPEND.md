# QIMA V1 Function Register — QA425

## QA425 — correct the QA413 geography-default replay fixture label

**Statut : CLOSED — QIMA CI [#1483](https://github.com/meridane/QimaTrade-MVP/actions/runs/43684750243) SUCCESS sur le HEAD `4f35e3424d7beee21ab3a2e06a7fdb7850338408`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `6964384f3b572c91cdc8f13c39b58b1e5f4dcb48`.  
**Branche de travail :** `work/qa425-geography-default-fixture-label-20261115-1512`.

## Constat et portée
- Le bloc runtime `qa413_geography_default_replay` utilisait par erreur `v_input = '{"case":"qa412-market-default-replay"}'::jsonb`, un libellé copié depuis QA412.
- La valeur n'altérait pas l'argument ciblé `p_geography`, le hash attendu ni le résultat du replay, mais rendait l'identité du fixture incohérente avec la clé, le nom d'offre et le bloc QA413.
- Le libellé est corrigé en `qa413-geography-default-replay`.
- Le contrôle statique QA413 existant exige désormais cette valeur exactement une fois et refuse l'ancien libellé dans le bloc QA413.
- Le workflow possédait déjà un step Verify pour le contrôle statique QA413 et des steps runtime sur PostgreSQL 16 et 17.6 ; aucun changement de workflow n'est nécessaire.

## Validation définitive — QIMA CI #1483
- QIMA CI [#1483](https://github.com/meridane/QimaTrade-MVP/actions/runs/43684750243) : **SUCCESS** sur le HEAD `4f35e3424d7beee21ab3a2e06a7fdb7850338408`.
- Verify job `132723980558` : SUCCESS ; exactement un marqueur `QA413 static contract PASS`.
- PostgreSQL 16 job `132723980516` : SUCCESS ; exactement un marqueur `QA413 PASS`.
- PostgreSQL 17.6 job `132723980262` : SUCCESS ; exactement un marqueur `QA413 PASS`.
- npm audit au seuil high, TypeScript, build Next.js et Playwright **347/347** : SUCCESS.
- CodeQL [#1418](https://github.com/meridane/QimaTrade-MVP/actions/runs/43684750307) : SUCCESS.
- Vercel combined status : FAILURE avec cible `build-rate-limit`, correspondant à la limite quotidienne du fournisseur. Le build Next.js GitHub Actions est réussi ; aucun échec de compilation n'est établi.
- QA425 est **CLOSED**.

## Sécurité et limites
- Ce changement corrige uniquement une étiquette JSON de fixture et ajoute une assertion statique ; il ne change aucune règle métier, signature SQL, hash, statut, autorisation ou donnée applicative.
- Aucun DML direct, aucune migration, aucune donnée Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Il s'agit d'une correction de qualité de test, pas d'un constat de vulnérabilité.

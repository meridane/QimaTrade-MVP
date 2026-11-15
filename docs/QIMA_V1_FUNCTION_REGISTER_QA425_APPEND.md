# QIMA V1 Function Register — QA425

## QA425 — correct the QA413 geography-default replay fixture label

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `6964384f3b572c91cdc8f13c39b58b1e5f4dcb48`.  
**Branche de travail :** `work/qa425-geography-default-fixture-label-20261115-1512`.

## Constat et portée
- Le bloc runtime `qa413_geography_default_replay` utilisait par erreur `v_input = '{"case":"qa412-market-default-replay"}'::jsonb`, un libellé copié depuis QA412.
- La valeur n'altérait pas l'argument ciblé `p_geography`, le hash attendu ni le résultat du replay, mais rendait l'identité du fixture incohérente avec la clé, le nom d'offre et le bloc QA413.
- Le libellé est corrigé en `qa413-geography-default-replay`.
- Le contrôle statique QA413 existant exige désormais cette valeur exactement une fois et refuse l'ancien libellé dans le bloc QA413.
- Le workflow possédait déjà un step Verify pour le contrôle statique QA413 et des steps runtime sur PostgreSQL 16 et 17.6 ; aucun changement de workflow n'est nécessaire.

## Validation
- La validation historique QA413 est CLOSED sur QIMA CI #1447, avec un marqueur runtime QA413 PASS sur PostgreSQL 16 et PostgreSQL 17.6.
- QA425 reste IMPLEMENTED jusqu'à une nouvelle exécution CI sur le HEAD corrigé.
- Les contrôles attendus sont le Verify QA413 statique, le runtime QA413 sur les deux versions PostgreSQL, puis la réussite globale de QIMA CI.

## Sécurité et limites
- Ce changement corrige uniquement une étiquette JSON de fixture et ajoute une assertion statique ; il ne change aucune règle métier, signature SQL, hash, statut, autorisation ou donnée applicative.
- Aucun DML direct, aucune migration, aucune donnée Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Il s'agit d'une correction de qualité de test, pas d'un constat de vulnérabilité.

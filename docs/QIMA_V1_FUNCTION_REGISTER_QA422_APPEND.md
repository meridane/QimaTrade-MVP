# QIMA V1 Function Register — QA422

## QA422 — invalid currency variants leave all persistence tables unchanged

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `0b2962711b7d321eebdcf4080dc81ac7b2428cf3`.  
**Branche de travail :** `work/qa422-currency-rejection-no-writes-20261115-1236`.

## Portée
- Caractériser le garde `INVALID_CURRENCY` déjà présent dans `execute_create_offer_v1` sans modifier la migration.
- Tester cinq entrées invalides : code non pris en charge (`XYZ`), SQL NULL, chaîne vide/espaces, code avec espaces périphériques (` USD `) et code en minuscules (`usd`).
- Chaque appel utilise un tenant membre valide, l'acteur authentifié correspondant, un produit actif, une demande existante et une clé d'idempotence dédiée.
- Chaque appel doit retourner exactement `INVALID_CURRENCY`.
- Le scénario capture les comptes des quatre tables `idempotency_keys`, `action_executions`, `offers` et `action_events` avant et après la matrice et exige leur égalité.
- Il vérifie également l'absence des clés, exécutions, offres sentinelles et événements liés aux cinq appels.
- Le SQL appelle uniquement `execute_create_offer_v1` et utilise des assertions SELECT ; aucun DML direct ni changement de schéma n'est utilisé.

## Distinction avec la couverture existante
- Le bloc de validation historique dans `create-offer-runtime.sql` vérifie déjà les erreurs de devise exacte pour ces variantes et l'absence d'offres.
- QA422 renforce cette couverture en exigeant l'absence de toute écriture dans les quatre tables, pas seulement dans `offers`.
- Les régressions numériques QA384–QA390 et QA421 restent distinctes ; aucun comportement de devise valide n'est modifié.

## Validation et limites
- Le contrôle statique `tests/sql/test-create-offer-currency-rejection-no-writes-contract.sh` vérifie le garde exact, son ordre avant hash/verrou/persistance, les cinq cas, l'unicité du marqueur, l'absence de DML direct et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.
- Le runtime `tests/sql/create-offer-currency-rejection-no-writes.sql` est câblé dans les deux runners PostgreSQL jetables.
- Aucun résultat QA422 statique ou runtime n'est revendiqué avant l'exécution de la nouvelle CI sur le HEAD publié.
- Le test synthétique ne constitue pas un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié. Aucun déploiement Production, merge, force-push ou changement de règle de protection.

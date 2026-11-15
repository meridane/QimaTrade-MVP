# QIMA V1 Function Register — QA424

## QA424 — non-finite price rejection leaves all persistence tables unchanged

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `981f57442441619bac0bb597560000e2e66f9d18`.  
**Branche de travail :** `work/qa424-nonfinite-price-no-writes-20261115-1432`.

## Portée
- Caractériser le garde `INVALID_PRICE` déjà présent dans `execute_create_offer_v1` pour `NaN` et `-Infinity`, sans modifier la migration.
- Chaque appel utilise un tenant membre valide, l'acteur authentifié A, une demande existante, un Product Master actif et une clé d'idempotence unique.
- Les deux appels doivent retourner exactement `INVALID_PRICE`.
- Le scénario compare avant/après les comptes de `idempotency_keys`, `action_executions`, `offers` et `action_events` et exige leur égalité.
- Il vérifie également l'absence des clés, exécutions, offres et événements sentinelles.
- Le SQL appelle uniquement `execute_create_offer_v1` et utilise des assertions SELECT ; aucun DML direct ni changement de schéma n'est utilisé.

## Distinction avec les tests existants
- QA384 vérifie déjà le rejet de `NaN` et `-Infinity` pour le prix, avec absence de lignes dans les tables d'idempotence, d'exécution et d'offre ; son bloc ne compare pas explicitement le compte de `action_events`.
- QA388 couvre déjà `+Infinity` pour le prix avec comparaison des quatre tables.
- QA387 couvre le prix négatif et QA390 le prix SQL NULL avec comparaison des quatre tables.
- QA424 complète donc précisément l'invariant `action_events` pour les deux cas non finis restants, sans modifier le domaine numérique ni la règle métier.

## Validation et limites
- Le contrôle statique est `tests/sql/test-create-offer-nonfinite-price-no-writes-contract.sh`.
- Le runtime est `tests/sql/create-offer-nonfinite-price-no-writes.sql`.
- Le workflow doit exécuter le contrôle statique dans Verify et le SQL sur PostgreSQL 16 et PostgreSQL 17.6.
- Aucun résultat runtime QA424 n'est revendiqué avant les journaux finaux des deux versions PostgreSQL.
- Le scénario utilise uniquement les fixtures et bases jetables de CI ; il ne constitue pas un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié. Aucun déploiement Production, merge, force-push ou changement de règle de protection.

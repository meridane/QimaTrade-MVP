# QIMA V1 Function Register — QA414

## QA414 — omission de p_documentation_status et replay avec NULL explicite

**Statut : IMPLEMENTED — nouvelle validation CI en attente sur la branche de travail.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa414-documentation-status-default-replay-20261115-0405`.
**Commit de base :** `c4dcdfa4ff6e35343570fd640092f67e01bdce2f`.

## Portée
- Caractériser la signature existante `p_documentation_status text DEFAULT NULL::text` sans modifier la migration.
- Le premier appel CREATE_OFFER dans `tests/sql/create-offer-runtime.sql` omet réellement l'argument nommé `p_documentation_status`.
- Le replay avec le même tenant et la même clé fournit explicitement `p_documentation_status => NULL`.
- Les autres paramètres effectifs restent identiques, notamment `p_geography => NULL`, `p_market => 'fixture-market-stable'` et `p_attributes => '{}'::jsonb`.
- Exiger le résultat JSON exact, le hash inchangé, l'exécution `COMPLETED`, `offers.documentation_status IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans `idempotency_keys`, `action_executions`, `offers` et `action_events`.
- Le contrôle statique est ajouté au script existant `test-create-offer-documentation-status-mismatch-replay-contract.sh`, déjà exécuté par Verify. Le scénario runtime est ajouté à `create-offer-runtime.sql`, déjà exécuté par le runner PostgreSQL 16 et 17.6.
- Aucun changement de `.github/workflows/**` n'est nécessaire.

## Validation
- Prérequis QA413 : CLOSED sur QIMA CI [#1447](https://github.com/meridane/QimaTrade-MVP/actions/runs/43622170878), avec exactement un marqueur runtime `QA413 PASS` dans chacun des journaux PostgreSQL 16 et 17.6.
- La validation QA414 sera consignée après le déclenchement CI sur le nouveau HEAD.
- Aucun résultat runtime QA414 n'est revendiqué avant cette exécution.

## Sécurité et limites
- Le test utilise uniquement les fixtures PostgreSQL temporaires de CI.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Les valeurs sont synthétiques ; le test caractérise le défaut SQL existant et ne prouve aucune vulnérabilité Production.
- Les décisions métier d'autorisation demand/tenant et MKT-1.1, MKT-1.2, MKT-1.3 restent bloquées sur approbation explicite.

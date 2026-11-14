# QIMA V1 Function Register — QA415

## QA415 — omission de p_lifecycle et replay avec NULL explicite

**Statut : IMPLEMENTED — validation CI en attente sur la branche de travail.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa415-lifecycle-default-replay-20261115-0450`.
**Commit de base :** `811953827e845705b7d8726de9cabf2e49f73d4e`.

## Portée
- Caractériser la signature existante `p_lifecycle text DEFAULT NULL::text`, sans modifier la migration ni introduire de taxonomie métier.
- Le premier appel CREATE_OFFER dans `tests/sql/create-offer-runtime.sql` omet réellement l'argument nommé `p_lifecycle`.
- Le replay avec le même tenant et la même clé fournit explicitement `p_lifecycle => NULL`.
- Tous les autres paramètres effectifs restent identiques, notamment `p_documentation_status => NULL`, `p_geography => NULL`, `p_market => 'fixture-market-stable'` et `p_attributes => '{}'::jsonb`.
- Exiger le résultat JSON exact, le hash inchangé, l'exécution `COMPLETED`, `offers.lifecycle IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans `idempotency_keys`, `action_executions`, `offers` et `action_events`.
- Le scénario runtime est ajouté à `create-offer-runtime.sql`, déjà exécuté par les runners PostgreSQL 16 et 17.6.
- Le contrôle statique QA415 est ajouté au script QA406 existant déjà exécuté par Verify. Aucun changement de workflow n'est nécessaire.

## Validation
- Prérequis QA414 : CLOSED sur QIMA CI [#1448](https://github.com/meridane/QimaTrade-MVP/actions/runs/43630697523), avec exactement un marqueur runtime `QA414 PASS` dans chacun des journaux PostgreSQL 16 et 17.6 ; Verify, Playwright 347/347 et CodeQL #1395 ont réussi.
- La validation QA415 sera consignée après le déclenchement CI sur le nouveau HEAD.
- Aucun résultat runtime QA415 n'est revendiqué avant cette exécution.

## Sécurité et limites
- Le test utilise uniquement les fixtures PostgreSQL temporaires de CI.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Les valeurs sont synthétiques ; le test caractérise le défaut SQL existant et ne prouve aucune vulnérabilité Production.
- Les décisions métier d'autorisation demand/tenant et MKT-1.1, MKT-1.2, MKT-1.3 restent bloquées sur approbation explicite.

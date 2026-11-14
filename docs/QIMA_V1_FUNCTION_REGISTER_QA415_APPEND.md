# QIMA V1 Function Register — QA415

## QA415 — omission de p_lifecycle et replay avec NULL explicite

**Statut : CLOSED — QIMA CI [#1449](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745260) SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 terminés. CodeQL [#1396](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745205) SUCCESS.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa415-lifecycle-default-replay-20261115-0450`.
**Commit validé :** `406485815a0560a2f11ddb435186f124b69e26b5`.

## Portée vérifiée
- La signature existante déclare `p_lifecycle text DEFAULT NULL::text` ; aucune migration n'a été modifiée.
- Le premier appel CREATE_OFFER omet réellement `p_lifecycle` ; le replay avec le même tenant et la même clé fournit explicitement `p_lifecycle => NULL`.
- Tous les autres paramètres effectifs restent identiques, notamment `p_documentation_status => NULL`, `p_geography => NULL`, `p_market => 'fixture-market-stable'`, `p_attributes => '{}'::jsonb`, `p_offer_type => 'fixture-offer-type-stable'` et `p_pricing_model => 'fixture-pricing-model-stable'`.
- Les deux appels retournent exactement le même résultat JSON.
- Le test vérifie le hash initial, le résultat d'idempotence, l'exécution `COMPLETED`, `offers.lifecycle IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans `idempotency_keys`, `action_executions`, `offers` et `action_events`.
- Le contrôle statique QA415 est intégré au script lifecycle déjà exécuté par Verify. Les runners PostgreSQL 16 et 17.6 réutilisent le même scénario runtime.

## Preuves CI
- QIMA CI [#1449](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745260), run `43634745260` : SUCCESS.
- Verify job `132568972779` : marqueur `QA415 static contract PASS` confirmé ; npm audit au seuil high, TypeScript, build Next.js et **347/347** tests Playwright réussis.
- PostgreSQL 16 job `132568972750` : SUCCESS ; le journal complet contient exactement un marqueur `QA415 PASS`.
- PostgreSQL 17.6 job `132568972722` : SUCCESS ; le journal complet contient exactement un marqueur `QA415 PASS`.
- Les deux jobs PostgreSQL ont également terminé les contrôles CREATE_OFFER/concurrence, repeat-guard, catalogue, replication slots, paramètres locaux, ACL, extensions, privilèges du runner, RLS et nettoyage.
- Les deux simulations négatives du nettoyage ont produit les échecs attendus ; leurs jobs d'assertion ont réussi. Le job volontairement skipped et son assertion ont produit le résultat attendu.
- CodeQL [#1396](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745205) : SUCCESS.
- Le statut combiné Vercel sur le HEAD validé est FAILURE avec la cible `build-rate-limit`. Le build Next.js du job Verify est réussi ; aucune erreur de compilation applicative n'est déduite de cette limitation fournisseur.

## Sécurité et limites
- Les tests runtime utilisent uniquement les bases PostgreSQL jetables de CI et des fixtures synthétiques.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'a été modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Ce test caractérise le défaut SQL existant ; il ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à une approbation métier explicite.

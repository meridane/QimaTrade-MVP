# QIMA V1 Function Register — QA414

## QA414 — omission de p_documentation_status et replay avec NULL explicite

**Statut : CLOSED — QIMA CI [#1448](https://github.com/meridane/QimaTrade-MVP/actions/runs/43630697523) SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 terminés. CodeQL [#1395](https://github.com/meridane/QimaTrade-MVP/actions/runs/43630697473) SUCCESS.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Commit validé :** `811953827e845705b7d8726de9cabf2e49f73d4e`.

## Portée vérifiée
- La signature existante déclare `p_documentation_status text DEFAULT NULL::text` ; aucune migration n'a été modifiée.
- Le premier appel nommé omet réellement `p_documentation_status` ; le replay avec le même tenant et la même clé fournit explicitement `p_documentation_status => NULL`.
- Tous les autres paramètres effectifs sont identiques, notamment `p_geography => NULL`, `p_market => 'fixture-market-stable'` et `p_attributes => '{}'::jsonb`.
- Les deux appels retournent exactement le même résultat JSON.
- Le test vérifie le hash initial, le résultat d'idempotence, l'exécution `COMPLETED`, `offers.documentation_status IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans les quatre tables de persistance.

## Preuves CI
- QIMA CI [#1448](https://github.com/meridane/QimaTrade-MVP/actions/runs/43630697523), run `43630697523` : SUCCESS.
- Verify job `132556402415` : contrat statique QA414 PASS, npm audit au seuil high, TypeScript, build Next.js et **347/347** tests Playwright réussis.
- PostgreSQL 16 job `132556402215` : SUCCESS ; exactement un marqueur `QA414 PASS` dans le journal complet.
- PostgreSQL 17.6 job `132556402371` : SUCCESS ; exactement un marqueur `QA414 PASS` dans le journal complet.
- Les deux jobs PostgreSQL ont aussi terminé les tests CREATE_OFFER/concurrence, repeat-guard, catalogue, replication slots, paramètres, extensions, privilèges du runner, RLS, ACL et nettoyage.
- Les jobs de simulation négative du nettoyage ont échoué comme prévu ; leurs jobs d'assertion ont réussi. Le job volontairement skipped et son assertion ont produit le résultat attendu.
- CodeQL [#1395](https://github.com/meridane/QimaTrade-MVP/actions/runs/43630697473) : SUCCESS.
- Le statut combiné Vercel du HEAD validé est FAILURE avec la cible `build-rate-limit`. Le build Next.js du job Verify a réussi ; aucune erreur de compilation applicative n'est déduite de cette limitation fournisseur.

## Sécurité et limites
- Les tests runtime utilisent uniquement les bases PostgreSQL jetables de CI et des fixtures synthétiques.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'a été modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Ce test caractérise l'équivalence du défaut SQL ; il ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à une approbation métier explicite.

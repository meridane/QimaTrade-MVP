# QIMA V1 Function Register — QA413

## QA413 — omission de p_geography et replay avec NULL explicite

**Statut : CLOSED — QIMA CI [#1447](https://github.com/meridane/QimaTrade-MVP/actions/runs/43622170878) SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 terminés. CodeQL [#1394](https://github.com/meridane/QimaTrade-MVP/actions/runs/43622170873) SUCCESS.**

## Portée vérifiée
- La signature existante déclare `p_geography text DEFAULT NULL::text` ; aucune migration n'a été modifiée.
- Le premier appel nommé omet réellement `p_geography` ; les deux appels fournissent explicitement `p_market => NULL` et conservent identiques tous les autres paramètres effectifs.
- Le replay avec le même tenant et la même clé fournit explicitement `p_geography => NULL` et retourne exactement le résultat JSON initial.
- Le hash, l'exécution `COMPLETED`, l'offre avec `geography IS NULL`, l'événement `ACTION_SUCCEEDED` et les compteurs des quatre tables de persistance restent inchangés.

## Preuves CI
- QIMA CI [#1447](https://github.com/meridane/QimaTrade-MVP/actions/runs/43622170878) — run `43622170878`, conclusion SUCCESS.
- Verify job `132530053097` — contrat statique QA413 PASS, npm audit au seuil high, TypeScript, build Next.js et **347/347** tests Playwright réussis.
- PostgreSQL 16 job `132530053047` — SUCCESS ; le journal contient exactement un marqueur `QA413 PASS`.
- PostgreSQL 17.6 job `132530052797` — SUCCESS ; le journal contient exactement un marqueur `QA413 PASS`.
- Les deux jobs complets ont aussi terminé les tests CREATE_OFFER/concurrence, repeat-guard, catalogue, replication slots, paramètres, ACL, extensions, privilèges du runner, RLS et nettoyage.
- Les deux jobs de simulation négative du nettoyage ont échoué comme prévu ; leurs jobs d'assertion ont réussi. Le job volontairement skipped et son assertion ont produit le résultat attendu.
- CodeQL [#1394](https://github.com/meridane/QimaTrade-MVP/actions/runs/43622170873) — SUCCESS.
- Le statut combiné Vercel sur le HEAD `c4dcdfa4ff6e35343570fd640092f67e01bdce2f` indique `build-rate-limit`. C'est une limitation de capacité du fournisseur, pas une preuve d'échec de compilation ; le build Next.js du job Verify est réussi.

## Sécurité et limites
- Les tests runtime utilisent uniquement les bases PostgreSQL jetables de CI et des fixtures synthétiques.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'a été modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Ce test caractérise le contrat PostgreSQL ; il ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent en attente d'approbation métier.

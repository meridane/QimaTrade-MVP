# QIMA V1 Function Register — QA412

## QA412 — omission de p_market et replay avec NULL explicite

**Statut : CLOSED — QIMA CI #1446 SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 terminés.**
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa412-market-default-replay-20261115-0118`.
**Commit validé :** `0543731c297b1925956bcda3286ea5d44741e2b8`.

## Portée

- Caractériser la signature existante `p_market text DEFAULT NULL::text` sans modifier la migration.
- Le premier appel CREATE_OFFER omet réellement l'argument nommé `p_market`.
- Les deux appels fournissent explicitement `p_conditions => NULL` et conservent identiques tous les autres paramètres effectifs.
- Le replay du même tenant et de la même clé fournit explicitement `p_market => NULL`.
- Exiger le résultat JSON initial exact, le hash inchangé, l'exécution `COMPLETED`, l'offre avec `market IS NULL`, l'événement `ACTION_SUCCEEDED` et exactement une ligne dans chacune des quatre tables de persistance.

## Validation

- Première tentative QIMA CI [#1444](https://github.com/meridane/QimaTrade-MVP/actions/runs/43615154472) : Verify a échoué sur le marqueur statique, car le commentaire et le NOTICE runtime mentionnaient encore `p_conditions`. Les deux étapes SQL QA412 ont réussi, mais cette tentative n'est pas utilisée pour clôturer le dossier.
- Correction du commentaire et du marqueur runtime publiée dans `0543731c`.
- QIMA CI [#1446](https://github.com/meridane/QimaTrade-MVP/actions/runs/43615260933) : SUCCESS.
- Verify job `132510374617` : contrat statique QA412, npm audit au seuil high, TypeScript, build Next.js et **347/347** tests Playwright réussis.
- PostgreSQL 16 job `132510374270` : SUCCESS ; exactement un marqueur `QA412 PASS` dans le journal complet.
- PostgreSQL 17.6 job `132510374562` : SUCCESS ; exactement un marqueur `QA412 PASS` dans le journal complet.
- Les deux jobs ont également réussi l'intégration CREATE_OFFER/concurrence, repeat-guard, catalogue, replication slots, paramètres locaux, ACL, extensions, privilèges du runner, RLS et nettoyage.
- Les jobs de simulation négative du nettoyage ont échoué comme prévu ; leurs assertions de contrôle ont réussi. Le job volontairement skipped et son assertion ont produit le résultat attendu.
- CodeQL [#1393](https://github.com/meridane/QimaTrade-MVP/actions/runs/43615260918) : SUCCESS.
- Le statut Vercel combiné sur le commit validé est SUCCESS.

## Sécurité et limites

- Les tests runtime utilisent exclusivement les bases PostgreSQL jetables CI et une URL loopback.
- Aucun accès ou changement aux données ou migrations Supabase Production, secrets, grants, RLS ou paramètres PostgreSQL persistants.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Les valeurs de fixture sont synthétiques ; ce test caractérise le contrat PostgreSQL existant et ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à approbation métier.

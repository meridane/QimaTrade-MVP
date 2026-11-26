# QIMA V1 Function Register — QA411

## QA411 — omission de p_conditions et replay avec NULL explicite

**Statut : CLOSED — QIMA CI [#1443](https://github.com/meridane/QimaTrade-MVP/actions/runs/43611188057) SUCCESS.** Verify, PostgreSQL 16, PostgreSQL 17.6, les deux marqueurs explicites `QA411 PASS` et CodeQL [#1391](https://github.com/meridane/QimaTrade-MVP/actions/runs/43611188051) sont confirmés.
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa411-conditions-default-replay-20261115-0034`.
**HEAD validé :** `da8bb94ed6deb14720bb9b3c3f61cfd3a7de9ede`.

## Portée

- La signature existante déclare `p_conditions text DEFAULT NULL::text`; aucune migration n'a été modifiée.
- Le premier appel nommé omet réellement `p_conditions` et fournit les autres paramètres effectifs.
- Le replay avec le même tenant et la même clé fournit explicitement `p_conditions => NULL`.
- Le replay retourne exactement le JSON initial et préserve le hash, l'exécution `COMPLETED`, l'offre (`conditions IS NULL`), l'événement `ACTION_SUCCEEDED` et les quatre compteurs de persistance.
- Le scénario SQL ne réalise que les appels à la fonction existante et des assertions de lecture.

## Validation

- Verify job `132496371296` : SUCCESS. Le contrôle statique QA411, npm audit au seuil high, TypeScript, build Next.js et **347/347** tests Playwright ont réussi.
- PostgreSQL 16 job `132496371272` : SUCCESS. Le journal complet contient exactement un marqueur `QA411 PASS`.
- PostgreSQL 17.6 job `132496371245` : SUCCESS. Le journal complet contient exactement un marqueur `QA411 PASS`.
- Les deux jobs complets ont aussi réussi l'intégration CREATE_OFFER/concurrence, le repeat-guard, les caractérisations catalogue/replication slots/paramètres/extensions, les privilèges du runner, les contrôles RLS/ACL et les assertions de nettoyage.
- Les deux jobs négatifs de simulation du nettoyage ont produit leurs échecs attendus ; leurs jobs d'assertion ont réussi. Le job volontairement skipped et son assertion ont produit le résultat attendu.
- CodeQL #1391 : SUCCESS.
- Le statut combiné Vercel sur ce HEAD est FAILURE avec la cible `build-rate-limit`. C'est une limitation de capacité du fournisseur ; ce statut ne démontre pas un échec de compilation applicative.

## Sécurité et limites

- L'exécution runtime utilise uniquement les services PostgreSQL jetables 16/17.6 de GitHub Actions et le `DATABASE_URL` loopback.
- Aucune donnée, migration, politique RLS, permission, secret ou configuration PostgreSQL persistante de Supabase Production n'a été modifiée.
- Aucun déploiement Production, merge de PR, force-push ou changement de protection n'a été effectué.
- Cette régression caractérise le défaut d'argument PostgreSQL existant ; elle ne constitue pas une constatation de vulnérabilité Production.
- Le modèle métier de propriété demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à approbation.

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


## Follow-up QA425 — fixture input label correction

- Une relecture du fichier `tests/sql/create-offer-geography-default-replay.sql` a trouvé que la valeur JSON de `v_input` utilisait encore le libellé `qa412-market-default-replay` dans le bloc QA413.
- Cette valeur ne changeait pas le paramètre testé `p_geography` ni le comportement du replay, mais elle rendait les traces de fixture trompeuses.
- QA425 corrige le libellé en `qa413-geography-default-replay` et renforce le contrôle statique existant pour exiger la valeur exacte et refuser l'ancien libellé dans le bloc QA413.
- Le résultat runtime antérieur QA413 reste valide pour le contrat d'omission/replay ; QA425 a revalidé le fixture corrigé sur PostgreSQL 16 et 17.6 dans QIMA CI #1483.


## QA425 validation — corrected fixture on QIMA CI #1483

- QIMA CI [#1483](https://github.com/meridane/QimaTrade-MVP/actions/runs/43684750243) completed with conclusion **SUCCESS** on HEAD `4f35e3424d7beee21ab3a2e06a7fdb7850338408`.
- Verify job `132723980558` completed successfully; the journal contains exactly one `QA413 static contract PASS`. npm audit at the high threshold, TypeScript, Next.js build, Chromium installation and Playwright **347/347** also succeeded.
- PostgreSQL 16 job `132723980516` completed successfully; the journal contains exactly one `QA413 PASS` for the corrected geography-default fixture.
- PostgreSQL 17.6 job `132723980262` completed successfully; the journal contains exactly one `QA413 PASS` for the corrected geography-default fixture.
- CodeQL [#1418](https://github.com/meridane/QimaTrade-MVP/actions/runs/43684750307) completed successfully.
- The combined Vercel status is failure with target `build-rate-limit`; the Vercel bot reported the provider's daily deployment quota. This is not a failed Next.js build: the GitHub Actions production build succeeded.
- QA425 is therefore **CLOSED**. The correction remains limited to fixture identity and static-contract diagnostics; it does not change SQL behavior or business rules.

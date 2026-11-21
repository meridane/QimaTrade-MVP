# QIMA V1 Function Register — QA416

## QA416 — omission de p_offer_type et replay avec NULL explicite

**Statut : CLOSED — QIMA CI [#1468](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644843255) SUCCESS ; PostgreSQL 16/17.6 et les marqueurs runtime QA416 confirmés. CodeQL [#1403](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644843266) SUCCESS.
**Target :** PR #26, branche `fix/create-offer-status-contract`.
**Branche de travail :** `work/qa416-offer-type-default-replay-20261115-0514`.
**Commit de base :** `406485815a0560a2f11ddb435186f124b69e26b5`.

## Portée
- Caractériser la signature existante `p_offer_type text DEFAULT NULL::text`, sans modifier la migration ni introduire de taxonomie métier.
- Le premier appel CREATE_OFFER dans `tests/sql/create-offer-runtime.sql` omet réellement l'argument nommé `p_offer_type`.
- Le replay avec le même tenant et la même clé fournit explicitement `p_offer_type => NULL`.
- Tous les autres paramètres effectifs restent identiques, notamment `p_lifecycle => NULL`, `p_documentation_status => NULL`, `p_geography => NULL`, `p_market => 'fixture-market-stable'`, `p_attributes => '{}'::jsonb` et `p_pricing_model => 'fixture-pricing-model-stable'`.
- Le test exige le résultat JSON exact, le hash inchangé, l'exécution `COMPLETED`, `offers.offer_type IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans les quatre tables de persistance.
- Le nouveau contrôle statique vérifie le défaut de signature, le mapping du hash, le forwarding, l'omission réelle du premier appel, le NULL explicite du replay, l'identité des autres paramètres, les assertions read-only et le wiring Verify/PostgreSQL 16/PostgreSQL 17.6.
- Le scénario runtime est intégré à `create-offer-runtime.sql`, déjà exécuté par les runners PostgreSQL 16 et 17.6. Aucun changement du runner n'est nécessaire.

## Validation
- Prérequis QA415 : CLOSED sur QIMA CI [#1449](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745260), avec exactement un marqueur `QA415 PASS` dans chacun des journaux PostgreSQL 16 et 17.6 ; Verify, Playwright 347/347 et CodeQL #1396 ont réussi.
- Le contrôle statique QA416 est ajouté au nouveau script `tests/sql/test-create-offer-offer-type-default-replay-contract.sh`.
- Le workflow Verify exécute ce script une fois ; les deux jobs PostgreSQL exécutent le scénario runtime via le runner existant.
- La validation QA416 sera consignée après le déclenchement CI sur le nouveau HEAD. Aucun résultat runtime QA416 n'est revendiqué avant cette exécution.

## Sécurité et limites
- Le test utilise uniquement les fixtures PostgreSQL temporaires de CI.
- La valeur NULL synthétique caractérise le défaut SQL ; elle ne définit ni n'approuve une taxonomie métier d'offer type.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, RLS ou paramètre PostgreSQL persistant n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Ce test caractérise l'équivalence du défaut SQL et ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à une approbation métier explicite.


## Revue finale avant validation CI
- La relecture du scénario a détecté que le paramètre non ciblé `p_lifecycle` devait rester explicitement stable dans les deux appels. Le commit `da3ec87ecd1e5df2c5c2d7388e2c021e22f85b53` ajoute `p_lifecycle => NULL` aux deux appels ; seul `p_offer_type` diffère désormais par omission versus NULL explicite.
- Prévalidation structurale sur le HEAD `da3ec87ecd1e5df2c5c2d7388e2c021e22f85b53` : défaut de signature, mapping du hash, forwarding, omission du premier argument, replay NULL, égalité des autres paramètres, assertions de persistance et absence de DML direct vérifiés.
- CodeQL [#1397](https://github.com/meridane/QimaTrade-MVP/actions/runs/43636740480) a terminé SUCCESS sur le HEAD précédent `c71bd5a7cf3a039c807024b22757e9f4a58a439b` ; ce résultat n'est pas présenté comme une analyse du commit correctif `da3ec87`.
- Cette observation concernait le HEAD précédent et est remplacée par la revalidation documentée ci-dessous.

## Revalidation on code/workflow HEAD 636acbca15a57832b97bbbe06cdcaa9c301e1850

- QIMA CI [run 43644473687](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644473687) is still IN_PROGRESS at this update.
- Verify job `132599046989` completed SUCCESS. The logs contain exactly one `QA416 static contract PASS` and one `QA417 static contract PASS`; npm audit at the high threshold, TypeScript, Next.js production build and Playwright **347/347** also succeeded.
- PostgreSQL 16 job `132599046809`: the CREATE_OFFER integration/concurrency runner step completed SUCCESS; the separate product-master, attributes, conditions, market and geography replay steps also completed SUCCESS. The full runner-privilege, RLS/ACL and cleanup tail remains in progress.
- PostgreSQL 17.6 job `132599047040`: the CREATE_OFFER integration/concurrency runner step and the same separate replay steps completed SUCCESS; the full runner-privilege, RLS/ACL and cleanup tail remains in progress.
- QA416 and QA417 runtime blocks are both in `create-offer-runtime.sql`, executed by the successful integration runner step on each version. Exact `QA416 PASS` / `QA417 PASS` marker counts are not claimed until the complete job logs are available.
- CodeQL [run 43644473682](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644473682) completed SUCCESS. The combined Vercel status on this code/workflow HEAD is SUCCESS.
- This appendix-only update does not alter the code/workflow HEAD validated by the active QIMA CI run.


## Validation finale — QIMA CI #1468 (15 novembre 2026)

- QIMA CI [run 43644843255](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644843255) : SUCCESS sur le HEAD 491a2de0fc7f46faf21815c75bb4ad1d17486343.
- Verify job 132600980210 : SUCCESS ; exactement un marqueur statique QA416 PASS et un QA417 PASS ; npm audit high, TypeScript, build Next.js et Playwright 347/347 réussis.
- PostgreSQL 16 job 132600980596 : SUCCESS ; exactement un marqueur runtime QA416 PASS et QA417 PASS. Les marqueurs QA414 et QA415 apparaissent également exactement une fois chacun.
- PostgreSQL 17.6 job 132600980578 : SUCCESS ; exactement un marqueur runtime QA416 PASS et QA417 PASS. Les marqueurs QA414 et QA415 apparaissent également exactement une fois chacun.
- Les deux jobs ont terminé les contrôles complets CREATE_OFFER/concurrence, catalogue, replication slots, paramètres, extensions, privilèges du runner, RLS, ACL et nettoyage.
- Les simulations négatives du nettoyage ont produit leurs échecs attendus et leurs assertions ont réussi ; le job volontairement skipped a été correctement reconnu.
- CodeQL [run 43644843266](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644843266) : SUCCESS.
- Vercel combiné indique build-rate-limit ; le build Next.js Verify a néanmoins réussi. Aucune erreur de compilation n'est déduite de cette limitation fournisseur.
- QA416 est CLOSED : l'omission de p_offer_type et le replay explicite NULL préservent exactement le hash, le résultat et les quatre tables de persistance.

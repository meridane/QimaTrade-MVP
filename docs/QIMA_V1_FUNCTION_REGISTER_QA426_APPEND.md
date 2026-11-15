# QIMA V1 Function Register — QA426

## QA426 — correct and protect CREATE_OFFER default-replay diagnostics

**Statut : CLOSED — QIMA CI [#1484](https://github.com/meridane/QimaTrade-MVP/actions/runs/43690898637), Verify job `132741139490` SUCCESS sur le HEAD `c4648fc1aefd473126c79ac257fa66d4330925f1`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**HEAD de base :** `4f35e3424d7beee21ab3a2e06a7fdb7850338408`.  
**Branche de travail :** `work/qa426-geography-default-diagnostics-20261115-1635`.

## Constat et portée
- Le contrat statique QA413 utilisait encore le diagnostic `runtime is missing the QA413 market-default replay block`, alors que le bloc cible `p_geography`.
- Son diagnostic de paramètres identiques disait `all non-market effective parameters`, ce qui désignait le mauvais paramètre.
- Le contrôle d'existence du bloc était exécuté après l'extraction de `INPUT_LINE` ; il est maintenant effectué immédiatement après l'extraction du bloc, afin de produire le diagnostic le plus précis si le bloc manque.
- QA426 corrige ces deux diagnostics en `geography` et ajoute `tests/sql/test-create-offer-default-replay-diagnostics-contract.sh`.
- Le nouveau contrôle vérifie que QA410, QA411, QA412 et QA413 identifient chacun leur propre paramètre dans les diagnostics de bloc manquant et de paramètres non ciblés.
- Le nouveau contrôle vérifie également que QA413 vérifie l'existence du bloc avant de lire sa ligne `v_input`.
- Le script est intégré une seule fois au job Verify, immédiatement après le contrôle statique QA413. Aucun nouveau job PostgreSQL ni modification de migration n'est nécessaire.

## Validation définitive du périmètre QA426 — QIMA CI #1484
- QIMA CI [#1484](https://github.com/meridane/QimaTrade-MVP/actions/runs/43690898637) : **SUCCESS** sur le HEAD de code `c4648fc1aefd473126c79ac257fa66d4330925f1`.
- Verify job `132741139490` : SUCCESS ; exactement un marqueur `QA426 static contract PASS`.
- PostgreSQL 16 job `132741139537` : SUCCESS ; exactement un marqueur runtime `QA413 PASS`.
- PostgreSQL 17.6 job `132741139574` : SUCCESS ; exactement un marqueur runtime `QA413 PASS`.
- npm audit au seuil high, TypeScript, build Next.js, installation Chromium et Playwright **347/347** : SUCCESS.
- CodeQL [#1419](https://github.com/meridane/QimaTrade-MVP/actions/runs/43690898685) : SUCCESS. Le statut combiné Vercel sur le HEAD de code : SUCCESS.
- Le commit documentaire `e72e2af3` a déclenché QIMA CI [#1485](https://github.com/meridane/QimaTrade-MVP/actions/runs/43691351096), désormais **SUCCESS** : Verify job `132742742902` SUCCESS avec exactement un marqueur `QA426 static contract PASS` ; PostgreSQL 16 job `132742742857` SUCCESS avec exactement un marqueur `QA413 PASS` ; PostgreSQL 17.6 job `132742742859` SUCCESS avec exactement un marqueur `QA413 PASS`. npm audit au seuil high, TypeScript, build Next.js, Chromium et Playwright **347/347** : SUCCESS. CodeQL [#1420](https://github.com/meridane/QimaTrade-MVP/actions/runs/43691351183) et Vercel : SUCCESS.
- Le HEAD de PR `57f1cef017bed7298cc4b75a4f0b8988db901b94` a été validé par QIMA CI [#1486](https://github.com/meridane/QimaTrade-MVP/actions/runs/43691555270), **SUCCESS** : Verify job `132744382154` SUCCESS avec exactement un marqueur `QA426 static contract PASS` ; PostgreSQL 16 job `132744382183` SUCCESS avec exactement un marqueur `QA413 PASS` ; PostgreSQL 17.6 job `132744382170` SUCCESS avec exactement un marqueur `QA413 PASS`. npm audit au seuil high, TypeScript, build Next.js, Chromium et Playwright **347/347** : SUCCESS. CodeQL [#1421](https://github.com/meridane/QimaTrade-MVP/actions/runs/43691555275) et Vercel : SUCCESS.
- Les commits `e72e2af3` et `57f1cef0` ne modifient que `docs/**` ; la validation #1486 porte le HEAD exact de la PR sans changement du code QA426 depuis le HEAD de code `c4648fc1aefd473126c79ac257fa66d4330925f1`.
- QA426 est **CLOSED** sur son périmètre statique : aucun nouveau scénario runtime n'a été ajouté, et son contrôle dédié ainsi que l'intégralité de QIMA CI #1484 ont réussi.

## Sécurité et limites
- QA426 modifie uniquement les diagnostics d'un test shell et ajoute un contrôle statique de cohérence.
- Aucun SQL runtime, fonction, migration, hash, statut, règle métier ou donnée applicative n'est modifié.
- Aucun DML direct, aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Il s'agit d'une amélioration de qualité des tests, pas d'un constat de vulnérabilité.

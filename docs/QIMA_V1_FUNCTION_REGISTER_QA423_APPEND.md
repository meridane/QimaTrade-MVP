# QIMA V1 Function Register — QA423

## QA423 — all supported currency codes are accepted, persisted and exactly replayed

**Statut : CLOSED — QIMA CI #1479 SUCCESS sur le HEAD `981f57442441619bac0bb597560000e2e66f9d18`.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit validé :** `981f57442441619bac0bb597560000e2e66f9d18`.  
**Branche de travail :** `work/qa423-supported-currency-acceptance-20261115-1342`.

## Portée
- La whitelist exacte de la migration — `USD`, `EUR`, `KRW`, `MAD` et `CNY` — est caractérisée positivement.
- Chaque devise a été acceptée, persistée avec son code exact et rejouée avec la même clé sans créer de doublons.
- Le replay a conservé le JSON de résultat et le request hash originaux.
- Les quatre tables `idempotency_keys`, `action_executions`, `offers` et `action_events` ont conservé une seule ligne cohérente par clé et devise.

## Validation définitive
- QIMA CI [#1479](https://github.com/meridane/QimaTrade-MVP/actions/runs/43678170735) : **SUCCESS** sur le HEAD `981f5744`.
- Verify job `132702790629` : SUCCESS ; exactement un marqueur `QA423 static contract PASS`.
- PostgreSQL 16 job `132702790819` : SUCCESS ; exactement un marqueur runtime `QA423 PASS`.
- PostgreSQL 17.6 job `132702790889` : SUCCESS ; exactement un marqueur runtime `QA423 PASS`.
- npm audit au seuil high : SUCCESS. TypeScript : SUCCESS. Build Next.js : SUCCESS. Playwright : **347/347**.
- CodeQL [#1414](https://github.com/meridane/QimaTrade-MVP/actions/runs/43678170697) : SUCCESS.
- Statut combiné Vercel sur le HEAD `981f5744` : SUCCESS ([Preview](https://vercel.com/bmk1/qimatrade-mvp/8f7Qc1jjBBFxGKV9c7Qm1CUnCTsX)).
- Les deux jobs de simulation négative du nettoyage ont présenté leurs échecs attendus ; les jobs d'assertion correspondants ont réussi. Le job de nettoyage volontairement skipped a été reconnu comme tel. La conclusion globale de QIMA CI reste SUCCESS.

## Limites et sécurité
- Le runtime utilise le wrapper et les fixtures synthétiques de CI jetable ; il ne constitue pas une preuve directe de la fonction basse couche déployée en production ni un constat de vulnérabilité.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

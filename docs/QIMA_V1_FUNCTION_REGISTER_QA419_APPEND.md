# QIMA V1 Function Register — QA419

## QA419 — provider actor mismatch rejected before idempotency lookup

**Statut : CLOSED — QIMA CI #1471 SUCCESS sur le HEAD corrigé.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `474e628176a4889f8daaa6f71c0a4d96675cbf68`.  
**Commit correctif validé :** [`ab4b8842cfe012704f4f231401c282a59d3451db`](https://github.com/meridane/QimaTrade-MVP/commit/ab4b8842cfe012704f4f231401c282a59d3451db).

## Portée
- Caractériser l'ordre déjà présent dans `execute_create_offer_v1` : l'identité d'acteur est résolue depuis `auth.uid()`, puis `p_provider_actor_id` est comparé à cet acteur avant le calcul du hash et la lecture de la clé d'idempotence.
- Créer une offre initiale avec l'utilisateur synthétique A, le tenant A et le provider actor A.
- Réutiliser exactement le même tenant, la même clé d'idempotence et tous les autres paramètres, mais fournir le provider actor B tout en conservant le JWT subject de l'utilisateur A.
- Le replay doit retourner exactement `INVALID_PROVIDER_ACTOR`, avant toute consultation du hash/idempotency record.
- Vérifier que le hash, le résultat JSON, l'acteur, l'exécution `COMPLETED`, `offers.provider_actor_id`, l'événement `ACTION_SUCCEEDED` et les quatre compteurs de persistance restent inchangés.
- Le contrôle statique vérifie l'ordre profile lookup → provider actor guard → hash → idempotency lookup → persistence, les deux profils du fixture, la stabilité de tous les autres paramètres, l'absence de DML direct et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.

## Historique de validation
- Première tentative QIMA CI [#1470](https://github.com/meridane/QimaTrade-MVP/actions/runs/43654482580) : Verify a correctement échoué parce que le contrôle statique exigeait une comparaison explicite du hash après replay. Les deux premières étapes SQL QA419 avaient réussi sur PostgreSQL 16 et 17.6, mais ces succès isolés ne validaient pas le job complet.
- Correctif [`ab4b8842`](https://github.com/meridane/QimaTrade-MVP/commit/ab4b8842cfe012704f4f231401c282a59d3451db) : ajoute `v_replay_hash`, lit `request_hash` dans la même vérification read-only que l'acteur/exécution/résultat et exige `v_replay_hash IS NOT DISTINCT FROM v_original_hash`. Le hash n'est plus relu dans une assertion séparée qui ne pouvait pas comparer la valeur initiale.
- QIMA CI [#1471](https://github.com/meridane/QimaTrade-MVP/actions/runs/43654514471) : **run global SUCCESS** sur le HEAD `ab4b8842`.
- Verify job `132631708552` : SUCCESS ; exactement un marqueur `QA419 static contract PASS`. npm audit (seuil high), TypeScript, build Next.js et Playwright **347/347** ont réussi.
- PostgreSQL 16 job `132631708797` : SUCCESS ; exactement un marqueur runtime `QA419 PASS`.
- PostgreSQL 17.6 job `132631708875` : SUCCESS ; exactement un marqueur runtime `QA419 PASS`.
- Les caractérisations complètes des privilèges du runner, RLS, ACL, concurrence et nettoyage ont réussi dans les deux environnements. Les jobs de simulation négative du nettoyage ont conservé leurs échecs attendus et leurs assertions dédiées ont réussi ; le job volontairement skipped a été reconnu comme tel.
- CodeQL [#1406](https://github.com/meridane/QimaTrade-MVP/actions/runs/43654514480) : SUCCESS. Statut combiné Vercel sur le HEAD `ab4b8842` : SUCCESS.
- La validation QA419 est donc clôturée sur preuves statiques et runtime des deux versions PostgreSQL.

## Limites métier et sécurité
- Ce test caractérise un garde-fou d'identité déjà présent ; il ne change aucune règle métier et ne prétend pas résoudre l'autorisation demand/tenant.
- L'acteur B est un profil synthétique existant dans le fixture jetable ; aucun compte ni membership de production n'est créé.
- Aucun constat de vulnérabilité n'est déduit du scénario synthétique.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

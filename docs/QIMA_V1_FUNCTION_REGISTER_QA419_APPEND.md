# QIMA V1 Function Register — QA419

## QA419 — provider actor mismatch rejected before idempotency lookup

**Statut : IMPLEMENTED — test runtime et contrôle statique ajoutés ; validation CI en attente.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Branche de travail :** `work/qa419-provider-actor-guard-replay-20261115-0837`.  
**Commit de base :** `474e628176a4889f8daaa6f71c0a4d96675cbf68`.

## Portée
- Caractériser l'ordre déjà présent dans `execute_create_offer_v1` : l'identité d'acteur est résolue depuis `auth.uid()`, puis `p_provider_actor_id` est comparé à cet acteur avant le calcul du hash et la lecture de la clé d'idempotence.
- Créer une offre initiale avec l'utilisateur synthétique A, le tenant A et le provider actor A.
- Réutiliser exactement le même tenant, la même clé d'idempotence et tous les autres paramètres, mais fournir le provider actor B tout en conservant le JWT subject de l'utilisateur A.
- Le replay doit retourner exactement `INVALID_PROVIDER_ACTOR`, avant toute consultation du hash/idempotency record.
- Vérifier que le hash, le résultat JSON, l'acteur, l'exécution `COMPLETED`, `offers.provider_actor_id`, l'événement `ACTION_SUCCEEDED` et les quatre compteurs de persistance restent inchangés.
- Le contrôle statique vérifie l'ordre profile lookup → provider actor guard → hash → idempotency lookup → persistence, les deux profils du fixture, la stabilité de tous les autres paramètres, l'absence de DML direct et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.

## Limites métier et sécurité
- Ce test caractérise un garde-fou d'identité déjà présent ; il ne change aucune règle métier et ne prétend pas résoudre l'autorisation demand/tenant.
- L'acteur B est un profil synthétique existant dans le fixture jetable ; aucun compte ni membership de production n'est créé.
- Aucun constat de vulnérabilité n'est déduit du scénario synthétique.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

## Validation
- QA418 est CLOSED sur QIMA CI [#1469](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436722) : Verify, PostgreSQL 16 et PostgreSQL 17.6 SUCCESS ; exactement un marqueur QA418 PASS par version.
- QA419 sera considéré validé uniquement après un nouveau run sur le HEAD publié, le passage du contrôle statique et exactement un marqueur runtime QA419 PASS dans chacun des journaux PostgreSQL 16 et 17.6.

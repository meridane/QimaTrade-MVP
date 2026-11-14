# QIMA V1 Function Register — QA418

## QA418 — changement de p_demand_id lors d'un replay

**Statut : IMPLEMENTED — prévalidation structurelle terminée ; CI déclenchée après publication, validation runtime en attente.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Branche de travail :** `work/qa418-demand-id-mismatch-20261115-0811`.  
**Commit de base :** `491a2de0fc7f46faf21815c75bb4ad1d17486343`.

## Portée
- Caractériser le mapping existant 'demandId', p_demand_id dans le hash CREATE_OFFER, sans modifier la migration.
- Réutiliser les deux demandes synthétiques valides déjà seedées dans les fixtures jetables : la demande originale du schéma et la demande alternate publiée ajoutée par create-offer-runtime.sql.
- Le premier appel utilise la demande 50000000-0000-4000-8000-000000000001 ; le replay utilise la demande 50000000-0000-4000-8000-000000000002, avec le même tenant et la même clé.
- Le paramètre p_product_master_id et tous les autres paramètres effectifs restent identiques.
- Le replay modifiant uniquement p_demand_id doit produire exactement IDEMPOTENCY_KEY_REUSE.
- Vérifier que le hash, le résultat JSON, l'exécution COMPLETED, offers.demand_id, l'événement ACTION_SUCCEEDED et les compteurs des quatre tables de persistance conservent l'état initial.
- Le contrôle statique vérifie le mapping du hash, le forwarding, les deux demandes des fixtures, la différence limitée à p_demand_id, les assertions read-only et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.

## Limites métier et sécurité
- Ce test vérifie uniquement l'idempotence lorsque l'identifiant de demande change ; il ne teste pas l'appartenance d'une demande à un tenant ni l'autorisation d'utiliser cette demande.
- Le modèle d'autorisation demand/tenant reste séparément soumis à une décision métier explicite. Aucune conclusion de vulnérabilité n'est tirée de ce test synthétique.
- Les demandes et les données créées sont confinées aux fixtures PostgreSQL jetables.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou paramètre PostgreSQL persistant n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.

## Validation
- QA416 et QA417 sont CLOSED sur QIMA CI [#1468](https://github.com/meridane/QimaTrade-MVP/actions/runs/43644843255), avec Verify, PostgreSQL 16 et PostgreSQL 17.6 SUCCESS et exactement un marqueur runtime de chaque dossier par version.
- Le contrôle statique QA418 et ses deux étapes runtime seront validés par le nouveau run QIMA CI déclenché par le commit de cette branche.
- CodeQL #1403 est SUCCESS ; le statut combiné Vercel du HEAD antérieur indique build-rate-limit, tandis que le build Next.js Verify est réussi.

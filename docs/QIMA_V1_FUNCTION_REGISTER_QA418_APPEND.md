# QIMA V1 Function Register — QA418

## QA418 — changement de p_demand_id lors d'un replay

**Statut : CLOSED — QIMA CI [#1469](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436722) SUCCESS ; Verify, PostgreSQL 16 et PostgreSQL 17.6 terminés, exactement un marqueur QA418 PASS par version. CodeQL [#1404](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436705) SUCCESS ; Vercel SUCCESS.**  
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
- QIMA CI [#1469](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436722) : Verify job `132623653620` SUCCESS ; npm audit high, TypeScript, build Next.js et Playwright 347/347 réussis.
- PostgreSQL 16 job `132623653455` et PostgreSQL 17.6 job `132623653677` : SUCCESS ; exactement un marqueur QA418 PASS dans chaque journal complet. QA416 et QA417 apparaissent également exactement une fois par version.
- Les deux jobs ont terminé les caractérisations complètes CREATE_OFFER, concurrence, privilèges, RLS, ACL et nettoyage. Les simulations négatives ont produit les échecs attendus et leurs assertions ont réussi ; le job volontairement skipped a été correctement reconnu.
- CodeQL [#1404](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436705) SUCCESS ; statut combiné Vercel SUCCESS sur le HEAD QA418.


## Validation finale — QIMA CI #1469 (15 novembre 2026)

- QIMA CI [run 43652436722](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436722) : SUCCESS sur le HEAD `474e628176a4889f8daaa6f71c0a4d96675cbf68`.
- Verify job `132623653620` : SUCCESS ; npm audit high, TypeScript, build Next.js et Playwright 347/347 réussis.
- PostgreSQL 16 job `132623653455` : SUCCESS ; exactement un marqueur runtime QA416 PASS, QA417 PASS et QA418 PASS dans le journal complet.
- PostgreSQL 17.6 job `132623653677` : SUCCESS ; exactement un marqueur runtime QA416 PASS, QA417 PASS et QA418 PASS dans le journal complet.
- Les deux jobs ont terminé les contrôles complets CREATE_OFFER/concurrence, catalogue, replication slots, paramètres, extensions, privilèges du runner, RLS, ACL et nettoyage.
- Les simulations négatives du nettoyage ont produit leurs échecs attendus et leurs assertions ont réussi ; le job volontairement skipped a été correctement reconnu.
- CodeQL [run 43652436705](https://github.com/meridane/QimaTrade-MVP/actions/runs/43652436705) : SUCCESS. Le statut combiné Vercel sur le HEAD QA418 est SUCCESS.
- QA418 est CLOSED : changer uniquement `p_demand_id` avec le même tenant et la même clé provoque `IDEMPOTENCY_KEY_REUSE` et préserve le hash, le résultat, l'exécution, l'offre et l'événement initial.

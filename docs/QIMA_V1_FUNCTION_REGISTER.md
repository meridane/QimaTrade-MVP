# QIMA Trade — Registre des fonctionnalités V1 et audit de départ

Dernière vérification du code distant : 27 octobre 2026  
Dépôt : `meridane/QimaTrade-MVP`  
Branche examinée : `fix/create-offer-status-contract`  
PR #26 : ouverte, en brouillon, non fusionnée  
Commit examiné : `54dec2d3f255b04319416e2279429dcd7522f168`

> Ce registre distingue les éléments présents dans le dépôt, ceux constatés en base et ceux réellement testés. La présence d'une route ou d'une fonction ne prouve pas que le comportement métier est validé.

## Mise à jour de suivi — 27 octobre 2026

### OFFER-01 / ACTION-01 — Statut SQL de CREATE_OFFER

- **État : À TESTER — Security Gate NOT PASS.**
- Fichier proposé : `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- La fonction proposée écrit `RUNNING` / `COMPLETED` dans `action_executions` et `IN_PROGRESS` / `COMPLETED` dans `idempotency_keys`, tandis que le résultat externe conserve `status: succeeded`.
- Le hash d'idempotence couvre `p_input` et les paramètres métier effectifs.
- Risques non levés : autorisation de la demande par tenant, profil acteur obtenu par `LIMIT 1`, comportement des appels concurrents partageant une nouvelle clé et contrat précis des états en échec.
- Aucun test runtime SQL de cette fonction n'est présent dans les contrôles CI constatés. Aucune migration de cette PR n'a été appliquée en production.

### CI-REGRESSION-01 — Workflows PR #26

Résultats des exécutions associées au commit de la PR :

| Contrôle | Exécution | Résultat |
|---|---:|---|
| QIMA CI | `40355755095` | SUCCESS |
| Installation dépendances | étape CI | SUCCESS |
| Audit dépendances npm | étape CI | SUCCESS |
| TypeScript | étape CI | SUCCESS |
| Build production | étape CI | SUCCESS |
| Installation Playwright Chromium | étape CI | SUCCESS |
| Tests navigateur smoke | étape CI | SUCCESS |
| QIMA CodeQL Security | `40355755332` | SUCCESS |

Ces contrôles passent, mais ne valident pas l'exécution PostgreSQL de `execute_create_offer_v1`, les conflits d'idempotence concurrente ou les cas négatifs multi-tenant.

### ARCH-OFFER-01 — Deux chemins de création

- `app/api/offers/route.ts` insère directement dans `public.offers`.
- `app/api/actions/create-offer/route.ts` passe par `executeUniversalAction`.
- `app/offers/actions.ts` passe également par le Universal Action Runtime.
- **État : À CORRIGER / À TESTER.** Unifier sans retirer la compatibilité de formulaire et de redirection existante.

### SEC-TENANT-01 — Sélection du tenant

- `app/api/actions/create-offer/route.ts` et `app/offers/actions.ts` utilisent `dt_memberships ... LIMIT 1`.
- **État : RISQUE CONFIRMÉ DANS LE CODE, EXPLOITABILITÉ NON DÉMONTRÉE.** Un utilisateur à appartenances multiples peut recevoir une sélection arbitraire. Le flux doit utiliser un tenant de contexte explicite ou refuser l'ambiguïté.

### SEC-DEMAND-01 — Autorisation de la demande

- La migration vérifie l'existence de `p_demand_id`, mais la garde SQL visible ne lie pas explicitement la demande au tenant actif ni à une règle d'autorisation métier.
- **État : À TESTER / BLOQUANT POUR LE SECURITY GATE** jusqu'à documentation du modèle de propriété et tests négatifs isolés.

### QA-OFFER-01 — Plan de régression

Le plan est ajouté à `docs/CREATE_OFFER_REGRESSION_SECURITY_PLAN.md`. Il recense les scénarios de statuts, idempotence, concurrence, tenant isolation, validation serveur et journalisation.

## Règle de sécurité

**Security Gate : NOT PASS.** CI et CodeQL sont verts, mais les tests SQL/runtime, l'isolation multi-tenant et la concurrence ne sont pas encore validés. Ne pas fusionner, appliquer en production ni déployer sur la seule base des contrôles CI.

## Prochaine action

Créer ou utiliser un environnement PostgreSQL/Supabase jetable et exécuter la matrice de régression ciblée. Après validation, traiter l'autorisation demande-tenant, puis unifier les chemins de création et la sélection du tenant avec des tests de régression.

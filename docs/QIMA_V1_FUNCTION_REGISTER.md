# QIMA Trade — Registre des fonctionnalités V1 et audit de départ

Dernière vérification : 28 octobre 2026 09:18 KST
Dépôt : meridane/QimaTrade-MVP — branche fix/create-offer-status-contract (PR #26, brouillon)
Projet Supabase : `QIMA` (`yyulzlnrfcbaxovzjbnh`)

> Ce document distingue les éléments **présents dans le dépôt**, les éléments **présents dans Supabase** et les éléments **à tester de bout en bout**. La présence d'une table ou d'une route ne prouve pas que la fonctionnalité est prête pour les utilisateurs.

## 1. État de départ vérifié

### Application
- Stack observée dans `package.json` : Next.js 15.5, React 19, TypeScript, Tailwind CSS, `@supabase/ssr`, `@supabase/supabase-js`.
- Scripts disponibles : `dev`, `build`, `start`, `typecheck`.
- Le dépôt contient des routes pour l'authentification, les arbres de décision, les offres, les demandes de produits, les prestataires et des pages de projet de test.
- Audit à distance seulement : le build et les tests d'intégration n'ont pas été exécutés pendant cet audit.

### Supabase
- Projet en état `ACTIVE_HEALTHY`, PostgreSQL 17.
- Le journal de migrations contient les migrations MVP historiques et les migrations d'architecture QIMA appliquées jusqu'à `qima_event_architecture_v1` (10 octobre 2026).
- Comptes Auth : 3 ; profils `core.profiles` : 3.
- Organisation plateforme : `QIMA Platform` ; un membership actif `SUPERADMIN` a été confirmé pour le compte principal.
- Les profils sont tous marqués `onboarding_status = PENDING` au moment de l'audit : le parcours d'onboarding doit être testé.
- Les tables métier de la nouvelle architecture sont vides au moment de la vérification : publications, demandes, transactions, messages, matchings, politiques, règles, workflows et outbox = 0 ligne chacune.
- Comptage structurel observé : schémas `core` (65 tables), `config` (16), `integration` (10), `audit` (4), `analytics` (3), `lineage` (3), `reference` (14). Le schéma `public` contient aussi 102 tables historiques/MVP : ne pas supprimer sans plan de migration explicite.
- RLS : plusieurs tables de la nouvelle architecture disposent de politiques. L'audit a aussi trouvé 31 tables du schéma `public` avec RLS activé mais sans politique, et 16 objets/tableaux du schéma `auth` sans politique dans le relevé système. Ce point doit être analysé table par table ; ne pas appliquer une politique globale à l'aveugle.
- Les moteurs Policy, Rules, Universal Decision Tree, Workflow Transition et Outbox/Event ont des fonctions SQL installées. Les configurations métier correspondantes sont encore vides.
- L'outbox possède ses fonctions de réservation/complétion/échec, mais aucun worker de production ni consommateur métier n'a été confirmé comme déployé.

## 2. Registre des fonctionnalités

Statuts :
- **PRÉSENT** : route, table ou fonction repérée dans le dépôt/la base.
- **À TESTER** : existence confirmée, comportement réel pas encore validé de bout en bout.
- **À FAIRE** : implémentation ou intégration manquante.
- **BLOQUANT** : doit être résolu avant lancement public.

| ID | Fonctionnalité V1 | État constaté | Prochaine vérification / tâche |
|---|---|---|---|
| AUTH-01 | Connexion Google et callback | PRÉSENT dans le dépôt | Tester connexion, déconnexion, session expirée et callback |
| AUTH-02 | Profil utilisateur et onboarding | PRÉSENT en base | Tester progression, validation téléphone et reprise après interruption |
| AUTH-03 | Rôles et permissions | PRÉSENT en base ; SUPERADMIN confirmé | Tester accès autorisé/refusé avec plusieurs comptes |
| TAX-01 | Domaines, catégories, sous-catégories, Product Master | PRÉSENT dans le schéma public historique et le dépôt | Vérifier données officielles, cohérence des références et accès RLS |
| DT-01 | Arbre de décision MVP | PRÉSENT dans le dépôt et l'historique SQL | Tester une session réelle et sa persistance |
| DT-02 | Arbre de décision universel configurable | PRÉSENT en base | Créer une configuration validée et tester branches, réponses, reprise et actions |
| OFFER-01 | Création et liste d'offres | PRÉSENT dans le dépôt (routes/API) | Tester validation, ownership, statut, pièces jointes et erreurs |
| DEM-01 | Création/qualification des demandes | PRÉSENT dans le dépôt | Tester création, sauvegarde, publication et permissions |
| MATCH-01 | Matching demande ↔ publication | PRÉSENT dans le dépôt et le schéma | Vérifier calcul, explication, doublons et acceptation |
| CHAT-01 | Conversations et messages | PRÉSENT dans le dépôt et le schéma | Tester participants, envoi, lecture, temps réel et isolation |
| TRANS-01 | Transaction entre acheteur et vendeur | PRÉSENT en base, 0 donnée | Implémenter et tester le cycle métier ; QIMA ne conserve pas les fonds |
| SHIP-01 | Demande de transport et suivi | PRÉSENT en base, 0 donnée | Définir transitions et prestataire ; tester informations manuelles/API disponibles |
| SHOW-01 | Showcase (publication produit d'abord, vidéo ensuite) | PRÉSENT en base, à confirmer côté UI | Vérifier séparation showcase/publication/transaction |
| TRUST-01 | Signaux et scores de confiance | PRÉSENT en base | Définir modèle V1, règles d'explication et tests ; aucun score utilisateur validé |
| POLICY-01 | Moteur de politiques | PRÉSENT en base, 0 politique | Ajouter des cas de test puis configurer uniquement les règles métier validées |
| RULE-01 | Moteur de règles | PRÉSENT en base, 0 règle | Tester opérateurs, valeurs absentes et résultat UNKNOWN |
| WF-01 | Définition et évaluation des workflows | PRÉSENT en base, 0 workflow | Configurer les transitions approuvées ; l'évaluateur seul ne modifie pas les objets métier |
| EVENT-01 | Outbox et livraisons consommateurs | PRÉSENT en base, 0 événement | Ajouter worker/consommateurs, retries, DLQ et idempotence ; vérifier supervision |
| NOTIF-01 | Notifications et préférences | PRÉSENT en base, UI/livraison à tester | Tester création, lecture, préférences et livraison |
| ADMIN-01 | Administration utilisateurs/rôles/configuration | PARTIEL | Construire les écrans d'administration et tester les permissions |
| AUDIT-01 | Journal d'audit et historique d'état | PRÉSENT en base | Vérifier écritures automatiques, acteur, horodatage et consultation |
| UI-01 | Tableau de bord utilisateur | PARTIEL / à auditer visuellement | Vérifier design, navigation, états vides, responsive et erreurs |
| UI-02 | Tableau de bord administrateur | À FAIRE / à confirmer | Développer les vues d'administration V1 |
| QA-01 | Tests automatiques et parcours de bout en bout | À FAIRE / non exécutés dans cet audit | Ajouter tests et exécuter `npm run typecheck` + `npm run build` |
| OPS-01 | Déploiement, secrets et observabilité | À TESTER | Vérifier Vercel, variables d'environnement, logs et environnement de production |

## 3. Routes observées dans le dépôt

### Authentification et accueil
- `app/page.tsx`
- `app/login/page.tsx`
- `app/auth/callback/route.ts`

### Arbre de décision
- `app/decision-tree/page.tsx`
- `app/decision-tree/service-provider/page.tsx`
- `app/api/decision-tree/session/route.ts`
- `app/api/decision-tree/answer/route.ts`
- `app/api/decision-tree/products/route.ts`
- `app/api/decision-tree/select-product/route.ts`
- `app/api/decision-tree/service-provider/session/route.ts`

### Offres, demandes et prestataires
- `app/offers/page.tsx`
- `app/offers/new/page.tsx`
- `app/offers/actions.ts`
- `app/api/offers/route.ts`
- `app/api/actions/create-offer/route.ts`
- `app/demands/page.tsx`
- `app/demands/list/page.tsx`
- `app/demands/qualification/page.tsx`
- `app/demands/match/page.tsx`
- `app/demands/conversation/page.tsx`
- `app/api/product-requests/route.ts`
- `app/api/product-requests/publish/route.ts`
- `app/service-provider/page.tsx`
- `app/service-provider/capabilities/page.tsx`
- `app/api/service-provider/me/route.ts`
- `app/api/service-provider/capabilities/route.ts`

### Espace projet de test
- `app/projects/test/page.tsx`
- `app/projects/test/[id]/page.tsx`
- Sous-routes : documents, inspections, orders, payment-requests, payments, shipments.
- À ne pas confondre avec un parcours transactionnel QIMA V1 validé : ces écrans sont explicitement dans l'espace `projects/test`.

### Moteurs serveur repérés
- `lib/actions/*`
- `lib/decision-tree/*`
- `lib/supabase/browser.ts`
- `lib/supabase/server.ts`
- `middleware.ts`

## 4. Ordre d'exécution recommandé

1. **P0 — Sécurité et santé du projet** : auditer les 31 tables `public` sans politique, vérifier le rôle SUPERADMIN et les règles RLS avec tests d'accès. Ne rien supprimer.
2. **P0 — Vérification du code** : exécuter typecheck et build, puis corriger les erreurs bloquantes.
3. **P1 — Premier parcours métier vertical** : connexion → onboarding → créer une publication/offre ou demande → matching → conversation.
4. **P1 — Services métier** : appliquer des transitions validées aux objets métier, avec journal d'audit et événements idempotents.
5. **P1 — Transaction et transport** : cycle de transaction et suivi, sans détention des fonds par QIMA.
6. **P2 — Notifications, tableaux de bord et administration**.
7. **P2 — Tests de sécurité, tests de bout en bout et déploiement V1**.

## 5. Règle de mise à jour de ce registre

Pour chaque modification, mettre à jour la ligne correspondante avec :
- statut : À FAIRE / EN COURS / À TESTER / VALIDÉ / BLOQUANT ;
- fichiers touchés et migration SQL ;
- test exécuté et résultat ;
- date de validation.

Une fonctionnalité n'est **VALIDÉE** qu'après un test réel, pas simplement parce qu'une route, une table ou une fonction existe.


## 6. Point de sécurité P0 — tables `public` sans politique RLS

Au moment de l'audit, les 31 tables suivantes ont RLS activé mais aucune policy PostgreSQL déclarée :
`actors`, `business_objects`, `business_rules`, `capabilities`, `decision_nodes`, `decision_trees`, `domain_events`, `evidence`, `evidence_actors`, `evidence_business_objects`, `evidence_products`, `evidence_profiles`, `evidence_specifications`, `match_evidence`, `object_types`, `opportunities`, `opportunity_matches`, `platform_engines`, `products_archived`, `search_event_business_objects`, `search_event_object_types`, `search_event_products`, `search_events`, `search_keywords`, `services`, `specifications`, `trust_evaluations`, `trust_evidence`, `units`, `workflow_states`, `workflow_transitions`.

**Action requise :** comparer ces tables à la nouvelle architecture et à leur utilisation dans le code. Certaines peuvent être historiques/obsolètes. Ne pas ajouter de policy permissive ni supprimer ces tables avant cette classification. La vérification suivante doit inventorier les grants, les vues/fonctions qui les utilisent et les références dans le dépôt, puis décider pour chaque table : garder et sécuriser / lecture publique contrôlée / archiver après migration.


## 7. Journal d'exécution — 13 octobre 2026

- **CI-01 — Pipeline automatique :** le workflow `.github/workflows/ci.yml` a été corrigé pour ne plus exiger le cache npm en l'absence de lockfile. Le run `38331207042` a réussi : installation des dépendances, `npm run typecheck` et `npm run build` sont tous passés pour le commit correspondant.
- **AUTH-04 — Callback OAuth :** `app/auth/callback/route.ts` a été durci pour refuser les redirections externes, vérifier l'échange du code OAuth et renvoyer vers la connexion si le callback est incomplet ou échoue. Commit : `6032a044f3fb3e18cab1130c0d0065c9f462be7b`. La CI de ce commit est en attente de résultat au moment de la mise à jour ; le correctif n'est donc pas encore marqué VALIDÉ.
- **SEC-RLS-01 — Permissions des tables historiques :** nouvel audit en lecture seule confirme 31 tables `public` avec RLS activé et aucune policy. Pour beaucoup d'entre elles, les rôles `anon` et `authenticated` possèdent aussi des privilèges de table larges, notamment `TRUNCATE` et autres privilèges DDL/DML. L'absence de policy RLS ne protège pas contre certains privilèges comme `TRUNCATE`. **Aucun privilège n'a été modifié pendant cet audit.** Étape suivante : inventorier dépendances, usages applicatifs et besoins légitimes, puis préparer une migration de révocation minimale et testée en environnement de développement.
- **Prochaine action immédiate :** attendre le résultat CI du commit OAuth ; ensuite auditer les permissions des tables utilisées par les parcours V1 et créer un environnement de test isolé avant toute modification de droits ou données.


## 8. Vérification de suivi — 14 octobre 2026

- **CI-01 : VALIDÉ pour le commit de registre courant.** Le run `38343753076` a réussi l'installation, le typecheck et le build. Ce commit inclut le correctif OAuth décrit ci-dessus, donc le code OAuth a été compilé et typechecké dans cette exécution. Cela ne remplace pas un test interactif Google OAuth en conditions réelles.
- **AUTH-04 : code compilé, parcours réel À TESTER.** Le run direct du commit OAuth a été annulé par la concurrence entre pushes successifs ; le commit suivant, qui contient ce code, a réussi la CI.
- **SEC-RLS-02 — Dépendances des tables sans policy :** un inventaire en lecture seule a confirmé que ces tables ne sont pas toutes obsolètes. Exemples : `actors` a 30 clés étrangères entrantes ; `business_objects` en a 12 ; `evidence` en a 8 ; `opportunities` en a 2 ; `products_archived` en a 6 ; `workflow_states` en a 2. Les tables de liaison evidence/match/search ont également des clés étrangères. Elles ne doivent donc pas être supprimées ou archivées sans analyse détaillée.
- **SEC-RLS-03 — Risque de privilèges :** plusieurs rôles `anon` et `authenticated` ont des privilèges de table larges sur des tables sans policy, y compris `TRUNCATE`. L'inventaire est terminé, mais aucun droit n'a été modifié. Il faut préparer une migration ciblée et l'essayer sur une base de développement avant la production.
- **Environnement DEV Supabase :** aucune branche de développement Supabase n'est actuellement enregistrée pour le projet QIMA. La création d'une branche peut entraîner des coûts selon le plan ; ne pas la créer sans confirmation du coût et de l'organisation.
- **Prochaine action :** valider le parcours Google OAuth interactif, puis préparer l'environnement de développement et une migration de permissions limitée aux tables et rôles dont le besoin a été vérifié.


## 8. Automatisation CI quotidienne — 14 octobre 2026

- **AUTO-01 — Vérification planifiée :** le workflow `.github/workflows/ci.yml` est modifié sur la branche `automation/nightly-ci-report` pour s'exécuter chaque jour à 10:00 UTC (19:00 en Corée), à chaque push sur `main`, sur les Pull Requests vers `main` et à la demande.
- **AUTO-02 — Contrôles :** installation des dépendances, audit npm au seuil `high`, contrôle TypeScript et build de production.
- **AUTO-03 — Rapport :** un résumé GitHub Actions indique la date, le déclencheur, la branche, le commit et le résultat de chaque contrôle, y compris si un contrôle échoue.
- **Limites :** l'audit npm est informatif et ne bloque pas le build. Ce workflow contrôle le code présent ; il ne développe pas à lui seul de nouvelles fonctionnalités et ne remplace pas les tests de navigateur.
- **État :** modification commitée sur une branche de travail ; attendre le résultat CI de la Pull Request avant fusion. Aucun changement Supabase ou déploiement de production n'a été effectué.
- **Étape suivante :** ajouter Playwright pour tester les parcours réels de l'application, puis configurer un agent de codage dans un cadre limité aux branches et Pull Requests.


## 9. Tests automatiques du navigateur — 17 octobre 2026

- **AUTO-04 — Playwright :** ajout de `@playwright/test`, du script `npm run test:e2e` et du fichier `playwright.config.ts`.
- **AUTO-05 — Parcours couverts :** affichage de la connexion Google, message d'erreur OAuth compréhensible, et retour vers la connexion lorsque le callback OAuth ne contient pas de code.
- **AUTO-06 — CI :** le workflow installe Chromium, lance les tests contre l'application compilée et ajoute leurs résultats au rapport GitHub Actions.
- **Sécurité :** les tests utilisent des variables Supabase factices et n'écrivent pas dans la base de production. Aucun changement de schéma ou de permissions Supabase.
- **État :** branche `automation/playwright-smoke-tests`; validation CI requise avant fusion. Ces tests couvrent seulement des parcours d'authentification de base, pas le parcours métier complet.
- **Prochaine étape :** corriger tout échec détecté par la CI, puis étendre les tests à la création d'offre/demande, au matching et aux conversations avec des données de test isolées.


## 10. Tests de validation API — 17 octobre 2026

- **AUTO-07 — API offres :** test d'une requête invalide qui doit renvoyer HTTP 400 avant tout accès à la base.
- **AUTO-08 — API demandes produit :** test des champs obligatoires manquants, attendu HTTP 400 avant authentification et accès aux données.
- **AUTO-09 — Publication :** test de l'absence de `requestId`, attendu HTTP 400 avant l'exécution d'une action métier.
- **Sécurité :** ces tests n'envoient que des payloads invalides et doivent s'arrêter avant toute écriture en base.
- **État :** ajout sur la branche `automation/api-validation-tests`; CI à vérifier avant fusion.
- **Limite :** ces tests valident le rejet des entrées invalides ; ils ne prouvent pas que la création, le matching ou les conversations fonctionnent de bout en bout.


## 11. Correctif dépendances npm — 17 octobre 2026

- **SEC-01 — Diagnostic :** l'artefact npm audit du 17 octobre indiquait 6 vulnérabilités élevées et 3 modérées, principalement dans la chaîne CSS/glob.
- **SEC-02 — Correctif proposé :** mise à niveau de PostCSS et overrides ciblés pour `braces`, `fast-glob`, `micromatch`, `postcss` et `postcss-selector-parser`, sans migration majeure immédiate de Tailwind ou Next.js.
- **SEC-03 — Validation :** la CI doit confirmer que les versions résolues sont compatibles, que l'audit passe, et que TypeScript, build et tests Playwright restent verts.
- **État :** Pull Request #5 ouverte ; aucun changement de base de données ou de production. Ne pas fusionner avant résultat CI et vérification de l'audit.


## 12. Migration Tailwind CSS v4 pour corriger la chaîne de dépendances — 18 octobre 2026

- **SEC-04 — Cause confirmée :** le rapport npm audit du run `39044058725` identifie cinq vulnérabilités élevées dans `braces`, `chokidar`, `fast-glob`, `micromatch` et `tailwindcss`. L'avis GitHub GHSA-vfj7-8cjw-p6xm indique que `braces` jusqu'à `3.0.3` est affecté et qu'aucune version corrigée n'est publiée à la date de vérification.
- **SEC-05 — Changement proposé :** migration de Tailwind CSS 3 vers 4.3.3, ajout de `@tailwindcss/postcss`, remplacement de la configuration PostCSS et transfert des tokens QIMA (palette orange et ombre `soft`) dans `app/globals.css`. Suppression des overrides npm qui ne pouvaient pas corriger `braces@3.0.3`.
- **SEC-06 — Portée :** aucun changement métier, aucune migration Supabase, aucun changement d'authentification. Le design est préservé au niveau des tokens, mais doit encore être vérifié par le build et les tests de navigateur.
- **État :** changements commités sur `security/fix-npm-audit`, PR #5. Attendre les résultats CI et l'audit npm actualisé avant fusion.
- **Validation attendue :** audit sans vulnérabilités élevées non résolues, TypeScript, build de production et tests Playwright. Si l'audit reste élevé, inspecter le nouvel artefact au lieu de considérer le correctif comme terminé.
- **Source advisory :** https://github.com/advisories/GHSA-vfj7-8cjw-p6xm


- **SEC-07 — Résultat intermédiaire de l'audit après Tailwind v4 :** le run CI `39046566081` a réussi installation, audit, TypeScript, build et tests Playwright. L'artefact npm audit a ramené le total à **2 vulnérabilités** : 1 modérée (`next`) et 1 élevée (`postcss` imbriqué dans `next/node_modules/postcss`). L'audit n'est donc pas encore entièrement corrigé.
- **SEC-08 — Correctif complémentaire :** ajout d'un override ciblé `next.postcss = ^8.5.23` pour remplacer la version vulnérable imbriquée sans mettre à niveau Next.js vers la version majeure 16. La nouvelle CI doit confirmer la résolution effective avant toute fusion.


## 13. Automatisation de maintenance et sécurité — 19 octobre 2026

- **SEC-09 — Audit npm actuel :** le run planifié `39132895065` sur `main` a terminé avec succès le 18 octobre 2026. Les logs montrent `npm audit` avec **0 vulnérabilité (0 critique, 0 élevée, 0 modérée, 0 faible)**. Ce résultat remplace l'état intermédiaire SEC-07/SEC-08 pour le commit testé `b204cae715fd35095fbc169ab15964d347a92fa9`.
- **CI-02 — Vérification quotidienne :** le run `39132895065` a validé installation, audit npm, TypeScript, build de production, installation de Chromium et tests Playwright. Résultat global : SUCCESS.
- **AUTO-04 — Dependabot proposé :** configuration pour les dépendances npm et GitHub Actions, avec regroupement des mises à jour mineures/patch, au maximum cinq Pull Requests ouvertes par écosystème et programmation le lundi à 19 h 00 (heure coréenne).
- **SEC-10 — CodeQL proposé :** analyse JavaScript/TypeScript à chaque push/PR vers `main`, chaque lundi à 19 h 30 en Corée et à la demande.
- **État mis à jour le 20 octobre 2026 :** la PR #6 a été fusionnée dans `main` (commit `8fdcf11bc9f815237e2b6176531cf126498df063`). Dependabot a commencé à ouvrir des PR de mise à jour et les workflows CodeQL/CI ont été déclenchés sur `main`. Les premières exécutions sur `main` sont encore en attente au moment de cette mise à jour ; surveiller les résultats avant de considérer la chaîne entièrement validée.
- **Limite :** ces mécanismes automatisent la détection et les propositions de mise à jour ; ils ne constituent pas un agent autonome qui développe toutes les fonctionnalités métier de QIMA. Le développement métier automatisé reste la prochaine grande étape.


## 14. Renforcement des tests d'accès — 20 octobre 2026

- **TEST-AUTH-04 :** Playwright vérifie que `/demands`, `/decision-tree`, `/offers` et `/request` redirigent les visiteurs non authentifiés vers `/login` et conservent la destination dans le paramètre `next`.
- **État :** validation CI requise avant fusion.

## 15. Tests de validation des offres — 20 octobre 2026

- **TEST-OFFER-01 :** rejet d'une quantité nulle avant authentification.
- **TEST-OFFER-02 :** rejet d'un prix négatif avant authentification.
- **TEST-OFFER-03 :** rejet d'une devise non prise en charge avant authentification.
- **État :** validation CI requise avant fusion. Aucun changement de logique métier ou de base de données.


## 16. Suivi des mises à jour automatiques — 20 octobre 2026

- **AUTO-05 :** après fusion de la PR #6, Dependabot a ouvert plusieurs PR de dépendances et d'actions GitHub (dont Next.js 16, TypeScript 7, Supabase SSR, CodeQL Action, checkout et upload-artifact).
- **Règle de validation :** ne pas fusionner automatiquement les mises à jour majeures. Elles doivent passer CI et faire l'objet d'une vérification de compatibilité, en particulier Next.js 16 et TypeScript 7.
- **État :** PR Dependabot ouvertes et CI en attente au moment de l'audit ; aucune de ces mises à jour majeures n'est considérée comme intégrée.
- **TEST-AUTH-OFFER-01 :** les tests combinés d'accès protégé et de validation des entrées d'offres sont dans la PR #9 ; la fusion dépend du résultat CI.


## 17. Reprise technique — 27 octobre 2026 — PR #26

- **État de la PR :** ouverte, en brouillon, non fusionnée. Branche `fix/create-offer-status-contract`. La migration reste une proposition non appliquée en production.
- **Fichier SQL examiné :** `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- **Statuts proposés :** `action_executions` reçoit `RUNNING` puis `COMPLETED`; `idempotency_keys` reçoit `IN_PROGRESS` puis `COMPLETED`. Le contrat public reste `status: succeeded`.
- **CI du commit initial de correction :** run `40355755095` SUCCESS. Étapes d'installation, audit npm, TypeScript, build, Playwright Chromium et smoke tests navigateur toutes terminées avec succès.
- **CodeQL du commit initial de correction :** run `40355755332` SUCCESS.
- **Limite de validation :** ces workflows ne prouvent pas que `execute_create_offer_v1` a été exécutée contre PostgreSQL. Une validation SQL isolée reste nécessaire.
- **SEC-OFFER-IDEMPOTENCY-01 : À TESTER.** Le `SELECT ... FOR UPDATE` ne verrouille pas de ligne lorsque la clé n'existe pas encore. Les premières requêtes concurrentes peuvent donc se heurter à la contrainte unique. Vérifier les contraintes réelles et l'absence de doublons par des tests d'intégration.
- **SEC-OFFER-TENANT-01 : À CORRIGER / À TESTER.** La migration vérifie l'appartenance de l'utilisateur au tenant fourni, mais la garde visible ne relie pas explicitement la demande au tenant/contexte autorisé.
- **SEC-OFFER-ACTOR-01 : RISQUE À ÉVALUER.** La fonction SQL sélectionne un acteur via `profiles ... LIMIT 1`. Les fonctions applicatives `app/offers/actions.ts` et `app/api/actions/create-offer/route.ts` sélectionnent elles aussi un tenant via `dt_memberships ... LIMIT 1`. Une identité multi-tenant peut aboutir à un choix arbitraire ; les règles exactes doivent être imposées et testées.
- **ARCH-OFFER-01 : À FAIRE.** `app/api/offers/route.ts` insère directement dans `offers`, alors que `app/api/actions/create-offer/route.ts` et `app/offers/actions.ts` utilisent le Universal Action Runtime. Unifier en préservant validation et redirection du formulaire.
- **Documentation de régression :** `docs/CREATE_OFFER_REGRESSION_SECURITY_PLAN.md` contient les cas requis : statuts, idempotence, concurrence, accès cross-tenant, validation serveur, événements d'audit.
- **Security Gate : NOT PASS.** Ne pas fusionner et ne pas appliquer en production avant exécution réelle des tests SQL/runtime, des tests négatifs multi-tenant et des tests concurrents dans un environnement isolé.
- **Actions de sûreté réalisées pendant cette reprise :** aucune migration appliquée en production, aucune offre créée en production, aucune PR fusionnée.
- **Dernière mise à jour documentaire :** voir `docs/CREATE_OFFER_REGRESSION_SECURITY_PLAN.md` pour les derniers résultats des workflows déclenchés par les commits de documentation. Vérifier les exécutions à nouveau avant toute décision.


## 18. Correction tenant ambigu — 27 octobre 2026

- **Code modifié :** `app/offers/actions.ts` et `app/api/actions/create-offer/route.ts`.
- **Changement :** les deux chemins récupèrent les appartenances du compte et refusent maintenant de choisir arbitrairement un tenant si plusieurs tenants distincts sont présents.
- **Réponse attendue :** l'action serveur renvoie une erreur explicite demandant de sélectionner un tenant ; l'API renvoie HTTP 409 avec `TENANT_SELECTION_REQUIRED`.
- **Limite :** le projet ne possède pas encore ici de sélecteur de tenant confirmé ; les comptes multi-tenant sont donc bloqués sur ces chemins jusqu'à l'implémentation d'un contexte de tenant explicite. C'est volontairement plus sûr qu'une sélection arbitraire, mais cela doit être intégré à l'UX.
- **Validation :** vérification statique des deux fichiers distants après écriture. Aucun test TypeScript, build ou Playwright local n'a été exécuté par cette session. Les workflows GitHub doivent être consultés pour la validation automatisée.
- **Non résolu :** `app/api/offers/route.ts` continue à écrire directement dans `offers`; l'unification avec le Universal Action Runtime reste une tâche distincte. Le contrôle SQL du lien demande/tenant et les tests d'idempotence/concurrence restent requis.


## 19. Audit complémentaire — compatibilité du parcours de création d'offre — 27 octobre 2026

- **Fichier examiné :** `app/api/offers/route.ts`.
- **Constat confirmé :** cette route multipart écrit directement dans `offers` sans passer par le Universal Action Runtime, donc sans sa clé d'idempotence, son suivi `action_executions` ni son événement `ACTION_SUCCEEDED`.
- **Contrat actuel de ce formulaire :** demande facultative, Product Master facultatif, prix facultatif (prix/devise peuvent être nuls pour un brouillon).
- **Contrat SQL de la migration PR #26 :** la fonction refuse un prix nul et exige une demande ainsi qu'un Product Master actif. Un remplacement direct casserait donc des cas que la route actuelle accepte.
- **Autorisation tenant-demande :** le pont `product_requests → demands` examiné crée les demandes avec `requester_actor_id` et un champ `scope` JSON, sans établir de `tenant_id` sur la demande. Il ne faut pas inventer la relation d'autorisation.
- **Décision sûre :** ne pas modifier le SQL de garde et ne pas unifier la route avant validation de la règle métier sur les brouillons, l'obligation d'une demande/Product Master et le propriétaire autorisé d'une demande.
- **Prochaine étape :** formaliser ce contrat, puis écrire des tests PostgreSQL isolés couvrant statuts, idempotence, concurrence, et accès cross-tenant. Aucun test SQL runtime n'a été exécuté dans cette session.
- **État sécurité : NOT PASS.** Aucun déploiement, aucune migration de production et aucune création d'offre en production.


## 20. Correction de concurrence d'idempotence — 27 octobre 2026

- **Décision prise :** sérialiser les appels `CREATE_OFFER` ayant le même tenant et la même clé d'idempotence avec un verrou transactionnel consultatif PostgreSQL, avant la lecture de `idempotency_keys`.
- **Pourquoi :** `SELECT ... FOR UPDATE` ne verrouille aucune ligne si la clé n'existe pas encore. Deux premiers appels simultanés pouvaient donc franchir la lecture avant l'insertion.
- **Fichier modifié :** `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- **Comportement attendu :** les appels avec même tenant/clé sont sérialisés ; la seconde requête peut relire le résultat terminé ou rejeter une réutilisation de clé avec paramètres différents.
- **État :** modification proposée dans la branche de PR uniquement. Pas exécutée contre PostgreSQL et pas appliquée en production.
- **Tests requis :** appels concurrents dans une base jetable, vérification de la portée de l'unicité réelle, absence de doublons et résultat stable lors d'un retry.
- **Toujours bloquant :** règle métier explicite pour la propriété/autorisation d'une demande, compatibilité des offres brouillon sans prix/demande/Product Master, migration de la route `app/api/offers/route.ts` vers le moteur universel.
- **Security Gate : NOT PASS** jusqu'à réussite des tests réels.


## 21. Vérification en lecture seule du schéma Supabase — 27 octobre 2026

- **Aucune écriture exécutée :** vérification limitée à des requêtes SELECT sur le schéma et les fonctions existantes.
- **Idempotence :** l'index unique réel `idempotency_keys_tenant_key_uidx` porte sur `(tenant_id, key)`. La portée du verrou consultatif ajoutée à la PR correspond à cette portée.
- **Contrats de statut :** `action_executions.status` autorise `PENDING/RUNNING/COMPLETED/FAILED/BLOCKED`; `idempotency_keys.status` autorise `IN_PROGRESS/COMPLETED/FAILED`. Les valeurs intermédiaires proposées sont compatibles avec ces CHECK constraints.
- **Profil/acteur :** `profiles.auth_user_id` est unique dans le schéma réel. Le risque de plusieurs lignes de profil pour un même utilisateur n'est donc pas confirmé ; garder le rejet si aucun acteur n'est lié, mais ne pas qualifier `LIMIT 1` de choix arbitraire sans autre preuve.
- **Tenant :** la clé primaire de `dt_memberships` est `(tenant_id, user_id)`, mais un utilisateur peut avoir plusieurs memberships. Le garde-fou applicatif qui refuse un tenant ambigu reste justifié tant qu'un tenant actif explicite n'est pas disponible.
- **Accès à une demande :** `demands` ne possède pas de colonne `tenant_id`. `product_requests` possède `tenant_id` et `user_id`, mais le pont crée la demande avec `requester_actor_id` et le scope. La fonction SQL `is_demand_participant` ne couvre que le demandeur et les personnes déjà reliées par une offre/match ; elle ne suffit pas pour autoriser la première offre d'un fournisseur.
- **Règle métier à concevoir :** il faut une règle explicite et testable de visibilité d'une demande auprès des fournisseurs. Ne pas imposer que le tenant fournisseur égale le tenant demandeur (ce qui bloquerait le marketplace inter-tenant) et ne pas utiliser la seule existence de la demande comme preuve d'autorisation.
- **Toujours bloquant :** compatibilité des brouillons sans demande/Product Master/prix et migration de `app/api/offers/route.ts` vers le moteur universel. Le contrat SQL actuel exige une demande, un Product Master actif et un prix.
- **État sécurité : NOT PASS.** Aucune migration appliquée, aucune offre créée, aucun déploiement ni fusion. Tests PostgreSQL isolés toujours requis.


## 22. Contrôle d'accès RPC — fonction basse couche CREATE_OFFER — 27 octobre 2026

- **Constat live (lecture seule) :** les rôles `authenticated` et `postgres` disposent de `EXECUTE` sur `create_offer_v1(...)` et `execute_create_offer_v1(...)`.
- **Risque :** `create_offer_v1` écrit directement dans `offers`, sans journal `action_executions`, sans clé d'idempotence et sans événement `ACTION_SUCCEEDED`. Un appel RPC direct peut contourner le chemin universel.
- **Correction proposée sur la branche :** migration additive `supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql`, qui retire l'accès `PUBLIC` et `authenticated` à la fonction basse couche et conserve explicitement l'accès authentifié à `execute_create_offer_v1`.
- **Non appliquée :** aucune migration n'a été exécutée sur Supabase. La fonction basse couche doit rester appelable par la fonction enveloppe `SECURITY DEFINER` via son propriétaire.
- **Tests avant application :** refus de l'appel direct authentifié ; réussite du chemin universel ; retry avec la même clé sans doublon ; rollback des lignes d'exécution/idempotence si la création échoue.
- **Limite :** `app/api/offers/route.ts` insère directement dans `offers` sous RLS et n'appelle pas cette RPC. La migration ne l'unifie pas encore avec le runtime.
- **État sécurité : NOT PASS** jusqu'à exécution des tests d'intégration sur une base jetable.

## 23. Régressions de validation HTTP — 27 octobre 2026

- **Fichier de tests modifié :** `tests/e2e/auth-smoke.spec.ts`.
- **Ajouts :** tests Playwright qui vérifient que `POST /api/offers` renvoie HTTP 400 avant authentification pour une quantité non numérique, un prix non numérique et des attributs JSON mal formés.
- **But :** verrouiller les validations d'entrée existantes et éviter qu'une régression transmette des valeurs invalides aux opérations Supabase.
- **Limite :** ces tests ne valident pas l'insertion d'offre authentifiée, les politiques RLS, les RPC SQL, l'idempotence ni les courses concurrentes. Ils ne prouvent donc pas la sécurité du parcours complet.
- **Validation :** les tests viennent d'être ajoutés à la branche PR #26. La CI déclenchée par le commit doit être vérifiée avant de déclarer ces tests réussis.
- **État sécurité : NOT PASS** jusqu'aux tests d'intégration PostgreSQL isolés et à la résolution des contrats demande/brouillon/route historique.


## 24. Ajustement du test HTTP — ordre de validation — 27 octobre 2026

- La CI a révélé que le test des attributs JSON mal formés attendait HTTP 400 avant authentification, alors que la route analyse les attributs après authentification et contrôles des références.
- Le test a été retiré plutôt que de changer le contrat de la route uniquement pour satisfaire le test. Les tests de quantité et de prix non numériques restent en place.
- CI sur le commit précédent : TypeScript et build réussis, 15 tests Playwright réussis et 1 échec lié à cette attente incorrecte ; CodeQL réussi.
- Un nouveau commit corrige le test. Résultat CI de ce nouveau commit en attente de vérification.
- Aucun changement de production ni migration SQL exécutée.


## 25. Sélection de tenant et parsing défensif — 27 octobre 2026

- **PUBLISH-01 :** `app/api/product-requests/publish/route.ts` ne choisit plus le premier tenant arbitrairement. La route charge les memberships, déduplique les tenants et renvoie HTTP 409 `TENANT_SELECTION_REQUIRED` si le compte appartient à plusieurs tenants distincts.
- **OFFER-API-01 :** `app/api/actions/create-offer/route.ts` traite maintenant `correlationId` et `idempotencyKey` comme des chaînes optionnelles : une valeur absente, vide ou non-string entraîne la génération d'une UUID au lieu d'un appel à `.trim()` qui échouerait.
- **Fichiers de suivi :** `docs/LIVE_SUPABASE_CREATE_OFFER_SECURITY_REVIEW.md` et `docs/CREATE_OFFER_REGRESSION_SECURITY_PLAN.md`.
- **Validation automatisée du commit `73ea68d550a00a0839ced24c75a4bf38012fa9a6` :** QIMA CI run [40514820339](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820339) SUCCESS, incluant tests PostgreSQL isolés de CREATE_OFFER/concurrence, audit npm, TypeScript, build de production et Playwright smoke tests. CodeQL run [40514820258](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820258) SUCCESS.
- **Attention :** ces résultats valident le commit `73ea68d...`; ils ne valident pas automatiquement les mises à jour documentaires ultérieures et ne prouvent pas la parité complète avec le schéma Supabase de production.
- **Limites encore ouvertes :** le formulaire historique `app/api/offers/route.ts` effectue toujours un INSERT direct et accepte les brouillons sans demande/Product Master/prix. La règle de visibilité des demandes fournisseurs n'est pas encore définie. Le sélecteur de tenant actif n'existe pas encore : les comptes multi-tenant sont refusés par ces chemins plutôt que traités dans un contexte arbitraire.
- **État de sécurité global : NOT PASS** tant que l'autorisation demande/fournisseur, le parcours brouillon, la parité migrations et le lockfile commité ne sont pas résolus. Aucune migration de production, écriture métier ou fusion n'a été effectuée.


## 26. Suivi après actualisation documentaire — 27 octobre 2026

- **Dernier commit de la branche :** `3e05418339f404798dbedb6643e785a8b4a8bdde` (`docs: record latest preview status and lockfile checksum`).
- **Vercel Preview : SUCCESS** pour ce commit : https://vercel.com/bmk1/qimatrade-mvp/HcD6Vv8jJpbRvFptgYtPQHT234qZ
- **CI QIMA : EN ATTENTE** — run [40517774298](https://github.com/meridane/QimaTrade-MVP/actions/runs/40517774298). Les deux jobs, vérification complète et intégration PostgreSQL CREATE_OFFER, étaient encore en file d'attente au dernier contrôle.
- **CodeQL : EN ATTENTE** — run [40517774315](https://github.com/meridane/QimaTrade-MVP/actions/runs/40517774315).
- **Lockfile : NON INTÉGRÉ.** L'artefact généré a été récupéré et contrôlé, mais `package-lock.json` n'est toujours pas commité ; le workflow continue à le générer à chaque exécution. Ne pas considérer la reproductibilité des dépendances comme validée.
- **État fonctionnel :** le parcours de création d'offre historique `app/api/offers/route.ts` insère toujours directement dans `offers`. Il conserve les brouillons sans demande, Product Master ou prix. La route doit être migrée uniquement après définition du contrat brouillon, afin de ne pas casser le comportement existant.
- **Sécurité globale : NOT PASS.** La validation CI du commit de code précédent ne remplace pas les résultats attendus sur le commit actuel et ne prouve pas la parité du schéma de test avec Supabase production.
- **Mesures de sûreté :** aucun changement de base de production, aucune migration appliquée, aucune offre créée, aucune fusion de PR ni déploiement de production.


## 27. Résultats de validation confirmés — 27 octobre 2026

- **Commit testé :** `857c5f66d84a112d05e186f4c1c91a079007d549`.
- **QIMA CI : VALIDÉ pour ce commit** — run [40518018097](https://github.com/meridane/QimaTrade-MVP/actions/runs/40518018097). Les deux jobs ont réussi : TypeScript, audit npm, build de production, tests Playwright et tests PostgreSQL isolés d'idempotence/concurrence CREATE_OFFER.
- **CodeQL : VALIDÉ pour ce commit** — run [40518017925](https://github.com/meridane/QimaTrade-MVP/actions/runs/40518017925).
- **Vercel Preview : SUCCESS** — https://vercel.com/bmk1/qimatrade-mvp/JDbEPveSVKb4SbTi4G11KTCB3tay
- **Lockfile : récupéré mais non commité.** L'artefact du run CI contient un `package-lock.json` de 62 981 octets, SHA-256 `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`. L'intégration dans la branche reste à faire.
- **Garde de sécurité globale : NOT PASS.** Les tests PostgreSQL sont isolés sur une fixture synthétique et ne prouvent pas la parité totale avec Supabase. Restent bloquants : contrat d'autorisation fournisseur/demande, compatibilité des brouillons, réconciliation des migrations, lockfile commité et revue complète des privilèges.
- **Aucune opération de production :** aucune migration ni modification de privilèges appliquée, aucune offre créée, aucune fusion ni déploiement de production.


## 28. Audit RLS de la messagerie historique — 28 octobre 2026

- **Fichier examiné :** `app/demands/conversation/actions.ts`. Le parcours chat MVP utilise `public.demands`, `public.offers` et `public.messages`, et non les tables plus récentes `core.conversations` / `core.conversation_participants`.
- **Constat du catalogue Supabase en lecture seule :** RLS est activé sur `public.messages`; le rôle `authenticated` dispose des privilèges SELECT et INSERT.
- **Fonction examinée :** `public.is_message_participant(demand_id, offer_id, sender_actor_id)`. Elle retourne true dès que l'acteur du profil authentifié est égal au `sender_actor_id` fourni, sans vérifier d'abord l'appartenance à la demande ou à l'offre ciblée.
- **Politique INSERT observée :** `messages_insert_participants` exige cette fonction et que `sender_actor_id` corresponde au profil authentifié. L'action serveur fournit bien l'acteur du profil, mais transmet les identifiants demande/offre fournis par l'appelant. Cela forme un candidat d'injection de messages dans une demande/offre étrangère.
- **Classification :** candidat de sécurité prioritaire, non confirmé par test d'exploitation authentifié. Aucune ligne de message n'a été insérée et aucune écriture de production n'a été tentée.
- **Plan de test :** `docs/LEGACY_MESSAGES_RLS_REVIEW_2026-10-28.md` définit les tests négatifs d'injection, de couple demande/offre incohérent, de spoofing d'acteur, et les tests positifs demandeur/fournisseur.
- **Autre risque séparé :** `docs/PARTICIPANT_SELF_ENROLLMENT_REGRESSION_PLAN.md` suit les politiques des tables `core.conversation_participants` et `core.transaction_parties`. Les deux parcours doivent être testés indépendamment.
- **État sécurité : NOT PASS.** CI et CodeQL verts sur le commit précédent ne testent pas cette politique live. Aucun changement de schéma, de privilèges ou de données en production; aucune migration appliquée; PR #26 toujours ouverte et en brouillon.


## 9. Suivi du ré-audit — 28 octobre 2026

- **CI PostgreSQL : tests isolés VALIDÉS** pour le commit de suivi `6247486bde609565109900d5eda3b8f3f9a4592f` : CREATE_OFFER integration/concurrency, legacy messages RLS et participant self-enrollment RLS ont tous réussi.
- **TypeScript : VALIDÉ** sur ce même run.
- **Build de production : EN COURS** au moment du relevé ; les tests Playwright et l'audit CodeQL sont également en cours.
- **Prévisualisation Vercel :** le commit suivant a un statut de déploiement en attente au moment du relevé. Ne pas confondre une preview READY précédente avec le dernier commit.
- **SEC-CHAT-01 :** le code de `app/demands/conversation/actions.ts` insère le message à partir de `demandId` et `offerId` fournis, sans vérifier explicitement côté action que l'offre appartient à la demande. Le contrôle dépend donc des contraintes et politiques RLS. À valider avec des tests négatifs reproduisant les politiques réelles ; aucun exploit de production n'a été tenté.
- **OFFER-02 :** `app/api/offers/route.ts` crée des brouillons directement dans `offers`, tandis que `app/api/actions/create-offer/route.ts` passe par `executeUniversalAction`. Il faut définir le contrat métier des brouillons avant toute suppression ou redirection de l'ancienne route.
- **CREATE_OFFER tenant ↔ demande :** la fonction SQL proposée vérifie l'appartenance du membre au tenant, le profil acteur, le Product Master actif et l'existence de la demande, mais ne vérifie pas explicitement que la demande est éligible pour ce tenant fournisseur. Contrat métier et tests négatifs encore requis.
- **Aucune migration n'a été appliquée en production.** Les changements restent sur la branche de travail et la PR #26 reste en brouillon.

### Prochaines étapes
1. Attendre la fin du build, de Playwright et de CodeQL.
2. Ajouter des tests négatifs explicites sur la relation demande/offre et tenant/demande dans un environnement isolé.
3. Revoir les politiques et contraintes live en lecture seule pour s'assurer que les fixtures reflètent le schéma déployé.
4. Réconcilier l'historique des migrations et compléter le registre après validation.


## 10. Résultats CI et Preview — 28 octobre 2026, 07:41 KST
- **Commit contrôlé :** `0b0a9ba95a57a77de46e6444cec960528b059dce` (`docs: update QIMA function register with re-audit progress`).
- **QIMA CI : SUCCESS** — run [40596253372](https://github.com/meridane/QimaTrade-MVP/actions/runs/40596253372). Les deux jobs sont verts : TypeScript, audit npm au seuil high, build de production, installation Chromium, Playwright smoke tests, CREATE_OFFER PostgreSQL/intégration-concurrence, tests RLS synthétiques messages et auto-inscription.
- **CodeQL : SUCCESS** — run [40596253383](https://github.com/meridane/QimaTrade-MVP/actions/runs/40596253383). Ce statut indique que l'analyse s'est terminée sans échec de workflow ; il ne remplace pas une revue d'autorisation métier ou des tests contre les politiques live.
- **Vercel Preview : READY** pour le même commit : [ouvrir la prévisualisation](https://qimatrade-dooyuc8s8-bmk1.vercel.app) — [détails du déploiement](https://vercel.com/bmk1/qimatrade-mvp/5E7rCBMYsTt79dewNQKyJVcf3hBz). C'est une prévisualisation, pas un déploiement de production.
- **Lockfile CI : artefact récupéré et vérifié**, mais pas encore commité. L'archive du run contient `package-lock.json` de 62 981 octets ; SHA-256 du fichier extrait : `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`. Le fichier doit être ajouté au dépôt via un transfert de contenu fiable avant de considérer les installations reproductibles comme validées. Le digest SHA-256 de l'archive de l'artefact GitHub est distinct : `0994c21e2ffa5f8f2fc89fb5dc4ac705db87ecb11e551da9e27fdfcd833883cc`.
- **Blocages métier inchangés :** contrat demande/tenant fournisseur, contrat de brouillon de la route historique et parité des tests synthétiques avec le schéma Supabase live restent à traiter. Ne pas déduire de ces tests que le risque de messagerie est exploitable en production, ni qu'il est corrigé en production.
- **Sécurité / opérations :** aucune écriture ni migration de production, aucune fusion de PR, aucun déploiement de production.

### Action suivante recommandée
Priorité : intégrer le `package-lock.json` généré par CI sur la branche de travail, puis vérifier qu'un `npm ci` propre fonctionne sans régénération. Ensuite, ajouter des tests négatifs avec une fixture dont les contraintes/policies sont explicitement comparées au catalogue live en lecture seule. Le contrat d'autorisation tenant-demande doit rester un blocage documenté jusqu'à décision métier.


## 11. Garde de cohérence demande/offre dans la messagerie — 28 octobre 2026

- **Commit code :** `e14c3d64ff86ab96f1e22a931a3620da7b1ae78a` — `fix: reject mismatched demand and offer in conversations`.
- **Fichier modifié :** `app/demands/conversation/actions.ts`.
- **Changement :** `loadConversation` vérifie désormais que l'offre choisie appartient à la demande demandée. `sendConversationMessage` vérifie la même relation avant d'insérer un message et refuse une offre absente ou associée à une autre demande.
- **Portée exacte :** défense en profondeur contre les paires demande/offre incohérentes ; cette garde ne prouve pas l'autorisation de l'utilisateur sur une paire étrangère cohérente. La RLS reste l'autorité d'accès et le candidat d'injection de messages n'est pas déclaré corrigé tant que les politiques live n'ont pas été testées.
- **Documentation associée :** `docs/QIMA_SENSITIVE_ROUTES_REVIEW_2026-10-28.md` mise à jour avec les limites du correctif.
- **Validation mise à jour le 28 octobre 2026, 08:41 KST : SUCCESS sur le commit de documentation `ee4ef34db13359a612b6380217d156dd1d42ec60`**, qui inclut le correctif de code `e14c3d64ff86ab96f1e22a931a3620da7b1ae78a`. Les runs exacts et la portée sont consignés dans la section 12 ci-dessous.
- **Pas de changement de production :** aucune migration ni écriture Supabase, aucune fusion, aucun déploiement de production.

### Suite immédiate
1. Vérifier CI, CodeQL et Vercel sur le dernier commit de la branche.
2. Si les contrôles passent, conserver ce changement limité et ajouter un test de régression ciblé pour l'action serveur si un harnais de test approprié est disponible ; ne pas prétendre que le test SQL synthétique teste directement cette action TypeScript.
3. Continuer de traiter l'autorisation utilisateur/demande et tenant/demande comme des contrats métier séparés à clarifier.


## 12. Résultats de validation du commit courant — 28 octobre 2026, 08:41 KST

- **Commit contrôlé :** `ee4ef34db13359a612b6380217d156dd1d42ec60` (`docs: record conversation consistency guard and validation status`).
- **QIMA CI : SUCCESS** — run [40596892081](https://github.com/meridane/QimaTrade-MVP/actions/runs/40596892081). Les deux jobs ont réussi :
  - `Typecheck, audit, build and browser tests` : génération du lockfile, installation depuis ce lockfile généré, audit des dépendances, TypeScript, build de production, installation Chromium et tests Playwright smoke.
  - `CREATE_OFFER PostgreSQL integration tests` : tests PostgreSQL isolés CREATE_OFFER/intégration-concurrence, régression RLS des messages historiques et auto-inscription des participants.
- **CodeQL : SUCCESS** — run [40596891989](https://github.com/meridane/QimaTrade-MVP/actions/runs/40596891989), job JavaScript/TypeScript terminé avec succès.
- **Vercel Preview : READY** pour ce commit : [ouvrir la prévisualisation](https://qimatrade-l2s1q5arb-bmk1.vercel.app) — [détails du déploiement](https://vercel.com/bmk1/qimatrade-mvp/CY5scRE2ZXd1itun8uTgYtbFQ8Cq). Il s'agit d'une preview, pas d'un déploiement de production.
- **Lockfile : toujours non commité.** L'artefact CI `generated-package-lock` (run `40596892081`, artefact `12776342387`) contient un `package-lock.json` de 62 981 octets, SHA-256 `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`. L'installation CI depuis le lockfile généré a réussi, mais ce résultat ne prouve pas que `npm ci` fonctionne à partir d'un lockfile suivi dans Git. Le lockfile doit encore être intégré et revalidé sur un commit ultérieur.
- **Limites de sécurité inchangées :** les tests RLS utilisent une base isolée/fixtures synthétiques. Ils ne constituent pas une exploitation authentifiée de Supabase production et ne confirment ni l'exploitabilité ni la correction des politiques live. Les contrats d'autorisation utilisateur/demande et tenant/demande restent ouverts.
- **Sûreté des opérations :** aucune donnée ni migration Supabase production modifiée ; aucune fusion de PR, aucun déploiement de production et aucune modification des règles de protection.

### Prochaine tâche prioritaire

1. Intégrer de façon fiable le lockfile généré dans la branche de travail, après vérification de sa cohérence avec `package.json`.
2. Exécuter une installation propre `npm ci` à partir du lockfile commité et vérifier que le fichier ne change pas.
3. Ensuite, continuer les tests négatifs demande/offre et tenant/demande dans un environnement isolé dont les contraintes et policies sont comparées au catalogue live en lecture seule. Ne pas changer le contrat métier sans décision explicite.


## 13. Validation et reprise — 28 octobre 2026, 09:18 KST

- **PR #26 :** ouverte, en brouillon, non fusionnée. Branche fix/create-offer-status-contract, HEAD contrôlé : 8d454408a4a66959af06a7870a634be77b537734. Base : main.
- **QIMA CI : SUCCESS** — run [40603979741](https://github.com/meridane/QimaTrade-MVP/actions/runs/40603979741), commit exact 8d454408a4a66959af06a7870a634be77b537734. Les deux jobs ont réussi : installation depuis le lockfile généré par CI, audit npm, TypeScript, build de production, Playwright smoke tests, CREATE_OFFER/intégration-concurrence PostgreSQL isolée, tests RLS synthétiques des messages et de l'auto-inscription des participants.
- **CodeQL : SUCCESS** — run [40603979601](https://github.com/meridane/QimaTrade-MVP/actions/runs/40603979601), analyse JavaScript/TypeScript terminée avec succès.
- **Vercel Preview : READY** pour le même SHA : [ouvrir la prévisualisation](https://qimatrade-a0ur1wuaz-bmk1.vercel.app) — [détails du déploiement](https://vercel.com/bmk1/qimatrade-mvp/GF5to19nfyLMEo9jQm5LFYr8ZgfH). Preview uniquement, pas de déploiement de production.
- **Artefact lockfile vérifié :** artefact CI generated-package-lock, ID 12780546091. Après extraction, package-lock.json contient 62 981 octets, lockfileVersion 3, SHA-256 8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f. Les dépendances et devDependencies racine correspondent aux déclarations de package.json.
- **Lockfile toujours non commité :** CI a réussi npm ci après avoir généré le lockfile, mais ce n'est pas encore une preuve d'installation à partir d'un lockfile suivi dans Git. Ne pas marquer la reproductibilité des installations comme validée avant son intégration et un nouveau run propre.
- **Contrats métier et sécurité encore ouverts :** autorisation utilisateur/demande, tenant/demande fournisseur, contrat des brouillons de la route historique et parité des fixtures RLS avec le schéma réel. Les tests synthétiques ne prouvent ni l'exploitabilité ni la correction d'une vulnérabilité en production.
- **Garde opérationnelle :** aucune donnée ni migration Supabase production modifiée ; aucune fusion de PR, aucun déploiement de production, aucune modification des protections.

### Prochaine tâche prioritaire

1. Intégrer le lockfile CI vérifié dans la branche de manière fiable.
2. Exécuter npm ci depuis ce fichier commité, vérifier que le lockfile reste inchangé, puis relancer CI et CodeQL sur le nouveau SHA.
3. Continuer les tests négatifs demande/offre et tenant/demande dans un environnement jetable aligné sur les contraintes et politiques observées en lecture seule. Le contrat tenant-demande reste bloqué tant que la règle métier n'est pas définie.

## 13. Vérification de suivi — 28 octobre 2026, 09:30 KST

- **HEAD vérifié** : `8cab480bf08592e6796e2fd2334b6c4060558fd9`, branche `fix/create-offer-status-contract`, PR #26 toujours ouverte en brouillon.
- **CI QIMA** : succès sur ce commit : audit npm, TypeScript, build de production, Playwright smoke tests et tests PostgreSQL isolés pour CREATE_OFFER/concurrence, messages historiques et auto-inscription aux participants.
- **CodeQL** : succès sur ce commit.
- **Preview Vercel** : état READY pour le commit contrôlé.
- **Limite de validation** : les tests SQL RLS sont des fixtures synthétiques, pas des tests d'autorisation avec les rôles/JWT et les politiques exactes de la base réelle. Ne pas déclarer la sécurité de production validée.
- **OFFER-SEC-01 — association tenant/demande** : toujours BLOQUANT avant fusion ; `execute_create_offer_v1` vérifie l'appartenance au tenant et l'existence de la demande, mais le contrat qui autorise ce tenant à proposer sur cette demande n'est pas encore établi par le code inspecté.
- **OFFER-SEC-02 — voie historique** : `app/api/offers/route.ts` insère directement une offre en brouillon ; elle ne passe pas par le runtime universel. Il faut confirmer le contrat de brouillon et son modèle d'autorisation avant de rediriger cette route vers `CREATE_OFFER`.
- **Aucune migration Supabase production, écriture de données, fusion ou déploiement de production n'a été effectué.**
- **Prochaine action** : définir les preuves d'autorisation disponibles dans les schémas et fonctions existants ; ajouter des tests négatifs contre un environnement isolé fidèle au schéma avant de préparer une modification métier.

## 14. Inspection Supabase en lecture seule — fonction CREATE_OFFER

- Le code de la fonction `public.execute_create_offer_v1` dans la base réelle reste l'ancienne définition : statuts internes minuscules, hash limité à `p_input`, et pas de verrou consultatif visible pour sérialiser la première création concurrente. La migration corrective existe sur la branche, mais **n'est pas appliquée en production**.
- Les relations vérifiées indiquent `demands.requester_actor_id → actors.id`, tandis que `dt_memberships.tenant_id → dt_tenants.id` et `dt_memberships.user_id → auth.users.id`. Aucune relation directe tenant-demande n'a été observée dans les colonnes/FK examinées.
- **Décision de sécurité :** ne pas appliquer la migration ni inventer un lien d'autorisation. Il faut déterminer si la règle métier est basée sur le propriétaire de la demande, une publication ouverte à plusieurs fournisseurs, un rattachement business-object, ou une autre règle déjà définie dans QIMA.
- Aucune modification de la base Supabase production n'a été faite ; toutes les requêtes exécutées étaient des SELECT en lecture seule.


## Nouveau module proposé — QIMA Auto Parts Market (28 octobre 2026)

**Statut : PROPOSED — conception à réconcilier avec B4 avant tout code ou migration.** Module séparé du commerce international Core.

- **Objectif :** marketplace de pièces automobiles neuves et d'occasion, pour particuliers et professionnels.
- **Lancement :** Corée du Sud, conception extensible à l'international.
- **Parcours :** recherche simple/avancée par pièce, marque, modèle, année, catégorie et référence OEM ; fiche annonce avec photos réelles, état, défauts, prix/devise, quantité, localisation, options de remise/livraison et compatibilité avec niveau de vérification.
- **Publication :** modération préalable au lancement.
- **Transaction :** contact direct et commande en ligne sont deux parcours envisagés ; paiement intégré bloqué jusqu'à validation du contrat de commande, remboursements, prestataire et obligations applicables.
- **Monétisation :** gratuit au lancement ; commission, annonces sponsorisées et abonnements restent des options futures.

### Actions proposées

`CREATE_AUTO_PART_LISTING`, `UPDATE_AUTO_PART_LISTING`, `SUBMIT_AUTO_PART_LISTING_FOR_REVIEW`, `APPROVE_AUTO_PART_LISTING`, `REJECT_AUTO_PART_LISTING`, `PUBLISH_AUTO_PART_LISTING`, `WITHDRAW_AUTO_PART_LISTING`, `SEARCH_AUTO_PARTS`, `CREATE_AUTO_PART_INQUIRY`, `RESERVE_AUTO_PART_LISTING`, `REPORT_AUTO_PART_LISTING`. `CREATE_AUTO_PART_ORDER` reste conditionnel à la décision sur le paiement.

### Modèle conceptuel à réconcilier (noms non validés)

- `auto_part_listings` : vendeur, titre/description, condition, prix/devise, quantité, statut, localisation, catégorie.
- `auto_part_listing_media` : photos et métadonnées.
- `vehicle_fitments` : compatibilité déclarée/vérifiée (marque, modèle, génération, années, motorisation, position).
- `auto_part_identifiers` : références OEM/fabricant avec provenance.
- `auto_part_categories` : taxonomie dédiée aux pièces, à comparer aux référentiels existants.
- `auto_part_inquiries` : demandes de contact.
- `auto_part_orders` et `auto_part_order_events` : uniquement après validation du contrat de commande.
- `auto_part_reports` et, éventuellement, `auto_part_reviews` : modération et avis liés à une transaction vérifiable.

**Ne pas créer ces tables avant l'audit** des tables, fonctions, catégories, profils/tenants, storage, messages et audit existants. Ce sont des entités conceptuelles, pas des tables confirmées.

### États et sécurité

Cycle proposé : `draft → pending_review → published → reserved → sold`, alternatives `rejected`, `expired`, `withdrawn`. Transitions vérifiées côté serveur, historique conservé. RLS/API/storage doivent empêcher la modification d'annonces d'autrui, empêcher la publication sans approbation et protéger les médias. La réservation/vente doit être atomique pour éviter la double vente. Les défauts d'une pièce d'occasion doivent être décrits avant publication. Une compatibilité non vérifiée doit être affichée comme telle.

### UI et tests d'acceptation

Écrans : accueil marketplace, résultats/filtres, détail annonce, création/édition, mes annonces, file de modération, demandes de contact et éventuellement commandes. Tests : persistance après rechargement, propriétaire/permissions, annonces non approuvées invisibles, défauts obligatoires pour occasion, filtres, compatibilité non vérifiée, concurrence de réservation, idempotence, RLS/storage multi-vendeur et régression Demand/Offer/Action Runtime.

### Ordre recommandé

1. `MKT-0` inventaire read-only du schéma B4/Supabase, migrations, policies, storage et UI.
2. `MKT-1` contrat de domaine, états et frontière avec Demand/Offer.
3. `MKT-2` mapping conceptuel → objets existants → écarts B4.
4. `MKT-3` première tranche sans paiement : créer, modérer, publier et rechercher.
5. `MKT-4` tests de sécurité et de régression.
6. `MKT-5` contact/réservation après validation des autorisations de conversation.
7. `MKT-6` commande/paiement seulement après décision métier et juridique.

**Garde-fous :** aucune migration production, aucun merge ni déploiement n'est autorisé par cette proposition. Le module n'est pas encore implémenté. Le travail de réconciliation des migrations et les risques de sécurité déjà prioritaires restent devant toute extension du périmètre.


## Point de contrôle CI — 28 octobre 2026, 10:41 KST

### État réel de la PR #26

- Branche : `fix/create-offer-status-contract`.
- HEAD vérifié avant ce point de documentation : `a87309ce83cf997c3acf43001e9989d6a8d78b8f` (`docs: register proposed QIMA Auto Parts Market module`).
- PR toujours ouverte, en brouillon, non fusionnée.
- QIMA CI run [40614589108](https://github.com/meridane/QimaTrade-MVP/actions/runs/40614589108) : **SUCCESS**. Les deux jobs ont réussi : TypeScript/audit/build/Playwright et PostgreSQL isolé (CREATE_OFFER, concurrence, tests de régression synthétiques messages RLS et auto-inscription).
- QIMA CodeQL run [40614589166](https://github.com/meridane/QimaTrade-MVP/actions/runs/40614589166) : **SUCCESS**.
- Statut Vercel du commit : **SUCCESS** (preview uniquement).
- Ces résultats correspondent au SHA ci-dessus ; ils ne préjugent pas des contrôles du commit de documentation ajouté ensuite.

### Lockfile npm — blocage restant confirmé

- `package-lock.json` est toujours absent de l'arbre versionné de la branche (lecture GitHub du chemin : 404).
- L'artefact généré par CI contient un fichier de 62 981 octets, empreinte SHA-256 `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`.
- La CI a réussi `npm ci` après avoir généré ce lockfile temporaire. Cela prouve que l'installation fonctionne dans cette exécution, **pas** que le dépôt possède un lockfile reproductible.
- Intégration non terminée : le fichier exact doit être ajouté à Git, puis `npm ci` doit réussir sans étape de génération préalable. Ne pas recréer manuellement le fichier ni déclarer ce point résolu.

### Interprétation sécurité

Les tests SQL de messages RLS et d'auto-inscription exécutés dans CI utilisent des fixtures synthétiques. Leur réussite valide les scénarios reproduits dans ces fixtures uniquement ; elle ne prouve ni l'existence ni l'absence d'un exploit sur les policies Supabase réellement déployées. Les vérifications des policies et des autorisations multi-tenant réelles restent ouvertes. Security Gate demeure **NOT PASS**.

### Prochaine action

1. Intégrer le lockfile généré et vérifié sans altérer son contenu.
2. Relancer et contrôler CI, CodeQL et Vercel sur le nouveau SHA.
3. Poursuivre la revue isolée des autorisations de conversation et du lien fournisseur/demande, sans supposer une règle métier non documentée.

Aucune migration, donnée ou policy de Supabase production n'a été modifiée. Aucun merge, déploiement de production ni changement de protection de branche n'a été effectué pendant ce point de contrôle.


## Point de contrôle — lockfile npm intégré et CI durcie (28 octobre 2026, 11:51 KST)

### Changements vérifiés sur la branche

- PR #26 toujours ouverte, en brouillon et non fusionnée.
- Commit `55e3ae9858160eb574e57e7afde2f1d1c0f8bad5` : ajout de `package-lock.json`, récupéré depuis l'artefact CI existant.
- Le fichier versionné fait **62 981 octets**, utilise `lockfileVersion: 3`, et son SHA-256 a été recalculé depuis le contenu relu sur GitHub : `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`. Il correspond exactement à l'artefact précédemment vérifié.
- Commit `4178092e529ca7d40fae4c26607515b3363e860c` : `.github/workflows/ci.yml` installe maintenant avec `npm ci` directement depuis le lockfile versionné ; l'étape qui régénérait le lockfile a été supprimée. La CI téléverse désormais l'artefact `committed-package-lock` après installation pour faciliter les vérifications.

### Checks observés

- Sur le commit précédent `cab5e34d2e8d676ee39234286ff79c68285efd80` : QIMA CI run [40616647201](https://github.com/meridane/QimaTrade-MVP/actions/runs/40616647201) **SUCCESS**, CodeQL [40616647192](https://github.com/meridane/QimaTrade-MVP/actions/runs/40616647192) **SUCCESS**, Vercel Preview **SUCCESS**.
- Sur le commit workflow `4178092e529ca7d40fae4c26607515b3363e860c` : QIMA CI run [40623603142](https://github.com/meridane/QimaTrade-MVP/actions/runs/40623603142) était **PENDING** au dernier contrôle ; CodeQL [40623603153](https://github.com/meridane/QimaTrade-MVP/actions/runs/40623603153) était **IN PROGRESS** ; Vercel Preview était **PENDING**. Aucun résultat final n'est affirmé pour ce commit à ce stade.
- L'absence de lockfile dans le dépôt est résolue sur cette branche ; la reproductibilité complète n'est pas déclarée validée avant le succès de `npm ci` sur le lockfile commité.

### Sécurité et prochaine étape

Les tests synthétiques messages-RLS et auto-inscription restent des fixtures de régression, pas une preuve d'exploitation ou d'absence de vulnérabilité sur le schéma Supabase réellement déployé. Security Gate demeure **NOT PASS**. Après les checks du commit courant, continuer la revue isolée des autorisations de conversation et du lien fournisseur/demande ; toute règle métier inconnue reste bloquante et doit être documentée, pas supposée.

Aucune donnée, policy ni migration de Supabase production n'a été modifiée. Aucun merge, déploiement production ni changement de protection de branche n'a été effectué.


## MKT-0 — B4/Supabase marketplace reconnaissance (28 octobre 2026, read-only)

La lecture des métadonnées du schéma Supabase confirme que plusieurs objets génériques existent et doivent être audités avant d'ajouter de nouvelles tables :

- `core.publications` : publication générique avec titre/description, type/statut, domaine/catégorie/sous-catégorie, produit master/produit physique, quantité, condition, localisation, prix/devise, disponibilité, marque/fabricant, média principal et version.
- `core.publication_media` + `core.media_assets` : relation publication-média et métadonnées de fichiers.
- `core.product_items` : exemplaire physique/stock avec propriétaire, organisation, SKU, numéro de série, condition, données JSON et statut.
- `core.organizations`, `core.organization_memberships`, `core.profiles` : organisations, membres et profils.
- `core.orders` : commande liée au modèle actuel de transaction/offre ; réutilisation non confirmée.
- `public.product_masters`, `public.categories`, `public.subcategories`, `public.trade_domains` : référentiels génériques, mais aucune compatibilité véhicule/OEM ne doit être supposée sans preuve.
- Les anciens `public.demands`, `public.offers`, `public.messages`, `public.product_requests` existent aussi ; leur cycle de vie ne doit pas être assimilé automatiquement à celui de la marketplace.
**Hypothèse d'architecture à vérifier :** spécialiser `core.publications` pour les annonces de pièces et réutiliser ses médias pourrait éviter des tables d'annonces dupliquées. Il faut d'abord vérifier `kind`, enums, contraintes, `publication_attributes`, fonctions de publication, policies/grants RLS et règles Storage. Une table dédiée de compatibilité véhicule/référence OEM pourrait être nécessaire, mais aucune nouvelle table n'est décidée.

**État :** inventaire initial des métadonnées seulement ; aucun test de sécurité n'est impliqué par la présence de RLS activé. Aucune donnée, policy, table ou migration de production n'a été modifiée.

**Prochaine étape MKT-0.2 :** lire les définitions SQL/policies/grants des objets candidats, puis construire le mapping champ marketplace → objet/colonne existant → écart → décision. Ne pas créer de migration avant cette réconciliation.


## MKT-0.2 — RLS audit initial des objets de publication (read-only, 28 octobre 2026)

Policies SQL observées sur l'environnement Supabase cible :

- `core.publications` : insertion/édition contrôlées par auteur ou admin ; suppression auteur seulement en `DRAFT` ou admin ; lecture par auteur, admin ou publication `ACTIVE/REOPENED`.
- `core.publication_media` et `core.publication_attributes` : écriture rattachée à une publication dont l'auteur est l'utilisateur ou admin ; lecture via `core.can_access_publication` ou admin.
- `core.media_assets` : insertion propriétaire/admin ; lecture propriétaire/admin ou média relié à publication active/réouverte/vitrine publiée. Les policies Storage et l'accès effectif aux objets doivent encore être inspectés séparément.
- `core.product_items` : accès propriétaire/organisation/admin, plus lecture si lié à une publication active/réouverte.
- `core.orders` : accès basé sur `core.can_access_transaction(transaction_id)` ou admin ; compatibilité marketplace non prouvée.
- `core.organization_memberships` a une policy `qima_membership_self_insert` autorisant `user_id = auth.uid()` avec `role_id IS NULL`. Point à auditer pour confirmer qu'il s'agit uniquement d'une demande sans privilège et qu'aucune auto-adhésion effective/escalade n'est possible ; la policy seule ne prouve pas une exploitation.

**Point de sécurité marketplace :** les policies visibles ne démontrent pas qu'un auteur ne peut pas passer directement une publication à `ACTIVE` sans modération. Il faut examiner enums, triggers, contraintes et actions serveur. La lecture actuelle est liée au rôle `authenticated`; l'accès anonyme au catalogue reste une décision non résolue. RLS des tables média ne remplace pas l'audit des policies Storage.

**Statut :** lecture de métadonnées/policies seulement, aucun test exploit, aucune migration ou écriture de production. Prochaine étape : inspecter enums `publication_status/kind`, fonctions `can_access_publication`, transitions/actions et policies Storage ; ensuite créer les tests isolés de contournement de modération.


## MKT-0.3 — Enums, access helper et Storage (read-only, 28 octobre 2026)

- `core.publication_kind` = `OFFER, REQUEST` uniquement : aucun type explicite de listing automobile.
- `core.publication_status` = `DRAFT, ACTIVE, PAUSED, CLOSED, REOPENED, ARCHIVED` : pas de `PENDING_REVIEW` ni `REJECTED` dans l'enum actuel.
- `core.can_access_publication(uuid)` est `SECURITY DEFINER`, avec `search_path` fixé ; sa logique donne accès à l'auteur ou aux publications `ACTIVE/REOPENED`, sans vérifier une approbation de modération.
- Dans le périmètre Storage interrogé, les policies vues concernent le bucket `project-documents`. Le contrat d'accès aux photos marketplace reste inconnu ; inventaire complet des buckets et policies requis.
- Les policies de table ne suffisent pas à prouver que l'auteur peut ou ne peut pas forcer `ACTIVE` : il faut vérifier triggers, RPC et actions applicatives.

**Conclusion provisoire :** ne pas réutiliser `OFFER` ou `REQUEST` par approximation pour une annonce de pièce. Comparer deux options : (A) spécialiser le modèle de publication générique avec type marketplace et modération côté serveur ; (B) contexte/tables marketplace dédiés avec réutilisation contrôlée des services communs. Aucune option n'est approuvée avant l'audit des dépendances.

**Prochaine étape MKT-0.4 :** inventaire complet des buckets Storage/policies ; triggers et fonctions qui changent `core.publications.status` ; contraintes/grants ; mapping des actions/UI ; comparaison A/B et plan de tests isolés. Aucun changement production.


## MKT-1.1 — CREATE_OFFER authorization contract audit (28 octobre 2026)

- **CI du code précédent :** QIMA CI run 238 et CodeQL run 201 ont réussi pour le SHA `195dab9bcb2026c6a80f7a0b876a590bbcaf2da5`. Ces checks ne prouvent pas la règle métier d'autorisation qui reste à définir.
- **Schéma réel relu en SELECT :** `public.demands` contient `requester_actor_id` et `demand_status`, mais aucune colonne `tenant_id` dans les colonnes inspectées. `public.dt_memberships` relie le tenant à l'utilisateur Auth ; `public.profiles` relie l'utilisateur à l'acteur.
- **Données observées :** 23 demandes avaient le statut `draft` au moment de la requête. Ce snapshot ne définit pas à lui seul le vocabulaire complet des statuts ni la règle de publication.
- **Écart confirmé :** le runtime vérifie l'appartenance au tenant, l'identité du fournisseur et l'existence de la demande, mais ne vérifie ni l'état de réponse autorisé de la demande, ni l'éligibilité de ce tenant à répondre à cette demande.
- **Décision : BLOQUANT / règle métier à préciser.** Ne pas inventer un statut `published` ou un lien tenant-demande qui n'est pas confirmé. Définir si toute demande publiée est ouverte à tous les fournisseurs ou si une politique d'audience/organisation restreint les réponses.
- **Route historique :** `app/api/offers/route.ts` insère encore directement les offres brouillon et ne passe pas par le runtime universel. Son intention et ses règles d'accès doivent être confirmées séparément.
- **Rapport complet :** `docs/MKT-1.1_CREATE_OFFER_AUTHORIZATION_AUDIT.md`.
- **Aucune écriture, migration, modification de policy Supabase, fusion ni mise en production** n'a été effectuée.



## Point de contrôle — lockfile et CI confirmés sur HEAD (28 octobre 2026, 13:06 KST)

### État GitHub relu avant cette mise à jour

- PR #26 : ouverte, en brouillon, non fusionnée ; base `main`, branche `fix/create-offer-status-contract`.
- HEAD avant le présent commit documentaire : `0c26fc8d09cc46f0c02ee5d997f6910a814259fe`.
- Le `package-lock.json` est bien présent sur la branche : 62 981 octets, `lockfileVersion: 3`. Son SHA-256 précédemment vérifié reste `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`.

### Résultats observés pour ce HEAD

- QIMA CI run [40629634655](https://github.com/meridane/QimaTrade-MVP/actions/runs/40629634655) : **SUCCESS**.
  - `npm ci --no-audit --no-fund` depuis le lockfile commité : SUCCESS.
  - `npm audit --audit-level=high` : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Installation Chromium et Playwright smoke tests : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER/concurrence : SUCCESS.
  - Tests de régression synthétiques messages RLS et auto-inscription des participants : SUCCESS.
  - Artefact `committed-package-lock` téléversé : SUCCESS.
- QIMA CodeQL run [40629634650](https://github.com/meridane/QimaTrade-MVP/actions/runs/40629634650) : **SUCCESS**.
- Statut Vercel du HEAD : **SUCCESS**, preview uniquement ([détails](https://vercel.com/bmk1/qimatrade-mvp/4namRs6GZf3AreK3tRCFUgZVbaCv)).

### Interprétation et garde-fous

- **Le blocage du lockfile est levé pour ce HEAD** : la CI a exécuté `npm ci` avec le fichier versionné et a téléversé l'artefact correspondant. Toute modification ultérieure des dépendances doit conserver cette vérification.
- Les tests RLS utilisent des fixtures PostgreSQL isolées. Leur succès valide les scénarios simulés uniquement ; il ne prouve ni l'exploitabilité ni l'absence d'une vulnérabilité dans la base Supabase réelle.
- **Security Gate reste NOT PASS** : l'autorisation fournisseur/tenant/demande et le contrat de la route historique de création de brouillon nécessitent encore une règle métier documentée.
- Prochaine tâche non bloquante : ajouter une couverture de régression ciblée pour le contrat demande/offre dans un environnement isolé, sans coder une règle d'éligibilité fournisseur non approuvée. Si le test exige de décider quels statuts autorisent une réponse ou quels fournisseurs sont éligibles, conserver ce point comme blocage métier.
- Aucune donnée ni migration, policy ou configuration Supabase production n'a été modifiée. Aucun merge, déploiement de production ni changement de protection de branche n'a été effectué.



## QA-02 — régression d'authentification CREATE_OFFER (28 octobre 2026, 13:07 KST)

- **Fichier ajouté/modifié :** `tests/e2e/auth-smoke.spec.ts`.
- **Commit :** `c8e2e012ab6f6858b1b9c518cc2b9310d05b6d9f`.
- **Cas ajouté :** un POST sur `/api/actions/create-offer` sans en-tête Bearer doit renvoyer HTTP 401 et `{ error: "UNAUTHENTICATED" }`. Ce test s'arrête sur la garde d'authentification et n'utilise aucun compte, secret ou accès à la base.
- **Contrôles du HEAD de test au moment du relevé :** QIMA CI run [40630587310](https://github.com/meridane/QimaTrade-MVP/actions/runs/40630587310) **PENDING** ; CodeQL run [40630587316](https://github.com/meridane/QimaTrade-MVP/actions/runs/40630587316) **IN PROGRESS** ; Vercel Preview **PENDING**. Aucun résultat final n'est revendiqué pour ce commit.
- **Dernier HEAD avec validation complète :** `0c26fc8d09cc46f0c02ee5d997f6910a814259fe` — QIMA CI run [40629634655](https://github.com/meridane/QimaTrade-MVP/actions/runs/40629634655), CodeQL run [40629634650](https://github.com/meridane/QimaTrade-MVP/actions/runs/40629634650) et Vercel Preview ont tous réussi. Ce HEAD confirme aussi que `npm ci` fonctionne depuis le lockfile commité.
- **Limite :** le test valide le refus d'une requête sans jeton ; il ne teste pas la validité d'un jeton expiré ni les autorisations tenant/demande.
- Aucun changement Supabase, migration, fusion ou déploiement de production.



## QA-02 — résultat final des contrôles (28 octobre 2026, 13:39 KST)

- **État PR relu avant cette mise à jour :** #26 ouverte, en brouillon, non fusionnée ; HEAD `018b1e82a7d5d4ddb8cb99ffae82a7972354bbc8`.
- **QIMA CI run [40630627764](https://github.com/meridane/QimaTrade-MVP/actions/runs/40630627764) : SUCCESS.** Les deux jobs ont réussi :
  - Installation depuis `package-lock.json` commité avec `npm ci` : SUCCESS.
  - Audit npm au seuil high : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Installation Chromium et suite Playwright : SUCCESS, y compris le test de refus HTTP 401 sans Bearer pour `/api/actions/create-offer`.
  - Tests PostgreSQL isolés CREATE_OFFER/concurrence : SUCCESS.
  - Tests synthétiques de régression messages-RLS et auto-inscription des participants : SUCCESS.
  - Artefact `committed-package-lock` : téléversé avec succès.
- **CodeQL run [40630627586](https://github.com/meridane/QimaTrade-MVP/actions/runs/40630627586) : SUCCESS.**
- **Statut Vercel : SUCCESS**, preview uniquement ([détails](https://vercel.com/bmk1/qimatrade-mvp/778LyZKyeDLPaxiZCMhSq5qjNXuy)).
- **Interprétation :** ces résultats valident les contrôles exécutés sur ce SHA. Les tests RLS sont synthétiques et ne démontrent pas, à eux seuls, une vulnérabilité ni son absence sur Supabase production.
- **Blocages métier inchangés :** règle d'éligibilité fournisseur/tenant/demande et contrat de la route historique de création de brouillon. Security Gate reste **NOT PASS** jusqu'à définition et validation de ces règles.
- **Aucune écriture ni migration Supabase production, aucune fusion, aucun déploiement de production, aucun changement de protection de branche.** Cette entrée est documentaire ; les checks du commit documentaire qui en résulte doivent être vérifiés séparément.


## OFFER-QA-03 — validation devise cohérente entre API et RPC (28 octobre 2026)

- **État de départ relu :** PR #26 ouverte, en brouillon, non fusionnée ; HEAD `a49310acd0c0a30d283bb253dc2fbb7851a3a997`. QIMA CI run [40633646593](https://github.com/meridane/QimaTrade-MVP/actions/runs/40633646593) et CodeQL run [40633646551](https://github.com/meridane/QimaTrade-MVP/actions/runs/40633646551) ont réussi sur ce HEAD ; Vercel Preview était Ready.
- **Constat de contrat :** les routes applicatives limitent la devise à `USD`, `EUR`, `KRW`, `MAD`, `CNY`, alors que le corps branch-only de `execute_create_offer_v1` vérifiait uniquement que la devise n'était pas vide. Cela établit une incohérence de validation entre couches, pas une preuve qu'un abus a eu lieu ou qu'il est exploitable sur la base de production.
- **Fichiers modifiés dans le commit de travail :**
  - `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql` — la fonction RPC rejette maintenant les devises hors de la liste déjà utilisée par les API.
  - `tests/sql/create-offer-runtime.sql` — cas négatif isolé `XYZ`, attendu `INVALID_CURRENCY`, avec assertion qu'aucune offre n'est créée.
  - `docs/QIMA_V1_FUNCTION_REGISTER.md` — consignation de l'écart, du correctif branch-only et des limites de validation.
- **Validation :** le test est ajouté à la suite PostgreSQL jetable CI. Les checks du nouveau commit doivent être vérifiés après push ; aucun succès n'est présumé avant leur résultat.
- **Limites :** ce changement ne définit pas l'éligibilité fournisseur/tenant/demande, ne change pas les statuts métier, et ne constitue pas un test sur Supabase production.
- **Garde-fous :** migration uniquement dans la branche GitHub ; elle n'a pas été appliquée à Supabase. Aucune donnée, policy ou configuration de production n'a été modifiée. Aucun merge ni déploiement de production.


## OFFER-QA-03 — résultats finaux et contrôle du schéma déployé (28 octobre 2026, 14:56 KST)

### Résultats du commit de code/test `ccf7067e4f1a987d418c556a6549fcf90aeec6f6`

- **QIMA CI run [40640681546](https://github.com/meridane/QimaTrade-MVP/actions/runs/40640681546) : SUCCESS.**
  - `npm ci` depuis le lockfile commité : SUCCESS.
  - Audit npm : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Tests Playwright : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER et concurrence : SUCCESS, y compris le cas `XYZ` qui attend `INVALID_CURRENCY`.
  - Régressions synthétiques messages-RLS et auto-inscription participants : SUCCESS.
  - Artefact lockfile commité : téléversé avec succès.
- **CodeQL run [40640681573](https://github.com/meridane/QimaTrade-MVP/actions/runs/40640681573) : SUCCESS.**
- **Vercel Preview : SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/61GfrcXhFU9GgVicdvPTJvSD6Pb7)). Prévisualisation uniquement.
- Ces résultats concernent ce SHA de code/test. Le commit documentaire qui ajoute cette entrée déclenchera ses propres contrôles et devra être vérifié séparément.

### Inspection Supabase réelle — SELECT seulement

- Aucune contrainte CHECK sur la devise n'a été trouvée parmi les contraintes de `public.offers` interrogées.
- `has_function_privilege` indique que le rôle `authenticated` possède actuellement `EXECUTE` sur `public.create_offer_v1(...)` et `public.execute_create_offer_v1(...)` ; `anon` ne possède pas ce privilège.
- Cela confirme que, dans le schéma actuellement déployé et avant application des migrations de la branche, le RPC bas niveau reste exécutable par un utilisateur authentifié. L'inspection ne prouve pas qu'un appel abusif a été effectué ; aucune requête de création d'offre n'a été exécutée.
- La migration de branche `20261027100000_restrict_direct_create_offer_rpc.sql` prévoit de retirer l'exécution directe, tandis que la migration `20261027090000_fix_create_offer_action_status_contract.sql` valide la devise sur le wrapper. **Aucune de ces migrations n'a été appliquée à la production.**
- **Décision opérationnelle :** garder ce point visible comme écart de configuration à traiter via le processus normal de revue et de déploiement approuvé. Ne pas le présenter comme un exploit confirmé. Avant toute mise en production, vérifier l'ordre et les ACL effectives après application des migrations, puis effectuer des tests négatifs dans un environnement de staging isolé.

### Garde-fous

Aucune donnée, migration, policy ou configuration Supabase production n'a été modifiée. Aucun merge, déploiement de production ou changement de protection de branche n'a été effectué.

## OFFER-QA-04 — devise NULL refusée par CREATE_OFFER (28 octobre 2026, 15:03 KST)

- **PR #26 / branche :** `fix/create-offer-status-contract`, PR toujours ouverte en brouillon et non fusionnée.
- **État de départ consulté :** HEAD avant modification `7d24b16c25446ce9bd65142292ce6b7355d9c37e`. La CI QIMA et CodeQL étaient terminées avec succès sur ce SHA ; le statut Vercel Preview était SUCCESS. Ces résultats ne valident pas les changements ci-dessous.
- **Modification :** commit `c7a40e581db908599c100e47712520cf5363246a`, fichier `tests/sql/create-offer-runtime.sql`. Ajout d'un cas négatif qui transmet `NULL` comme devise à `execute_create_offer_v1` et attend `INVALID_CURRENCY`. Le cas couvre explicitement une valeur nulle, distincte de la devise non prise en charge `XYZ`.
- **État de validation au relevé initial (15:03 KST) :** les checks du commit de test n'étaient pas encore disponibles ; aucun succès n'était alors présumé.
- **Résultat final :** voir la section immédiatement suivante « OFFER-QA-04 — résultats des contrôles du test devise NULL », qui consigne les résultats obtenus sur le HEAD `59310e61d33ec48b018b5a4a5cfc6e109aaf5651` : QIMA CI, CodeQL et Vercel Preview tous SUCCESS.
- **Limites :** test exécuté dans la base PostgreSQL isolée de CI, pas dans Supabase production.
- **Garde-fous :** aucune donnée ni migration Supabase production modifiée ; aucune fusion, aucun déploiement de production et aucune modification des règles de protection.

## OFFER-QA-04 — résultats des contrôles du test devise NULL (28 octobre 2026, 15:32 KST)

### Résultats vérifiés sur le HEAD `59310e61d33ec48b018b5a4a5cfc6e109aaf5651`

- **QIMA CI run [40641639220](https://github.com/meridane/QimaTrade-MVP/actions/runs/40641639220) — SUCCESS.**
  - Installation `npm ci` depuis le lockfile commité : SUCCESS.
  - Audit des dépendances au seuil `high` : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Installation de Chromium et tests Playwright : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER et concurrence : SUCCESS ; le lot comprend le cas devise `NULL` ajouté dans `c7a40e581db908599c100e47712520cf5363246a`, qui attend `INVALID_CURRENCY`.
  - Régressions synthétiques messages-RLS et auto-inscription participants : SUCCESS.
  - Artefacts `committed-package-lock` et `npm-audit-report` téléversés : SUCCESS.
- **CodeQL run [40641639125](https://github.com/meridane/QimaTrade-MVP/actions/runs/40641639125) — SUCCESS.**
- **Vercel Preview — SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/79qSkGwGFjSSK4y7PSWZcgzfVhMW)), preview uniquement.
- Les résultats couvrent le HEAD indiqué, qui contient le test devise `NULL` et la note documentaire initiale. Le présent ajout documentaire déclenchera ses propres contrôles ; ceux-ci doivent être vérifiés séparément.

### Portée et limites

- Les assertions CREATE_OFFER ont réussi dans une base PostgreSQL isolée de CI. Cela valide les scénarios simulés exécutés, pas l'ensemble des autorisations Supabase en production.
- CodeQL SUCCESS ne constitue pas, à lui seul, une preuve d'absence de vulnérabilité.
- **Security Gate reste NOT PASS** : l'accès direct du rôle `authenticated` à la RPC bas niveau observé lors de l'inspection précédente et la règle métier fournisseur/tenant/demande restent à traiter via revue et validation dans un environnement isolé. Aucun abus n'est affirmé comme ayant eu lieu.
- PR #26 reste ouverte, en brouillon et non fusionnée. Aucune écriture de données, migration, policy ou configuration Supabase production ; aucun déploiement de production ; aucune modification des règles de protection.

## OFFER-QA-05 — vérifier l'absence d'offre après devise NULL (28 octobre 2026, 15:34 KST)

- **Écart de couverture constaté :** le test `fixture-null-currency` attendait bien l'erreur `INVALID_CURRENCY`, mais le contrôle final qui vérifie l'absence de lignes `offers` pour les appels rejetés n'incluait pas le nom `Null Currency Offer`.
- **Modification de test :** commit `59d7d15dd729e03348fca721e8afdd476d267124`, fichier `tests/sql/create-offer-runtime.sql`. Le contrôle final inclut désormais `Null Currency Offer` dans la liste des offres interdites après échec ; aucune logique applicative ou migration n'a été modifiée.
- **Résultats finaux vérifiés sur le HEAD `e97cd93d24447b46557045d59ce28725338185a7` (15:36 KST) :**
  - QIMA CI run [40644687050](https://github.com/meridane/QimaTrade-MVP/actions/runs/40644687050) : **SUCCESS** ; les deux jobs ont terminé avec succès.
  - Installation `npm ci` depuis le lockfile commité : SUCCESS.
  - Audit des dépendances au seuil `high` : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Installation Chromium et tests Playwright : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER/concurrence : SUCCESS, y compris l'assertion ajoutée pour vérifier que `Null Currency Offer` n'est pas créé après le rejet de la devise `NULL`.
  - Régressions synthétiques messages-RLS et auto-inscription participants : SUCCESS.
  - Artefacts `committed-package-lock` et `npm-audit-report` téléversés : SUCCESS.
  - CodeQL run [40644687021](https://github.com/meridane/QimaTrade-MVP/actions/runs/40644687021) : **SUCCESS**.
  - Vercel Preview : **SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/cGcG51K8kn8CBiyBTDntnDiGF993)), preview uniquement.
- **Note sur les runs intermédiaires :** le run QIMA CI [40644605579](https://github.com/meridane/QimaTrade-MVP/actions/runs/40644605579) sur le commit de test `59d7d15` a été annulé par la concurrence après que les étapes de test et de build aient réussi. Le run complet [40644687050](https://github.com/meridane/QimaTrade-MVP/actions/runs/40644687050) sur le HEAD qui inclut ce test est le résultat de référence.
- **Garde-fous :** test destiné à PostgreSQL isolé CI. Aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucun merge, déploiement de production ou changement de protection de branche.

## OFFER-QA-06 — devise composée uniquement d'espaces (28 octobre 2026, 16:28 KST)

- **État de départ :** PR #26 ouverte en brouillon, branche `fix/create-offer-status-contract`, HEAD précédent `fd2165d2790acab2a3568f516502858c466a6e58`. Les contrôles de ce HEAD étaient réussis ; le présent ajout de test devait être validé séparément.
- **Modification :** commit `64b1503cedccf8fa44707cf067e8d7d396086af5`, fichier `tests/sql/create-offer-runtime.sql`.
  - Ajout du cas négatif `fixture-whitespace-currency`, avec `p_currency = '   '`, qui attend `INVALID_CURRENCY`.
  - Ajout de `Whitespace Currency Offer` à l'assertion finale qui garantit qu'aucune offre rejetée n'a été créée.
  - Aucun code applicatif ni migration SQL n'a été modifié.
- **Contrôles vérifiés sur le commit `64b1503cedccf8fa44707cf067e8d7d396086af5` :**
  - QIMA CI run [40650344416](https://github.com/meridane/QimaTrade-MVP/actions/runs/40650344416), run #255 : **SUCCESS**.
  - Installation depuis le lockfile avec `npm ci` : SUCCESS.
  - Audit des dépendances au seuil `high` : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Tests navigateur Playwright : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER/concurrence et régressions synthétiques RLS : SUCCESS, incluant le cas devise composée d'espaces.
  - Artefacts de rapport d'audit et de lockfile : téléversés avec succès.
  - CodeQL run [40650344363](https://github.com/meridane/QimaTrade-MVP/actions/runs/40650344363), run #218 : **SUCCESS**.
  - Vercel Preview : **SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/2T4pYCdkDVwraXgUbCgDTfKiw4n5)), preview uniquement.
- **Portée et limites :** ces résultats valident les contrôles exécutés sur ce commit et les scénarios simulés. Ils ne constituent pas une preuve complète de sécurité sur Supabase production et ne confirment pas qu'une vulnérabilité a été exploitée.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucun merge, déploiement de production ou changement des règles de protection.
- **Prochaine étape non bloquante :** continuer la couverture des validations d'entrée avec un cas de devise entourée d'espaces (par exemple `' USD '`) et vérifier que le contrat reste cohérent entre API et RPC. Le blocage métier distinct concernant l'éligibilité fournisseur/tenant/demande demeure non résolu et ne doit pas être codé sans décision métier approuvée.

### OFFER-QA-06-DOC — validation du registre après consignation des résultats (28 octobre 2026, 16:29 KST)

- Le commit documentaire précédent `3ac6d6e4fe9b191342b7600a471c9d67e4478e20` a lui-même été contrôlé après la mise à jour du registre.
- QIMA CI run [40650490991](https://github.com/meridane/QimaTrade-MVP/actions/runs/40650490991), run #256 : **SUCCESS** ; `npm ci`, audit npm, TypeScript, build de production, Playwright, tests PostgreSQL CREATE_OFFER/concurrence, régressions synthétiques RLS et téléversement des artefacts ont réussi.
- CodeQL run [40650491003](https://github.com/meridane/QimaTrade-MVP/actions/runs/40650491003), run #219 : **SUCCESS**.
- Vercel Preview : **SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/9DScwS4kGpCaorvMaBWS1qTYyd6V)), preview uniquement.
- Ces résultats valident le commit documentaire indiqué ; ils ne constituent pas une validation de Supabase production. Aucune donnée ou migration de production n'a été modifiée, aucun merge ou déploiement de production n'a été effectué.

## OFFER-QA-07 — devise entourée d'espaces rejetée par le RPC (28 octobre 2026, 17:51 KST)

- **État de départ relu :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`. HEAD de test `b2fd0c1a37676526d0564626f4d3ea5cfaa0d66c`.
- **Modification :** commit `b2fd0c1a37676526d0564626f4d3ea5cfaa0d66c`, fichier `tests/sql/create-offer-runtime.sql`.
  - Ajout du cas `fixture-padded-currency` avec `p_currency = ' USD '`.
  - Le contrat RPC strict attend `INVALID_CURRENCY` pour une devise non canonique ; le nom `Padded Currency Offer` est aussi inclus dans l'assertion finale vérifiant qu'aucune offre rejetée n'a été créée.
  - Aucun code applicatif ni fichier de migration n'a été modifié. Le test s'exécute uniquement dans PostgreSQL isolé de CI.
- **Contrôles vérifiés sur le commit de test `b2fd0c1a37676526d0564626f4d3ea5cfaa0d66c` :**
  - QIMA CI run [40659598728](https://github.com/meridane/QimaTrade-MVP/actions/runs/40659598728), run #258 : **SUCCESS**.
  - `npm ci` depuis le lockfile commité : SUCCESS.
  - Audit des dépendances : SUCCESS.
  - TypeScript : SUCCESS.
  - Build de production : SUCCESS.
  - Tests Playwright : SUCCESS.
  - Tests PostgreSQL isolés CREATE_OFFER/concurrence : SUCCESS, y compris le nouveau cas `' USD '` et l'assertion d'absence d'offre après rejet.
  - Régressions synthétiques messages-RLS et auto-inscription des participants : SUCCESS. Ces résultats ne constituent pas, seuls, une preuve d'exploitabilité ou d'absence de vulnérabilité dans Supabase production.
  - Artefacts d'audit npm et du lockfile commité : téléversés avec succès.
  - CodeQL run [40659598727](https://github.com/meridane/QimaTrade-MVP/actions/runs/40659598727), run #221 : **SUCCESS**.
  - Vercel Preview : **SUCCESS** ([détails](https://vercel.com/bmk1/qimatrade-mvp/6fVjoAs6u5TitQ1HuNFAUG7Q9NCs)), preview uniquement.
- **Interprétation :** la fonction SQL attend une devise canonique ; la route HTTP normalise les espaces extérieurs avant validation. Ce test couvre le contrat du RPC lorsqu'il est appelé directement, sans prétendre qu'une requête HTTP avec espaces échoue. Il ne change aucune règle métier.
- **Blocages toujours ouverts :** la règle d'autorisation fournisseur/tenant/demande nécessite une décision métier documentée ; le Security Gate reste **NOT PASS** jusqu'à sa validation et aux tests d'autorisation correspondants.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucun merge, déploiement de production ou changement des règles de protection.
- **Prochaine tâche non bloquante :** examiner les validations de format des paramètres CREATE_OFFER déjà couvertes par le contrat existant et ajouter un test de régression isolé uniquement si un écart concret est constaté. Ne pas décider implicitement de l'éligibilité fournisseur.



## Audit sécurité immédiat — 28 octobre 2026

- **Security Gate : NOT PASS.**
- **SEC-P0-01 — Messages :** la fonction déployée `public.is_message_participant` contient une branche qui considère l'utilisateur participant dès que son propre acteur correspond à `sender_actor_id`, sans relier cette branche à la demande/offre ciblée. Risque logique d'insertion de message hors conversation ; confirmé par lecture de la fonction réelle, aucun exploit ni écriture de production exécuté.
- **SEC-P0-02 — Grants :** des privilèges de table larges, dont `TRUNCATE`, apparaissent dans les grants de rôles `anon` et/ou `authenticated` sur plusieurs tables. Il faut inventorier les besoins puis préparer des révocations minimales testées ; un grant seul ne prouve pas que l'API REST expose chaque opération.
- **SEC-P1-03 — CREATE_OFFER :** lien d'autorisation tenant/demande/fournisseur non établi ; règle métier à définir.
- **SEC-P1-04 — Offres historiques :** `app/api/offers/route.ts` écrit directement dans la table et reste un contrat séparé.
- **SEC-P1-05 — Demandes produit :** `app/api/product-requests/route.ts` choisit le premier membership sans gérer plusieurs tenants, contrairement à la route de publication.
- **Rapport complet :** `docs/SECURITY_AUDIT_2026-10-28.md`.
- **Portée :** lecture de sources et SELECT Supabase uniquement. Aucune donnée, policy ou migration de production modifiée ; aucune fusion ni mise en production.



### SEC-P0-01 — Correctif de participation aux messages préparé (28 octobre 2026)

- Migration branche-only : `supabase/migrations/20261028180000_fix_message_participant_authorization.sql`.
- Le helper lie maintenant le profil authentifié à la demande ou à l'offre correspondante et vérifie que l'offre appartient à la demande ciblée.
- Test isolé ajouté pour l'accès en lecture d'un utilisateur étranger : `tests/sql/legacy-messages-rls-regression.sql`.
- Commits : `69c20a5dbc4e4f15c694932deed88269b8d5ee88`, `a59288626d0cadc93e4636c3b14f7bd32c383377`, puis documentation.
- Statut : **IMPLÉMENTÉ SUR BRANCHE / TESTS CI EN ATTENTE**. Le correctif n'est pas appliqué en production.
- Prochaine étape : CI/CodeQL, inspection des tests et vérification des grants avant de proposer la migration à un environnement isolé.



## SEC-P0-01 — résultats CI du correctif de participation aux messages (28 octobre 2026, 18:43 KST)

- **État vérifié :** PR #26 toujours ouverte, en brouillon et non fusionnée ; HEAD vérifié 93e20ebcf6968c52d497dfb795d9f578ae2b96e3.
- **QIMA CI** [run 40662397733](https://github.com/meridane/QimaTrade-MVP/actions/runs/40662397733) : **SUCCESS**. Les jobs TypeScript/audit/build/Playwright et tests PostgreSQL isolés ont terminé avec succès. Le job PostgreSQL a exécuté les tests CREATE_OFFER/concurrence, la régression synthétique RLS des messages et la régression synthétique d'auto-inscription des participants.
- **CodeQL** [run 40662397677](https://github.com/meridane/QimaTrade-MVP/actions/runs/40662397677) : **SUCCESS**.
- **Vercel Preview : SUCCESS** ([prévisualisation](https://vercel.com/bmk1/qimatrade-mvp/HK2ytxBVwQz4zThCakZJ7juX6Xge)), sans déploiement de production.
- **Portée :** les tests PostgreSQL s'exécutent dans une base jetable et les assertions RLS sont synthétiques. Ces résultats valident les scénarios testés, pas la fonction déployée dans Supabase ni l'absence de vulnérabilité en production.
- **Statut :** correctif SEC-P0-01 présent uniquement sur la branche ; vérification dans un environnement non-production avec schéma représentatif et revue restent nécessaires. Le Security Gate reste **NOT PASS**.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase de production modifiée ; aucune fusion ni mise en production.

## SEC-P0-02 — relevé en lecture seule des privilèges SQL (28 octobre 2026, 18:43 KST)

- **Méthode :** requêtes SELECT uniquement sur les métadonnées PostgreSQL du projet Supabase QIMA, sans exécuter de modification ni de requête destructive.
- **Résultat de has_table_privilege sur les 102 tables du schéma public :** anon dispose effectivement du privilège SQL TRUNCATE sur 98 tables et authenticated sur 100 tables ; DELETE est effectif pour anon sur 34 tables et pour authenticated sur 37 tables.
- **Échantillon vérifié :** pour demands, offers, profiles, messages, dt_sessions et product_requests, le privilège TRUNCATE est effectif pour les deux rôles. Le privilège DELETE de anon est effectif sur demands, offers et profiles dans cet échantillon ; authenticated possède DELETE sur les six tables listées.
- **Interprétation et limites :** cela confirme l'état des privilèges SQL rapportés par PostgreSQL, pas qu'une opération est exposée par chaque chemin HTTP/PostgREST, ni qu'une suppression a eu lieu. RLS ne remplace pas les privilèges de table et ne filtre pas TRUNCATE ; l'usage applicatif de chaque privilège doit être vérifié avant toute révocation.
- **Prochaine tâche non bloquante :** inventorier les usages applicatifs et les grants/migrations qui les accordent, puis préparer une réduction minimale des privilèges et des tests sur une base isolée. Ne pas exécuter de REVOKE en production ni créer une migration corrective sans validation en environnement non-production.
- **Garde-fous :** inspection en lecture seule uniquement ; aucune donnée, migration, policy ou configuration Supabase de production modifiée.

## OFFER-QA-08 — devise en minuscules rejetée par le contrat RPC (28 octobre 2026, 19:49 KST)

- **État de départ relu :** PR #26 ouverte, en brouillon, non fusionnée ; branche `fix/create-offer-status-contract`, HEAD précédent `77fa70560728deaca27fd6386d1f7e0a5eaee7ff`. Le registre et les checks du HEAD précédent ont été consultés avant modification.
- **Modification de test :** commit `98bae5465952250057b5b96403d53df758814d9a`, fichier `tests/sql/create-offer-runtime.sql`.
  - Ajout du cas `fixture-lowercase-currency` avec `p_currency = 'usd'`, qui attend `INVALID_CURRENCY` puisque le contrat SQL exige un code canonique.
  - Ajout de `Lowercase Currency Offer` à l'assertion finale qui garantit qu'aucune offre rejetée n'a été créée.
  - Aucun code applicatif, migration ou environnement Supabase n'a été modifié.
- **Contrôles après le commit de test :** interrogation GitHub Actions pour le SHA `98bae5465952250057b5b96403d53df758814d9a` : aucun workflow PR n'était retourné à cet instant ; le statut combiné ne retournait aucun check. **CI non encore vérifiable / en attente**, et non « réussi ». Le connecteur disponible ne fournit pas d'action de dispatch manuel de workflow ; aucune réussite n'est supposée.
- **Prochaine étape :** vérifier si GitHub Actions démarre pour ce commit, puis contrôler PostgreSQL isolé, TypeScript/build/Playwright, audit dépendances et CodeQL avant de qualifier le test comme validé. Si aucun run ne démarre, déclencher le workflow via l'interface GitHub ou un mécanisme autorisé, puis mettre à jour ce registre avec les liens et résultats réels.
- **Portée et limites :** test strict du RPC dans PostgreSQL jetable ; ne démontre pas que la route HTTP refuse `usd` de la même façon, car celle-ci peut normaliser la saisie en amont. Aucun constat de vulnérabilité ne découle de ce test isolé.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-09 — contrat devise API versus RPC (28 octobre 2026, 20:26 KST)

- **État de départ vérifié :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD `17bd6b8f92caf211c45a0d8213a92bdeb962850c`.
- **Contrôles avant cette modification documentaire :** QIMA CI [run 40675293712](https://github.com/meridane/QimaTrade-MVP/actions/runs/40675293712) : SUCCESS (Typecheck/audit/build/browser tests et PostgreSQL CREATE_OFFER/concurrency) ; CodeQL [run 40675293655](https://github.com/meridane/QimaTrade-MVP/actions/runs/40675293655) : SUCCESS ; statut Vercel sur ce HEAD : SUCCESS ([preview](https://vercel.com/bmk1/qimatrade-mvp/3wxFDZKoaHhggqAaQQxw4pa5Qnvz)).
- **Observation du code** dans `app/api/actions/create-offer/route.ts` : la route fait `body.currency.trim()`, puis vérifie la valeur contre la liste exacte `USD, EUR, KRW, MAD, CNY`, sans conversion en majuscules. Ainsi, une entrée HTTP `" USD "` devient `"USD"` avant validation ; `"usd"` reste en minuscules et est rejetée. Le RPC SQL, appelé directement dans `tests/sql/create-offer-runtime.sql`, attend le rejet des valeurs non canoniques avec espaces ou en minuscules.
- **Interprétation :** les tests SQL couvrent le contrat direct du RPC, pas le comportement HTTP de normalisation. Il n'y a pas de contradiction démontrée dès lors que les couches reçoivent des valeurs différentes ; le comportement actuel doit être documenté et testé au niveau de la route.
- **Prochaine tâche non bloquante :** ajouter un test de régression au niveau de la route avec le harness existant pour confirmer `" USD "` accepté après trim et `"usd"` rejeté. Ne pas changer la normalisation ni imposer une conversion de casse sans décision explicite sur le contrat souhaité.
- **Portée et limites :** revue statique du code et résultats CI précédant cette mise à jour documentaire ; aucune preuve de vulnérabilité ne découle de ces tests. Les checks du nouveau commit documentaire doivent être vérifiés séparément.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.



## OFFER-QA-10 — régression HTTP CREATE_OFFER sur le contrat de devise (28 octobre 2026, 21:27 KST)

- **État de départ vérifié :** PR #26 ouverte, en brouillon et non fusionnée ; HEAD de départ `ef89ec18a52cf9900136d7d6248dd96ecc030c73`. QIMA CI [run 40680079639](https://github.com/meridane/QimaTrade-MVP/actions/runs/40680079639) et CodeQL [run 40680079625](https://github.com/meridane/QimaTrade-MVP/actions/runs/40680079625) étaient SUCCESS sur ce HEAD ; statut Vercel Preview SUCCESS.
- **Modifications de régression :**
  - Commit `e5e5ad6fd6a5a1af3af7605fd274d365cac2db91` : ajout de `tests/e2e/create-offer-route-contract.spec.ts`. Le test appelle la vraie fonction `POST` avec un client Supabase entièrement simulé, vérifie que `" USD "` est normalisé en `"USD"` avant le RPC, et que `"usd"` est rejeté avant toute requête REST/RPC.
  - Commit `4fec8052dcdbef2341c818a9e0e7325cd93e2ae7` : import relatif du runtime dans `app/api/actions/create-offer/route.ts`, afin que le test isolé puisse importer la route sans dépendre de l'alias Next.js à l'exécution. Aucun changement de logique métier.
- **Contrôles après modification, HEAD `4fec8052dcdbef2341c818a9e0e7325cd93e2ae7` :** QIMA CI [run 40688214944](https://github.com/meridane/QimaTrade-MVP/actions/runs/40688214944) : **PENDING** au dernier contrôle ; CodeQL [run 40688214952](https://github.com/meridane/QimaTrade-MVP/actions/runs/40688214952) : **IN PROGRESS** ; statut Vercel Preview : **PENDING**. Aucun résultat de test pour ces commits n'est déclaré réussi tant que les runs ne sont pas terminés.
- **Prochaine étape :** relire les conclusions CI, en particulier TypeScript et le test Playwright `CREATE_OFFER route currency`. Corriger tout échec, puis consigner les résultats finaux. Si les runs restent absents ou en attente, ne pas supposer la réussite.
- **Portée et limites :** le test utilise des réponses Supabase simulées ; il vérifie la validation et le contrat d'appel de la route, pas le comportement d'une instance Supabase réelle. Aucun constat de vulnérabilité n'est déduit de ce test synthétique.
- **Garde-fous :** aucun accès aux données, migrations, policies ou configuration Supabase production ; aucun merge, déploiement de production ou changement des protections de branche.

## OFFER-QA-11 — diagnostic du premier échec du test de contrat HTTP (28 octobre 2026, 21:22 KST)

- **État relu avant intervention :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD `4057d1ab237cb5746a896d69795ea34688579f7a`.
- **Contrôles du HEAD avant cette modification :** QIMA CI [run 40688322328](https://github.com/meridane/QimaTrade-MVP/actions/runs/40688322328) : **FAILURE**. `npm ci`, audit npm, TypeScript et build production ont réussi. Playwright : 20 tests réussis ; le test `CREATE_OFFER route trims whitespace around a supported currency before the RPC` a échoué (attendu HTTP 200, reçu HTTP 400) ; le test suivant a été ignoré après l'échec en mode sériel. Le job PostgreSQL isolé CREATE_OFFER/concurrence et les deux régressions synthétiques RLS ont réussi.
- **CodeQL** [run 40688322383](https://github.com/meridane/QimaTrade-MVP/actions/runs/40688322383) : **SUCCESS**. Le statut Vercel est SUCCESS sur une prévisualisation uniquement.
- **Modification suivante :** améliorer le message d'assertion du test `tests/e2e/create-offer-route-contract.spec.ts` afin que le prochain échec affiche la réponse HTTP et les chemins REST/RPC observés. Cette instrumentation n'altère pas le comportement métier et vise à distinguer un problème du mock de l'API d'un problème de contrat.
- **Résultat de la nouvelle version :** CI/CodeQL à vérifier après le commit de diagnostic ; aucun résultat n'est présumé à ce stade.
- **Garde-fous :** aucun changement de logique métier ou de migration ; aucune lecture/écriture de données, migration, policy ou configuration Supabase production ; aucun merge, déploiement de production ou changement des protections de branche.



## OFFER-QA-12 — correction du mock WebSocket dans le test de route (28 octobre 2026, 23:17 KST)

- **État relu :** PR #26 ouverte, en brouillon, non fusionnée ; le HEAD précédent était `6d465206a36e1b4b7c5df8808f8a92920440aaaa`.
- **Diagnostic établi depuis les logs GitHub Actions** [QIMA CI run 40696121255](https://github.com/meridane/QimaTrade-MVP/actions/runs/40696121255) : le test de route échouait avant tout appel REST, avec `Node.js 20 detected without native WebSocket support`. Le problème provenait de l'initialisation Realtime du client Supabase dans l'environnement de test, et non de la validation de devise.
- **Correction de test :** commit `b8cee2c5aeea35867dbab8c00eea97d878312e46`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le test isolé fournit temporairement un constructeur WebSocket factice si Node n'en fournit pas, puis restaure la valeur d'origine. Aucun code métier, migration SQL ou configuration de production n'a été modifié.
- **Résultat après correction :** CI/CodeQL/Preview du nouveau HEAD à vérifier ; aucun résultat n'est déclaré réussi avant la fin des contrôles.
- **Portée et limites :** ce mock est destiné uniquement au test de route qui n'utilise pas Realtime. Il ne valide pas l'usage de Realtime sous Node 20 en production.
- **Garde-fous :** aucune écriture Supabase, migration, fusion, mise en production ou modification des protections de branche.

## OFFER-QA-13 — valeurs de devise non textuelles et validation CI (28 octobre 2026, 23:56 KST)

- **État relu avant cette entrée :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD `169875c1ae4146c876c7d3172f2ef218db7613c1`.
- **Régression ajoutée :** commit `169875c1ae4146c876c7d3172f2ef218db7613c1`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le helper de test accepte désormais une valeur inconnue et le test vérifie que `currency: null` et `currency: 123` retournent HTTP 400 avec `INVALID_CURRENCY`, sans requête REST/RPC. Aucun code métier n'a été modifié.
- **QIMA CI** [run 40711039137](https://github.com/meridane/QimaTrade-MVP/actions/runs/40711039137) : **SUCCESS**. Installation, audit des dépendances au seuil configuré, TypeScript, build de production et tests navigateur réussis ; **24 tests Playwright passés**, dont les quatre cas du contrat devise de la route. Le job PostgreSQL jetable a aussi réussi les assertions CREATE_OFFER, concurrence/idempotence et les deux suites RLS synthétiques.
- **CodeQL** [run 40711039345](https://github.com/meridane/QimaTrade-MVP/actions/runs/40711039345) : **SUCCESS**. Statut Vercel **SUCCESS** sur une prévisualisation uniquement : [Preview](https://qimatrade-mvp-git-fix-create-offer-status-contract-bmk1.vercel.app).
- **Limites d'interprétation :** les fixtures PostgreSQL et tests RLS sont synthétiques et isolés ; ils ne prouvent ni ne réfutent à eux seuls une vulnérabilité dans Supabase production. Le succès des contrôles ne vaut pas approbation métier ni validation complète de bout en bout.
- **Prochaine priorité / blocage métier :** documenter le modèle d'appartenance qui relie une demande (`demandId`) au tenant sélectionné avant de renforcer l'autorisation et d'ajouter les tests négatifs correspondants. La règle ne doit pas être inventée : le modèle métier/ownership doit être décidé et validé. En attendant, poursuivre uniquement les tests et revues non bloquants.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-14 — validation quantité/prix de CREATE_OFFER et CI (29 octobre 2026)

- **État avant cette entrée :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD `71058b6ef9d7e79506698578ca716536e1f537ff`.
- **Régression ajoutée :** commit `71058b6ef9d7e79506698578ca716536e1f537ff`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Quatre cas négatifs couvrent quantité nulle, quantité non numérique, prix négatif et prix composé d'espaces. Chaque cas attend HTTP 400 avec `INVALID_QUANTITY` ou `INVALID_PRICE`, et vérifie qu'aucune requête REST/RPC n'est émise.
- **QIMA CI** [run 40713652353](https://github.com/meridane/QimaTrade-MVP/actions/runs/40713652353) : **SUCCESS**. Installation réussie ; `npm audit --audit-level=high` rapporte 0 vulnérabilité (0 critical/high/moderate/low) ; TypeScript et build réussis ; Playwright **25/25 tests réussis** ; tests PostgreSQL isolés CREATE_OFFER/concurrence et suites de régression RLS synthétiques réussis.
- **CodeQL** [run 40713652350](https://github.com/meridane/QimaTrade-MVP/actions/runs/40713652350) : l'étape d'analyse JavaScript/TypeScript est terminée avec succès ; la finalisation du workflow était encore en cours au dernier relevé. Le statut Vercel associé au commit est **SUCCESS** pour une prévisualisation uniquement, [détails de déploiement](https://vercel.com/bmk1/qimatrade-mvp/Ajsei9UBdgsM95oVLMph8erp13av).
- **Avertissement non bloquant :** le build affiche toujours un avertissement sur l'usage de `process.version` par `@supabase/supabase-js` dans le contexte Edge Runtime ; le build a réussi. À analyser séparément avant de modifier les runtimes.
- **Limites :** les tests PostgreSQL/RLS utilisent une base jetable et des fixtures synthétiques ; ils ne prouvent ni ne réfutent à eux seuls une vulnérabilité de Supabase production. Aucun code métier, donnée ou migration Supabase production n'a été modifié.
- **Prochaine tâche non bloquante :** étendre le test de route aux corps JSON mal formés et aux corps de type tableau, afin de vérifier le rejet propre avant tout accès REST/RPC. Le test d'autorisation liant `demandId` au tenant reste bloqué par la décision métier sur le modèle d'appartenance.
- **Garde-fous :** aucune fusion, mise en production ou modification des protections de branche.


## OFFER-QA-15 — corps JSON mal formés de CREATE_OFFER (29 octobre 2026)

- **État de départ relu :** PR #26 ouverte, en brouillon, non fusionnée ; HEAD précédent `5ef80d288afd94365d1a7e2b9d73b9b8f66f3589`. Sur ce HEAD, QIMA CI [run 40713938428](https://github.com/meridane/QimaTrade-MVP/actions/runs/40713938428) et CodeQL [run 40713938430](https://github.com/meridane/QimaTrade-MVP/actions/runs/40713938430) ont finalement terminé avec succès ; la prévisualisation Vercel était SUCCESS.
- **Correction de route :** commit `3e2db1dbaa95ae9358a70bf745fbcf33eb55e0dc`, fichier `app/api/actions/create-offer/route.ts`. La route renvoie maintenant le code stable `INVALID_REQUEST_BODY` (HTTP 400) si le corps JSON est illisible ou n'est pas un objet JSON accepté, au lieu de transmettre le message d'exception du parseur. Le traitement métier après validation reste inchangé.
- **Tests de régression :** commit `f02e8792cefba812de705b8641e99b4b748a6825`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le helper permet de fournir le corps brut ; deux tests vérifient un JSON mal formé et un tableau JSON, avec HTTP 400, erreur stable `INVALID_REQUEST_BODY` et aucune requête REST/RPC vers `/rest/v1/`.
- **Contrôles après modification :** le workflow déclenché sur le commit de route `3e2db1d` est visible comme QIMA CI [run 40724566176](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724566176) et CodeQL [run 40724566174](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724566174) ; tous deux étaient encore **IN PROGRESS** au dernier relevé. Le statut Vercel de ce commit était **PENDING**. Aucun run GitHub Actions n'était encore retourné pour le HEAD de test `f02e879` lors de ce relevé. Les nouveaux tests ne sont donc pas encore marqués comme réussis.
- **Prochaine étape :** attendre la fin des runs existants, vérifier si CI/CodeQL démarrent pour le HEAD `f02e879`, puis consigner les résultats définitifs. Si aucun run ne démarre pour le HEAD, utiliser un mécanisme autorisé de déclenchement ou signaler que la validation reste en attente ; ne pas supposer la réussite.
- **Limites :** les tests appellent la route avec un client Supabase simulé. Ils vérifient le contrat HTTP et l'absence d'appels REST/RPC métier pour ces entrées ; ils ne valident pas un environnement Supabase réel ni le modèle d'autorisation tenant/demande.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.


### OFFER-QA-15 — suivi du typage et des contrôles après correction (29 octobre 2026)

- **Échec détecté dans la CI :** QIMA CI [run 40724566176](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724566176), job TypeScript. L'erreur `TS2345` signalait que `body.attributes`, rétréci au type générique `object`, ne correspondait pas à la valeur autorisée par `ActionInput`. L'audit npm était à zéro vulnérabilité signalée ; le build et les tests navigateur n'ont pas été exécutés dans ce job après l'échec du typecheck. Le run a ensuite été annulé lors d'un push plus récent.
- **Correction ciblée :** commit `73ec1ddb81dfcdca1f88a47a36d3ed5319ac4f54`, fichier `app/api/actions/create-offer/route.ts`. Après vérification que la valeur est un objet et non un tableau, le champ `attributes` est explicitement typé comme `Record<string, unknown>`, conformément au type `ActionInputValue`. Aucun changement de règle métier ou d'accès aux données.
- **État de validation :** le run QIMA CI [40724609249](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724609249) a été annulé après une mise à jour plus récente ; le job PostgreSQL isolé avait réussi, mais le job navigateur était annulé avant l'installation des dépendances et le typecheck. CodeQL [run 40724609151](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724609151) était encore en cours au dernier relevé. Le statut Vercel du HEAD `73ec1dd` était PENDING et aucun run CI/CodeQL complet n'était encore retourné pour ce HEAD.
- **Action suivante :** la CI doit valider le HEAD final après cette correction, notamment TypeScript, build, les deux nouveaux tests de corps JSON, PostgreSQL isolé et CodeQL. Ne pas déclarer la correction VALIDÉE avant ces résultats.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.


## OFFER-QA-16 — rejet des types non scalaires pour quantité et prix CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD précédent `73e76bccaf34ef5c2c8ab1e6fa58b75972bb2d14`. Sur ce HEAD, QIMA CI [run 40724778672](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724778672) : **SUCCESS** (typecheck/audit/build/tests navigateur et tests PostgreSQL isolés) ; CodeQL [run 40724778678](https://github.com/meridane/QimaTrade-MVP/actions/runs/40724778678) : **SUCCESS** ; statut Vercel : **SUCCESS** pour une prévisualisation uniquement.
- **Modification de code et de régression :** commit `b6f3baed31cd4bd31429aae9346883b7c223558e`.
  - `app/api/actions/create-offer/route.ts` : quantité et prix acceptent désormais seulement un nombre ou une chaîne numérique non vide avant conversion. Les booléens, tableaux, objets et autres types non scalaires sont rejetés par la validation existante avec `INVALID_QUANTITY` ou `INVALID_PRICE`.
  - `tests/e2e/create-offer-route-contract.spec.ts` : ajout de quatre cas négatifs pour quantité booléenne/tableau et prix booléen/tableau, en vérifiant HTTP 400 et l'absence d'appels REST métier.
  - Les chaînes numériques restent acceptées pour préserver les formulaires qui transmettent les champs sous forme de texte ; aucune règle métier liée au tenant ou à la demande n'a été modifiée.
- **Contrôles après modification :** juste après le push du commit `b6f3baed31cd4bd31429aae9346883b7c223558e`, l'interrogation GitHub Actions par SHA ne retournait encore aucun workflow et aucun statut combiné. **Validation du nouveau HEAD en attente** ; les succès du HEAD précédent ne sont pas considérés comme validation de cette modification.
- **Prochaine étape :** vérifier les runs QIMA CI et CodeQL du nouveau HEAD et consigner leurs résultats. Si aucun run ne démarre, la validation reste non vérifiée ; ne pas déclarer les tests réussis sur la seule base du code.
- **Limites d'interprétation :** ces tests de route utilisent un client Supabase simulé et ne prouvent pas à eux seuls une vulnérabilité ou son absence en production. Le modèle métier d'appartenance entre `demandId` et tenant reste une décision bloquante à documenter avant toute modification d'autorisation.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-17 — compatibilité des chaînes numériques CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD `aeadb729888f55dd04093b04ffa1d67cc09b9564`. Sur ce HEAD, QIMA CI [run 40741631846](https://github.com/meridane/QimaTrade-MVP/actions/runs/40741631846) : **SUCCESS** ; CodeQL [run 40741631943](https://github.com/meridane/QimaTrade-MVP/actions/runs/40741631943) : **SUCCESS** ; Vercel : **SUCCESS** pour une prévisualisation uniquement.
- **Régression ajoutée :** commit `99f141655913304faea0a08ced419177ffc4ee15`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le nouveau test envoie `quantity: "2"` et `price: "12.5"`, attend HTTP 200 et vérifie que l'appel RPC reçoit les nombres `p_quantity: 2` et `p_price: 12.5`. Aucun code métier, schéma ou donnée de production n'a été modifié.
- **Contrôles sur le commit de test :** QIMA CI [run 40743422379](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743422379) : **SUCCESS** — installation `npm ci`, audit npm (0 vulnérabilité signalée aux niveaux info/low/moderate/high/critical), TypeScript, build de production, **28 tests Playwright réussis**, tests d'intégration CREATE_OFFER/concurrence dans PostgreSQL jetable et deux suites de régression RLS synthétiques réussis. CodeQL [run 40743422338](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743422338) : **SUCCESS**. Vercel pour le commit de test : **SUCCESS** en Preview uniquement.
- **État du HEAD documentaire :** après l'entrée initiale, le commit de registre `a850c63667931d760bc3ad480d964d97a5304ba0` a déclenché QIMA CI [run 40743590675](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743590675) et CodeQL [run 40743591122](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743591122). Tous deux étaient **IN PROGRESS** au dernier relevé et Vercel était **PENDING**. Cette mise à jour documentaire déclenche un nouveau cycle ; vérifier les contrôles associés au HEAD final avant de déclarer la branche entièrement validée.
- **Portée et limites :** le test utilise un client Supabase simulé ; il vérifie la conversion des entrées au contrat RPC, mais ne valide pas le comportement d'une instance Supabase réelle et ne prouve ni ne réfute à lui seul une vulnérabilité de production. Le modèle métier d'autorisation reliant `demandId` au tenant reste bloqué par une décision d'appartenance explicite.
- **Prochaine étape :** vérifier QIMA CI, CodeQL et Vercel sur le HEAD final, puis actualiser ce registre avec les conclusions réelles. Si un contrôle échoue, corriger uniquement la cause démontrée et ajouter un test de régression ciblé.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-18 — chaînes numériques non finies CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD précédent `f8e52f23ce9d2465d39c292415c07a261032eb80`. Sur ce HEAD, QIMA CI [run 40743688745](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743688745) : **SUCCESS** ; CodeQL [run 40743688805](https://github.com/meridane/QimaTrade-MVP/actions/runs/40743688805) : **SUCCESS** ; statut Vercel : **SUCCESS** en Preview uniquement.
- **Régression ajoutée :** commit `f39a50d28e010fc5c66c84d18c7f8931e23bd1fe`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Deux cas négatifs supplémentaires vérifient que `quantity: "Infinity"` et `price: "1e309"` sont rejetés avec HTTP 400 et l'erreur stable attendue, sans appel REST/RPC métier. Ils couvrent respectivement une conversion en valeur non finie et un dépassement numérique lors de `Number(...)`. Aucun code métier n'a été modifié.
- **Contrôles après modification :** immédiatement après le push, la recherche des workflows associés au SHA `f39a50d28e010fc5c66c84d18c7f8931e23bd1fe` n'a retourné aucun run QIMA CI ou CodeQL ; le statut combiné ne contenait aucun check GitHub Actions et indiquait **Vercel PENDING** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/HnDWq67Jpwp7es9Y9qD7k2NaMsnt)). **Les deux nouveaux tests ne sont donc pas encore validés par CI.** Le succès du HEAD précédent n'est pas extrapolé à ce changement.
- **Action suivante :** vérifier les runs du HEAD final après la mise à jour du registre. Si QIMA CI ou CodeQL ne démarre pas, déclencher un workflow par le mécanisme GitHub autorisé ou laisser explicitement la validation en attente ; ne pas déclarer les tests réussis sans résultat.
- **Limites et garde-fous :** tests de route utilisant un client Supabase simulé ; ils vérifient le contrat de validation HTTP et l'absence d'appels REST/RPC pour ces entrées, pas la sécurité de Supabase production. Aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.


## OFFER-QA-19 — rejet des identifiants obligatoires vides ou mal typés CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, brouillon et non fusionnée ; HEAD initial de cette exécution `0592be7939a26a378fea519ff084e9358ecaba92`. Sur ce HEAD, QIMA CI [run 40757074631](https://github.com/meridane/QimaTrade-MVP/actions/runs/40757074631) : **SUCCESS** ; CodeQL [run 40757074865](https://github.com/meridane/QimaTrade-MVP/actions/runs/40757074865) : **SUCCESS** ; Vercel Preview : **SUCCESS**.
- **Régression ajoutée :** commit `e51709fe37fbfa6cc282f8d0fea7485fa7d14e1e`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Quatre cas vérifient que `name` vide/blanc ou non textuel, et `demandId` vide/blanc ou non textuel, sont rejetés avec HTTP 400 et `NAME_AND_DEMAND_REQUIRED`, sans appel REST/RPC sous `/rest/v1/`. Aucun code de production ni contrat métier n'a été modifié.
- **Contrôles après modification :** immédiatement après le push de `e51709f`, GitHub ne retournait encore aucun run QIMA CI/CodeQL et aucun statut combiné ; les contrôles du HEAD précédent ne valident pas ces nouveaux cas. **Validation du nouveau test en attente.**
- **Action suivante :** vérifier les workflows déclenchés par le commit de test et par cette mise à jour du registre. Ne pas déclarer les nouveaux tests réussis avant résultat CI sur le HEAD final.
- **Portée et limites :** tests Playwright de route avec client Supabase simulé ; ils vérifient le contrat HTTP et l'absence d'appels REST/RPC pour ces entrées, pas le comportement de Supabase production. Le modèle d'appartenance `demandId` ↔ tenant reste en attente d'une décision métier.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.


## OFFER-QA-20 — rejet des valeurs primitives JSON de CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD avant changement `8a3eb124a255a3c45fba68f49fe6bc74efd1bf68`. QIMA CI [run 40761278199](https://github.com/meridane/QimaTrade-MVP/actions/runs/40761278199) et CodeQL [run 40761278204](https://github.com/meridane/QimaTrade-MVP/actions/runs/40761278204) étaient terminés avec succès ; Vercel Preview était SUCCESS. Le registre était au blob `ed1d0b8049e93aa00bdb81c5d3d7ada1cc1e2edc`.
- **Régression ajoutée :** commit `c5208d405542149e4e806a2de94f987af8c7a555`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Un test en boucle couvre les corps JSON primitifs `null`, chaîne JSON, nombre et booléen. Chaque cas attend HTTP 400 avec `INVALID_REQUEST_BODY` et vérifie qu'aucun appel `/rest/v1/` n'a lieu. Aucun code de production, schéma ou donnée n'a été modifié.
- **Contrôles du commit de test :** QIMA CI [run 40772827661](https://github.com/meridane/QimaTrade-MVP/actions/runs/40772827661) — **QUEUED / jobs en cours** (tests PostgreSQL isolés et typecheck/audit/build/Playwright démarrés) ; CodeQL [run 40772827515](https://github.com/meridane/QimaTrade-MVP/actions/runs/40772827515) — **IN_PROGRESS**. Vercel Preview est encore PENDING. Aucun résultat final n'est déclaré pour ce test tant que ces runs n'ont pas terminé.
- **Étape suivante :** attendre la fin de CI/CodeQL/Preview sur le commit de test. Consigner les conclusions réelles, puis vérifier les contrôles déclenchés par la mise à jour du registre. Si un run échoue, lire les logs avant toute correction.
- **Portée et limites :** test de route avec client Supabase simulé ; il valide le contrat HTTP de rejet des primitives et l'absence d'appels REST/RPC métier pour ces entrées, pas la sécurité de Supabase production. Le modèle métier d'appartenance entre `demandId` et tenant reste à décider explicitement avant toute évolution des autorisations.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-21 — normalisation des champs optionnels CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; HEAD initial de cette exécution `59bac48190584a01b2234c70ed8513c9c5291e1c`. Sur ce HEAD, QIMA CI [run 40772876810](https://github.com/meridane/QimaTrade-MVP/actions/runs/40772876810) : **SUCCESS** (installation verrouillée, audit npm, TypeScript, build, Playwright et tests PostgreSQL isolés) ; CodeQL [run 40772876800](https://github.com/meridane/QimaTrade-MVP/actions/runs/40772876800) : **SUCCESS** ; Vercel : **SUCCESS** pour une Preview uniquement.
- **Régression ajoutée :** commit `b0fb2cc176b59efe5a7a13c33b8bab99c574d67d`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Un test transmet un tableau dans `attributes` et vérifie HTTP 200, `p_attributes: {}` et les valeurs par défaut `p_pricing_model: "fixed"`, `p_lifecycle: "draft"`, `p_offer_type: "supplier_offer"` dans l'appel RPC simulé. Aucun code de production, schéma ou donnée n'a été modifié.
- **Contrôles après le commit de test :** juste après le push, la recherche des workflows associés au SHA `b0fb2cc176b59efe5a7a13c33b8bab99c574d67d` n'a retourné aucun run GitHub Actions et le statut combiné ne contenait aucun check. **Le nouveau test reste non validé par CI** ; les succès du HEAD précédent ne lui sont pas attribués.
- **Étape suivante :** revérifier les runs QIMA CI, CodeQL et Vercel associés au HEAD après cette mise à jour du registre. Si aucun run ne démarre, garder explicitement la validation en attente plutôt que de conclure à la réussite.
- **Portée et limites :** le test utilise un client Supabase simulé ; il protège la normalisation des champs de la route et le contrat des paramètres RPC, mais ne constitue pas une validation de Supabase production. Le modèle métier d'appartenance `demandId` ↔ tenant reste en attente d'une décision explicite.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-22 — contrat de clé d'idempotence CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`. Le HEAD de code précédent `e4fef877ad89ab2898b6bee3b4408e2eb89537fc` avait QIMA CI [run 40782248196](https://github.com/meridane/QimaTrade-MVP/actions/runs/40782248196) : **SUCCESS** (PostgreSQL isolé, TypeScript, audit, build et Playwright) ; CodeQL [run 40782248232](https://github.com/meridane/QimaTrade-MVP/actions/runs/40782248232) : **SUCCESS** ; Vercel Preview : **SUCCESS**.
- **Régression ajoutée :** commit `6387f38a892f23864baf252a462cbc8539d8c4bb`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Deux cas vérifient qu'une clé explicite entourée d'espaces est transmise au RPC après `trim()`, et qu'une clé uniquement composée d'espaces est remplacée par un UUID v4 généré par la route. Le test utilise le fetch/Supabase simulé et ne contacte pas la production.
- **Contrôles après modification :** QIMA CI [run 40789182991](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789182991) a été interrompu par la concurrence lors du push suivant : l'intégration PostgreSQL a été annulée avant les tests et le job navigateur a eu des étapes annulées. CodeQL [run 40789182935](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789182935) était encore en cours au dernier relevé. Ces états ne constituent ni un succès ni un échec fonctionnel des deux nouveaux tests.
- **Contrôles documentaires suivants :** QIMA CI [run 40789211793](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789211793) est resté signalé `in_progress`, mais les jobs PostgreSQL / typecheck montrent des étapes annulées et aucune suite complète n'est validée. CodeQL [run 40789211824](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789211824) était encore `in_progress`. Pour le HEAD documentaire `3ef177512762695419759977309ab32136f522c7`, la recherche GitHub Actions n'a pas encore retourné de run associé ; Vercel Preview est **PENDING** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/8XvBVTaUcexBMuPDsZvyfCSRqsHb)).
- **Conclusion de validation :** les deux nouveaux tests sont **NON VALIDÉS** tant qu'une exécution QIMA CI complète n'a pas terminé sur un commit contenant ces tests. Aucun échec de test n'est confirmé ; les jobs observés ont été annulés ou restent en cours.
- **Étape suivante :** vérifier les runs déclenchés pour le dernier HEAD. Si aucun run complet ne démarre, déclencher QIMA CI / CodeQL depuis l'interface GitHub avec les permissions autorisées ; l'outillage disponible ici ne fournit pas d'action `workflow_dispatch`.
- **Portée et garde-fous :** ces tests vérifient le contrat de la route et le paramètre d'idempotence envoyé au RPC simulé ; ils ne prouvent pas le comportement de la base réelle. Aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ni modification des protections de branche. Le modèle d'appartenance `demandId` ↔ tenant reste en attente d'une décision métier explicite.


## OFFER-QA-23 — régressions de sélection de tenant CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, en brouillon et non fusionnée ; branche `fix/create-offer-status-contract`. HEAD précédent `a473b288891ef4e66bc58931352eb1f924b415a5`. Sur ce HEAD, QIMA CI [run 40789317863](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789317863) : **SUCCESS** (installation depuis lockfile commité, audit npm, TypeScript, build, Playwright smoke tests et tests PostgreSQL isolés CREATE_OFFER/concurrence + régressions RLS synthétiques) ; CodeQL [run 40789317898](https://github.com/meridane/QimaTrade-MVP/actions/runs/40789317898) : **SUCCESS** ; Vercel Preview : **SUCCESS**.
- **Régressions ajoutées :** commit de test `df8a13b5da17e8f54d6e9196b7da0eb3fe76e3c0`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le helper accepte maintenant une fixture de memberships paramétrable. Deux cas vérifient qu'une liste de memberships vide renvoie HTTP 403 `TENANT_MEMBERSHIP_REQUIRED`, et que deux tenant IDs distincts renvoient HTTP 409 `TENANT_SELECTION_REQUIRED`. Les deux vérifient qu'aucun RPC sous `/rest/v1/rpc/` n'est appelé.
- **Contrôles immédiatement après le commit de test :** la recherche GitHub Actions associée au SHA `df8a13b5da17e8f54d6e9196b7da0eb3fe76e3c0` ne retournait encore aucun workflow ; le statut combiné ne contenait aucun check. **Les deux nouveaux tests ne sont donc pas encore validés par CI.** Le succès du HEAD précédent n'est pas extrapolé au nouveau code.
- **Portée :** tests de route avec fetch/Supabase simulé ; ils verrouillent le contrat HTTP du garde-fou tenant dans l'application, mais ne testent pas les policies RLS live ni la propriété métier d'une demande. Aucune règle métier d'appartenance demande/tenant n'a été inventée.
- **Contrôles après l'entrée documentaire (HEAD `66be1797900de11c264b615e23014e8a4e179253`) :** QIMA CI [run 40797654185](https://github.com/meridane/QimaTrade-MVP/actions/runs/40797654185) : **IN_PROGRESS** (jobs TypeScript/audit/build/Playwright et PostgreSQL isolé démarrés, étapes de test encore en attente) ; CodeQL [run 40797654307](https://github.com/meridane/QimaTrade-MVP/actions/runs/40797654307) : **IN_PROGRESS** (initialisation de l'analyse) ; Vercel Preview : **PENDING** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/4sYXzPARYmEnLKy7ZM9dHPRP9Qms)). Aucun résultat final sur ce HEAD n'est encore disponible. Le push de cette mise à jour documentaire peut déclencher une nouvelle exécution ; vérifier le SHA final avant de conclure.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche.

## OFFER-QA-24 — contrat HTTP des statuts d'exécution CREATE_OFFER (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte en brouillon, non fusionnée ; branche `fix/create-offer-status-contract`. Le dernier commit documentaire observé avant cette exécution est `cf41c814b6ce9357ec946605aa94d801fad3cf9e`. Sur ce HEAD, CodeQL [run 40797706481](https://github.com/meridane/QimaTrade-MVP/actions/runs/40797706481) : **SUCCESS** ; QIMA CI [run 40797706647](https://github.com/meridane/QimaTrade-MVP/actions/runs/40797706647) : **CANCELLED** ; statut Vercel : **SUCCESS** pour une Preview uniquement.
- **Régression ajoutée :** commit de test `1aa8205c4d00ded635e7821640659d163ad9f2fe`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le mock RPC peut désormais renvoyer un statut paramétrable ; le nouveau cas simule `status: "failed"` et vérifie que la route conserve ce statut public et répond HTTP 409, tout en confirmant que le RPC a été appelé. Aucun code de production, schéma, migration ou donnée n'a été modifié.
- **Contrôles après le commit de test :** immédiatement après le push du SHA `1aa8205c4d00ded635e7821640659d163ad9f2fe`, GitHub Actions ne retournait aucun workflow associé et le statut combiné ne contenait aucun check. **Le nouveau test est NON VALIDÉ par CI à ce stade.** Les résultats du HEAD précédent ne sont pas extrapolés au nouveau test.
- **Prochaine étape :** vérifier les workflows du commit de test et du HEAD documentaire suivant. Si aucun workflow complet ne démarre, conserver explicitement l'état non validé ; ne pas annoncer de succès sans résultat final sur le HEAD exact.
- **Portée et limites :** test de route avec client Supabase simulé ; il vérifie le mappage HTTP du résultat de l'action, pas l'état réel de la transaction SQL ou de Supabase production. Aucun test synthétique n'est interprété comme preuve d'une vulnérabilité.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ni modification des protections de branche. La question métier d'appartenance `demandId` ↔ tenant reste séparée et non résolue.



## OFFER-QA-25 — rejet des requêtes CREATE_OFFER sans authentification Bearer valide (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte, brouillon et non fusionnée ; branche `fix/create-offer-status-contract`, HEAD précédent `4f2101bf9e42d58cb2a9f224ffbd76ea2cf98611`. Sur ce HEAD, QIMA CI [run 40801722024](https://github.com/meridane/QimaTrade-MVP/actions/runs/40801722024) : **SUCCESS** (audit npm, TypeScript, build, Playwright smoke tests et PostgreSQL isolé) ; CodeQL [run 40801722082](https://github.com/meridane/QimaTrade-MVP/actions/runs/40801722082) : **SUCCESS** ; Vercel Preview : **SUCCESS**.
- **Régression ajoutée :** commit de test `b4ea82ca7416809aca0214721e22cc57fdc77f53`, fichier `tests/e2e/create-offer-route-contract.spec.ts`. Le helper accepte un en-tête d'autorisation configurable. Le test couvre l'absence d'en-tête et un schéma non-Bearer (`Basic invalid-token`) ; chacun doit renvoyer HTTP 401 avec `UNAUTHENTICATED` et ne déclencher aucun appel réseau Supabase simulé. Aucun code de production n'a été modifié.
- **Contrôles du commit de test :** QIMA CI [run 40807699642](https://github.com/meridane/QimaTrade-MVP/actions/runs/40807699642) : **IN PROGRESS** au dernier relevé ; le job PostgreSQL isolé est **SUCCESS**, et dans le job navigateur l'installation `npm ci`, l'audit npm, TypeScript et le build sont **SUCCESS**, mais l'installation de Chromium est toujours en cours et Playwright n'a pas encore commencé. CodeQL [run 40807699613](https://github.com/meridane/QimaTrade-MVP/actions/runs/40807699613) : analyse principale terminée, nettoyage du job encore en cours au dernier relevé. **Le nouveau test n'est pas encore validé par une suite navigateur complète ; aucun échec fonctionnel n'est confirmé.**
- **Portée et limites :** test de route avec fetch/Supabase simulé ; il vérifie le garde-fou d'authentification avant toute requête Supabase et ne constitue pas une preuve de sécurité globale ni une conclusion sur une vulnérabilité de production.
- **Prochaine étape :** vérifier la fin de QIMA CI, CodeQL et Vercel sur le HEAD courant. Si un job échoue, examiner ses logs avant de corriger. Ne pas considérer la validation complète comme acquise avant la fin de Playwright.
- **Garde-fous :** aucune donnée, migration, policy ou configuration Supabase production modifiée ; aucune fusion, mise en production ou modification des protections de branche. Le modèle métier d'appartenance `demandId` ↔ tenant reste une décision séparée non résolue.


## OFFER-QA-26 — conformité du schéma Bearer insensible à la casse (29 octobre 2026)

- **État relu avant modification :** PR #26 ouverte en brouillon, non fusionnée ; branche `fix/create-offer-status-contract`. HEAD `2ad61a4c46894756d0a63973be594932bc1f4bfb`. QIMA CI [run 40807850815](https://github.com/meridane/QimaTrade-MVP/actions/runs/40807850815) : **SUCCESS** ; CodeQL [run 40807850819](https://github.com/meridane/QimaTrade-MVP/actions/runs/40807850819) : **SUCCESS** ; Vercel Preview : **SUCCESS**.
- **Constat et changement :** le garde-fou de `app/api/actions/create-offer/route.ts` comparait le préfixe `Bearer ` avec `startsWith` sensible à la casse. Le schéma d’authentification HTTP est insensible à la casse ; le contrôle accepte maintenant les variantes de casse tout en exigeant le préfixe Bearer et en conservant la validation du jeton via `supabase.auth.getUser(token)`.
- **Régression ajoutée :** dans `tests/e2e/create-offer-route-contract.spec.ts`, un test couvre `bearer qima-route-test-token` et `bEaReR qima-route-test-token`. Les deux cas attendent HTTP 200 et un appel à `execute_create_offer_v1` dans le mock. Le fichier complet conserve les tests existants (18 déclarations `test` au total).
- **Historique de validation et correction intermédiaire :** le commit initial `7a11ae7c965eb8e4cf652857f592297ca9f758b4` a temporairement remplacé par erreur le contenu complet du fichier de tests par le seul bloc d’authentification ; son run QIMA CI [40811805496](https://github.com/meridane/QimaTrade-MVP/actions/runs/40811805496) a échoué au contrôle TypeScript pour cette raison. Le commit correctif `82f3f3c9934e67093ddfdc8563dacdec3125925f` a restauré le fichier complet depuis le HEAD parent et ajouté le test au bon endroit. Ne pas interpréter l’échec intermédiaire comme un échec du test de comportement.
- **Contrôles du HEAD correctif `82f3f3c` :** QIMA CI [run 40811880254](https://github.com/meridane/QimaTrade-MVP/actions/runs/40811880254) : **SUCCESS** — installation depuis lockfile, audit npm (0 vulnérabilité signalée dans le rapport de ce run), TypeScript, build de production, installation Chromium, tests navigateur, tests PostgreSQL isolés CREATE_OFFER/concurrence et deux suites RLS synthétiques réussis. CodeQL [run 40811880309](https://github.com/meridane/QimaTrade-MVP/actions/runs/40811880309) : **SUCCESS**. Vercel Preview : **SUCCESS** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/BQoaVt7HoTJtybQdC668sGu16nLk)). Ces tests simulés/isolés ne prouvent pas l’absence de vulnérabilités en production.
- **Portée et garde-fous :** changement limité au parsing du préfixe d’authentification et à son test. Aucun secret, aucune donnée, migration, policy ou configuration Supabase production modifié ; aucune fusion, mise en production ni modification des protections de branche. La question métier distincte d’appartenance `demandId` ↔ tenant reste à décider.
- **Étape suivante :** vérifier les checks du nouveau HEAD documentaire après ce commit. Puis poursuivre les tests non bloquants du contrat CREATE_OFFER sans modifier l’autorisation métier tant que le modèle d’appartenance n’est pas documenté.

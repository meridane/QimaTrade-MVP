# QIMA Trade — Registre des fonctionnalités V1 et audit de départ

Dernière vérification : 12 octobre 2026  
Dépôt : `meridane/QimaTrade-MVP` — branche `main`  
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

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


## 17. Publication des offres et matching — 20 octobre 2026

- **OFFER-PUBLISH-01 — Soumission d'offre :** les deux chemins de création d'offre (`app/offers/actions.ts` et `app/api/offers/route.ts`) définissent désormais le cycle initial à `published`, cohérent avec l'action utilisateur « Submit offer ».
- **MATCH-PUBLISH-01 — Visibilité du matching :** `app/demands/match/page.tsx` ne récupère que les offres dont le cycle est `published` pour le Product Master demandé. Les brouillons et autres états ne sont donc pas présentés comme des offres disponibles.
- **Sécurité et limites :** aucune policy RLS, migration de production ou donnée n'a été modifiée. La CI doit confirmer le build et les tests existants ; le parcours réel de publication/matching avec comptes acheteur et fournisseur reste à tester sur un environnement contrôlé avant de marquer la fonctionnalité VALIDÉE.
- **État :** branche `feature/offer-publication-matching`; changements soumis à revue, aucun merge ni déploiement effectué.

## 18. Résultats CI de la publication/matching — 20 octobre 2026

- **CI-OFFER-PUBLISH-01 : VALIDÉ au niveau automatisé.** La CI GitHub du commit `af5f404ae28b6adb080f2805742104a24c61e819` a réussi : typecheck, audit, build et tests navigateur existants. Le contrôle CodeQL a également réussi.
- **Portée de cette validation :** ces résultats confirment que le code compile et que les tests existants passent. Ils ne valident pas encore le parcours réel avec un compte fournisseur et un compte acheteur, ni les politiques RLS de l'environnement.
- **État fonctionnel : À TESTER en conditions réelles.** Étape suivante : vérifier dans un environnement contrôlé qu'un fournisseur peut publier une offre associée au Product Master actif et qu'un acheteur voit cette offre dans le matching de sa demande, sans voir les brouillons ni les offres d'un autre produit.
- **Plan d'exécution :** checklist détaillée ajoutée dans `docs/QIMA_V1_E2E_TEST_PLAN.md` pour tester connexion, création d'offre, matching, isolation par Product Master, permissions et conversation avec deux comptes distincts.
- **État Git :** PR #23 toujours ouverte ; aucun merge, changement Supabase ou déploiement de production effectué.


## 19. Diagnostic du matching — 20 octobre 2026

- **MATCH-ERROR-01 — Erreurs de lecture :** `app/demands/match/page.tsx` distingue désormais une erreur de lecture des offres d'une liste réellement vide. L'interface affiche un état d'erreur au lieu de laisser croire qu'il n'existe aucune offre.
- **MATCH-EMPTY-01 — États vides :** le message précise si aucune offre publiée n'existe pour le Product Master demandé ou si la demande n'est pas liée à un Product Master canonique.
- **Validation :** modification commise sur la branche de la PR #23 ; attendre CI (typecheck, build, audit, tests navigateur et CodeQL). Aucun test métier Supabase réel n'a été exécuté.


## 20. Garde-fous du parcours demande → offre → matching → conversation — 20 octobre 2026

- **DEMAND-PUBLISH-01 — Statut de la demande issue du Decision Tree : CORRECTIF PROPOSÉ.** `dt_publish_product_request` marquait le `product_request` `published` mais créait la `demand` avec `demand_status = 'draft'`. La migration sur la branche de travail aligne le statut de la demande sur `published`. La migration n'est pas appliquée à une base distante et doit être validée en DEV avant mise en service.
- **OFFER-OWNER-01 — Propriété de la demande : CORRECTIF PROPOSÉ.** Les chemins d'offre vérifient côté serveur que l'acteur courant est propriétaire de la demande avant création.
- **OFFER-PRODUCT-01 — Cohérence canonique : CORRECTIF PROPOSÉ.** L'endpoint multipart ne permet plus de remplacer le Product Master porté par la demande avec un identifiant indépendant.
- **MATCH-OWNER-01 — Accès au matching : CORRECTIF PROPOSÉ.** La page de matching exige une session, un profil QIMA associé à un acteur et une demande dont `requester_actor_id` correspond à l'acteur courant.
- **CONVERSATION-AUTH-01 — Participants : CORRECTIF PROPOSÉ.** Chargement/envoi exigent une demande et une offre précises, un match `accepted` et l'acteur courant doit posséder soit la demande soit l'offre. Les tiers et les échanges où l'acteur serait des deux côtés sont refusés.
- **CONVERSATION-UI-01 — Gestion des erreurs : CORRECTIF PROPOSÉ.** La page attrape les rejets inattendus au chargement/envoi au lieu de laisser une promesse non gérée.
- **Automatisation vérifiée au moment de l'audit :** CI de la PR #23 réussie au commit `5bcc76bddf4c68a25eaf07497a61d3e1b244d930` (typecheck, audit, build, Playwright existants) ; CodeQL réussi. Ces runs précèdent la branche de correctifs décrite ci-dessus.
- **Parcours métier réel : À TESTER.** Aucune session Google interactive ni scénario complet fournisseur → acheteur → acceptation → conversation n'a été exécuté. Les deux comptes de test et un environnement Supabase isolé ne sont pas disponibles dans cette exécution.
- **RLS / privilèges : À AUDITER.** Aucune policy ni privilège RLS n'est modifié. La revue des policies existantes de `demands`, `offers`, `matches` et `messages` reste requise avant de considérer l'isolation validée.


## 21. Sécurisation de la décision sur une offre — 20 octobre 2026

- **OFFER-DECISION-OWNER-01 — Correctif proposé :** `app/demands/match/actions.ts` vérifie désormais que l'acteur connecté est le propriétaire de la demande avant d'accepter ou de refuser une offre.
- **OFFER-DECISION-PRODUCT-01 — Cohérence produit :** l'action refuse les offres non publiées, celles qui ne correspondent pas au Product Master canonique de la demande, ainsi que l'auto-acceptation par le fournisseur.
- **OFFER-DECISION-MATCH-01 — Écritures :** une correspondance existante non acceptée est mise à jour plutôt que de créer une ligne supplémentaire ; les erreurs de lecture/écriture sont renvoyées vers un état d'erreur générique.
- **Commit :** `ad940453ab9069c335c4947289c442f51cab2256` sur `feature/e2e-demand-conversation-guards`.
- **Validation :** CI et CodeQL déclenchés, résultats en attente au moment de cette mise à jour. Le comportement réel avec deux comptes et les policies RLS restent à tester en environnement contrôlé.
- **Aucune modification** appliquée à Supabase distant ; aucune fusion ou mise en production effectuée.


## 22. Audit RLS des tables marketplace — 20 octobre 2026

- **RLS-READONLY-01 — Tables vérifiées :** `demands`, `offers`, `matches`, `messages` ont RLS activé, mais `relforcerowsecurity = false`. Les politiques déclarées sont présentes ; elles doivent être évaluées avec les privilèges SQL et les fonctions auxiliaires.
- **RLS-PRIV-01 — Privilèges trop larges constatés :** les rôles `anon` et `authenticated` avaient des privilèges directs sur les tables, dont `TRUNCATE` sur les quatre tables. RLS ne bloque pas `TRUNCATE`. Aucun privilège n'a été modifié dans la base distante pendant l'audit.
- **RLS-MESSAGE-01 — Contrôle participant insuffisant :** l'ancienne fonction `is_message_participant` acceptait le cas où l'acteur courant correspondait simplement à `sender_actor_id`, sans vérifier la participation réelle au couple demande/offre. Le correctif proposé exige un match accepté, deux acteurs distincts et l'appartenance du compte à la demande ou à l'offre ; l'expéditeur fourni doit être l'un des deux participants.
- **RLS-MATCH-UPDATE-01 — Action serveur et policy :** l'action `respondToOffer` met à jour un match existant. La policy RLS existante ne prévoyait pas `UPDATE` sur `matches`. La migration proposée autorise l'update par le propriétaire de la demande et utilise un trigger pour empêcher la modification de l'identité du match et le changement de statut après acceptation.
- **Migration proposée :** `supabase/migrations/20261020193000_harden_marketplace_rls_v1.sql`, commit `f60da721aee1cd2fbd6f20bad527ac840fc253c5` sur `feature/e2e-demand-conversation-guards`.
- **État : À VALIDER EN DEV.** Aucun SQL n'a été appliqué à Supabase distant. Le projet ne dispose pas d'un environnement DEV isolé confirmé dans cet audit ; ne pas appliquer en production avant validation syntaxique, test de régression et tests avec acheteur/fournisseur/tiers.
- **Tests requis :** compte anonyme incapable de lire/écrire/tronquer ; acheteur et fournisseur peuvent lire les messages uniquement pour leur match accepté ; tiers ne peut ni lire ni insérer des messages ; mauvais couple demande/offre rejeté ; acheteur peut modifier la décision d'un match non accepté sans modifier son identité ; match accepté reste accepté.

- **RLS-MATCH-UPDATE-02 — Revue des colonnes :** l'inspection du schéma réel a montré que `matches` contient aussi `notion_url`, `match_id`, `reason`, `recommended_action`, `detected_at` et `version`. Le trigger proposé a été renforcé pour figer ces champs également ; seule la décision `status` (et l'horodatage `updated_at`) peut changer via ce chemin. Commit de correction : `c3801417d6a965fe391adea6bd9e3901aef985f0`.
- **RLS-MATCH-UPDATE-03 — Schéma confirmé :** PostgreSQL distant est en version 17.6 ; les colonnes utilisées par le trigger existent dans `public.matches`. Aucun trigger utilisateur existant n'a été trouvé sur `demands`, `offers`, `matches` ou `messages` lors de cette lecture.
- **Limite persistante :** les requêtes de métadonnées ont confirmé les types/colonnes, mais la migration n'a pas été exécutée dans une base isolée. La compatibilité transactionnelle, les privilèges effectifs après révocation et les scénarios RLS doivent encore être testés avant production.


## 23. Compatibilité décision de match / garde-fou SQL — 20 octobre 2026

- **RLS-MATCH-UPDATE-04 — Corrigé dans le code :** l'action `respondToOffer` ne modifie plus `reason`, `recommended_action` ni `detected_at` lorsqu'elle met à jour un match existant. Elle ne change que `status` et `updated_at`, conformément au trigger `guard_match_decision_update()` proposé dans `20261020193000_harden_marketplace_rls_v1.sql`.
- **Commit :** `868251f3804dccaa1626a1add0e2fa9d89078f98` sur `feature/e2e-demand-conversation-guards`.
- **Validation :** le fichier a été relu après commit et le correctif est présent. Aucun résultat CI associé à ce commit n'a encore été confirmé. La migration n'a pas été appliquée ; le comportement SQL reste à tester avant production.


## 24. Masquage des erreurs internes de l'API offres — 20 octobre 2026

- **API-OFFER-ERROR-01 — Corrigé dans le code :** `app/api/offers/route.ts` ne renvoie plus le message brut de Postgres/PostgREST ni le texte d'une exception inattendue au navigateur. Les erreurs d'écriture et exceptions renvoient désormais un message générique.
- **Commit :** `09c507acd80000923510fc7dcacd1b91d4c9b0c8` sur `feature/e2e-demand-conversation-guards`.
- **Validation :** le changement est enregistré sur GitHub. Les vérifications CI/CodeQL de ce commit restent à confirmer ; aucun test réel d'écriture Supabase n'a été exécuté.


## 25. Vérification CI/CodeQL des garde-fous marketplace — 21 octobre 2026

- **CI-PR24-01 — PASS :** pour le commit `9a1049f8d00a7a86442a741f5d58b85274f9ba18`, le contrôle GitHub Actions « Typecheck, audit, build and browser tests » est terminé avec succès. Cela valide le typecheck, l'audit npm, le build et les tests Playwright présents dans la branche.
- **CODEQL-PR24-01 — PASS :** CodeQL est terminé avec succès sur le même commit, sans nouvelle alerte dans le code modifié.
- **VERCEL-PREVIEW-01 — PASS :** le contrôle Vercel est réussi pour le commit vérifié.
- **Limite importante :** ces contrôles automatisés ne valident pas encore le parcours métier réel avec deux comptes (fournisseur/acheteur), ni l'application de la migration RLS dans une base isolée. Le test E2E métier reste **BLOCKED / NOT RUN** tant qu'un environnement de test sans risque n'est pas disponible.
- **État Git :** PR #24 reste ouverte, branche `feature/e2e-demand-conversation-guards`. Aucun merge, aucune modification de production et aucune migration Supabase distante n'ont été exécutés.
- **Prochaine étape :** préparer des tests ciblés supplémentaires pour les règles d'autorisation et clarifier le scénario métier « offre indépendante » versus « réponse à une demande » avant de modifier la logique de propriété des demandes.

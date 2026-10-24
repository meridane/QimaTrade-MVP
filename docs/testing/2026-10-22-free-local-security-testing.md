# QIMA — Solution de test gratuite, locale et isolée

Date: 2026-10-22  
Statut: préparation documentaire uniquement; aucun test hostile lancé sur la production.

## Objectif

Tester le moteur Decision Tree et les frontières multi-tenant sans créer de branche Supabase payante et sans toucher à la base de production.

## Architecture retenue

- **Supabase local** avec Supabase CLI et Docker Desktop/Engine sur le PC du développeur.
- **PostgreSQL local éphémère** pour appliquer les migrations et tester les politiques/RPC.
- Utilisateurs, tenants, sessions et Product Master de test synthétiques uniquement.
- Playwright/Vitest pour les tests applicatifs; SQL de diagnostic en lecture seule pour inspecter le catalogue.
- GitHub Actions pour rejouer les contrôles automatiques, dans les quotas gratuits disponibles du compte.
- Aucun URL, jeton, mot de passe ou clé de production dans les tests.

Coût de la branche Supabase distante: **0**. L'exécution locale nécessite une machine compatible et Docker; l'utilisation des quotas GitHub Actions dépend du plan et de la consommation.

## Important : limites connues

1. Le dépôt a un workflow CI avec TypeScript, audit npm, build Next.js et Playwright, mais le `package.json` observé ne contient pas de lockfile dans la revue précédente. L'installation utilise actuellement `npm install`; pour une reproductibilité complète, générer et revoir un lockfile avant de passer à `npm ci`.
2. **Blocage constaté dans l'inventaire GitHub du 22/10/2026 :** le dépôt ne contient actuellement que 15 fichiers sous `supabase/migrations/`, alors que le projet Supabase distant indique 157 migrations appliquées. La base locale ne peut donc pas encore être considérée comme une copie fidèle du schéma distant. Il faut retrouver/réconcilier les migrations manquantes avant de prétendre exécuter les tests d'intégration sur un schéma complet.
3. **Ne pas lancer le reset pour prétendre tester le schéma complet à ce stade.** D'abord inventorier les migrations présentes, comparer les versions au registre Supabase et récupérer les migrations manquantes depuis la source de vérité du projet. Si elles ne peuvent pas être récupérées, créer une fixture SQL locale minimale explicitement limitée aux tests de sécurité et ne pas la présenter comme équivalente à la production. Ne pas réparer en important ou en modifiant la production.
4. La CI existante ne prouve pas l'isolation entre tenants. Les tests de sécurité ci-dessous sont à écrire/exécuter sur la base locale avant toute demande de fusion.
5. Une base locale n'est représentative que des migrations réellement appliquées et des rôles simulés. La confirmation finale doit être faite sur un environnement de test isolé si disponible, jamais par des tentatives d'écriture sur la production.

## Démarrage local proposé

Prérequis : Node.js 20, npm, Git, Docker Desktop/Engine, Supabase CLI.

1. Cloner le dépôt et basculer sur `chore/qima-free-autopilot-review`.
2. Vérifier que `supabase/config.toml` et le répertoire des migrations existent.
3. Lire les migrations et vérifier qu'elles n'embarquent pas d'URL/clé de production ou d'opération externe.
4. Lancer `supabase start` uniquement après cette vérification.
5. Lancer `supabase migration list` et `supabase db reset` uniquement sur la base locale. Ne jamais utiliser une commande `db push` vers le projet distant.
6. Si le reset échoue, enregistrer le premier échec et arrêter; ne pas supprimer de données distantes pour contourner l'erreur.
7. Avant toute suite de sécurité ciblée, lancer `npm run test:local-env` avec `SUPABASE_URL=http://127.0.0.1:54321`. Ce garde-fou refuse explicitement les URLs distantes. Ensuite exécuter `npm run typecheck`, `npm run build` avec variables locales factices, puis `npm run test:e2e`.
8. Ajouter ensuite les tests d'intégration de sécurité et les lancer contre l'URL locale Supabase.

## Fixtures synthétiques

Créer deux tenants distincts, Tenant A et Tenant B, puis deux utilisateurs de test Alice et Bob. Alice ne doit être membre que de A; Bob uniquement de B. Créer des sessions distinctes. Ajouter un troisième utilisateur multi-tenant uniquement pour vérifier que l'API refuse de choisir une organisation arbitrairement.

Ne jamais copier de profils, e-mails, tokens, données commerciales ou identifiants réels dans ces fixtures.

## Tests bloquants à automatiser

- Alice ne peut pas lire ni modifier la session de Bob.
- Les identifiants de tenant, user, node ou rule forgés ne permettent pas de contourner le serveur.
- Un utilisateur sans membership est refusé.
- Un utilisateur ayant plusieurs memberships reçoit `TENANT_SELECTION_REQUIRED` tant qu'une sélection explicite et autorisée n'existe pas.
- Une réponse valide incrémente la révision une seule fois; le rejeu du même `client_command_id` ne crée aucun historique en double.
- Deux commandes concurrentes sur la même révision ne peuvent pas toutes les deux réussir.
- Les utilisateurs authentifiés ne peuvent pas directement insérer/modifier/supprimer les observations et transitions si les grants déployés les interdisent; le RPC officiel continue de fonctionner.
- La modification directe de `current_node_id`, `revision`, `status`, `tenant_id` ou `user_id` d'une session ne contourne pas la machine d'état.
- La création d'une demande avec la session d'un autre tenant est refusée sans écriture partielle.
- Chaque RPC `SECURITY DEFINER` vérifie l'identité et l'appartenance à l'organisation côté serveur.

## Critères d'arrêt

Arrêter et signaler le problème si :
- les migrations du dépôt ne permettent pas une installation locale propre;
- une commande indique un projet Supabase distant;
- des variables de production sont nécessaires pour lancer les tests;
- un test ne peut pas distinguer un refus RLS d'une erreur de fixture;
- une correction exige de modifier les droits ou le schéma distant.

## État de préparation au 22/10/2026

- Supabase CLI + Docker local est la voie gratuite privilégiée; aucune branche Supabase distante n'a été créée.
- Le dépôt contient 15 fichiers de migration sous `supabase/migrations/`, aucun `supabase/config.toml` n'a été trouvé dans l'arbre GitHub inspecté, alors que l'inventaire du projet distant retourne 157 migrations. L'absence de configuration locale et l'écart de migrations sont des **bloqueurs** pour reproduire fidèlement le schéma complet.
- Le prochain travail doit réconcilier ces migrations ou préparer une fixture locale ciblée, clairement étiquetée comme non équivalente au schéma complet.
- Le script `scripts/assert-local-supabase.mjs` (commande `npm run test:local-env`) bloque les URLs Supabase distantes avant les tests dédiés. Le script SQL compagnon `2026-10-22-qima-readonly-catalog-checks.sql` permet d'inspecter en lecture seule RLS, policies, grants et fonctions sensibles; il ne teste pas les accès runtime.

## Résultat attendu

La première livraison doit fournir des logs de tests reproductibles sur une base locale, le commit testé, la version des migrations, et un tableau PASS/FAIL. Aucun statut Security Gate ne sera déclaré PASS tant que les tests d'intégration multi-tenant ne sont pas réellement exécutés.

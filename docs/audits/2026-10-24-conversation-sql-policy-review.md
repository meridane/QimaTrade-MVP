# QimaTrade — revue des politiques SQL des conversations

Date : 24 octobre 2026  
Branche : `chore/qima-free-autopilot-review`  
Statut : **revue partielle du dépôt — sécurité non validée**.

## Résultat de cette passe

Les actions serveur suivantes ont été relues :

- `app/demands/conversation/actions.ts`
- `tests/e2e/auth-smoke.spec.ts`
- `supabase/migrations/20260829130000_fix_offers_insert_rls_actor_lookup.sql`
- `supabase/migrations/20260901090000_security_gate_dt_v1.sql`

Le test E2E actuel couvre l'authentification, des validations API et des redirections. Il ne teste pas l'isolation des conversations entre deux participants.

La migration `20260829130000_fix_offers_insert_rls_actor_lookup.sql` définit une politique d'insertion pour `offers` qui vérifie que `provider_actor_id` correspond à l'acteur du profil courant. Elle ne suffit pas à démontrer les droits de lecture/écriture de `messages`.

La migration `20260901090000_security_gate_dt_v1.sql` concerne les tables Decision Tree (`dt_sessions`, `dt_observations`, `dt_transitions`, etc.). Elle ne définit pas les politiques des tables de conversation `demands`, `offers` et `messages`.

## Point non résolu

Dans `app/demands/conversation/actions.ts` :

1. `loadConversation()` récupère la demande par son ID sans condition d'appartenance explicite dans la requête.
2. L'offre fournie est récupérée par son ID, sans vérifier explicitement qu'elle appartient à la demande demandée ni que l'acteur courant est l'un des participants autorisés.
3. Les messages sont recherchés par `demand_id` et, si présent, `offer_id`.
4. `sendConversationMessage()` insère le message après contrôle d'authentification et de contenu, mais sans contrôle explicite des participants dans cette action.

Ces constats sont des risques statiques, **pas la preuve qu'un utilisateur non autorisé peut lire ou envoyer des messages**. Les politiques RLS et les contraintes de base peuvent refuser ces opérations ; elles doivent être inspectées et testées dans leur version réellement appliquée.

## Limite du dépôt disponible

La liste des migrations examinées dans cette passe n'a pas permis d'identifier une migration faisant autorité qui définit les politiques de `messages` et l'intégralité du schéma courant de `demands`/ `offers`. L'écart déjà noté entre l'historique SQL du dépôt et le nombre de migrations du projet distant empêche de traiter ce dépôt seul comme un inventaire complet du schéma distant.

## Prochaines étapes

1. Obtenir l'inventaire SQL canonique autorisé des politiques, grants, contraintes et fonctions pour `public.demands`, `public.offers` et `public.messages` (lecture seule ; aucune modification).
2. Construire un environnement Supabase local jetable correspondant à ces migrations, avec deux utilisateurs et deux conversations synthétiques.
3. Tester lecture et insertion pour participant A, participant B et non-participant, y compris une paire incohérente `demand_id` / `offer_id`.
4. Ne modifier l'action serveur ou les politiques qu'après un test reproductible et après confirmation du modèle métier des participants.
5. Relancer les tests et enregistrer le SHA, les commandes et les sorties réelles.

## Garde-fous

- Aucun accès à des données de production dans les tests.
- Aucune migration, reset, push, merge ou déploiement de production.
- Aucun test marqué PASS sans exécution et sortie observables.
- Séparer « revue statique », « test écrit », « test exécuté » et « sécurité validée ».

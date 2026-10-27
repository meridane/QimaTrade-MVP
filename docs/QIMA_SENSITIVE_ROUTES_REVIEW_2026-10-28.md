# QIMA — Revue ciblée des routes sensibles

Date : 2026-10-28
Branche : fix/create-offer-status-contract

## Constat vérifié dans le code

### 1. Route historique de création d'offre
Fichier : `app/api/offers/route.ts`.
- La route authentifie l'utilisateur et récupère son `actor_id`.
- Elle valide le nom, la quantité, le prix, la devise et vérifie éventuellement l'existence d'une demande et d'un Product Master actif.
- Elle insère directement dans `offers` avec `lifecycle: draft`.
- Elle ne passe pas par `executeUniversalAction` dans ce fichier, donc cette voie ne bénéficie pas automatiquement du contrat d'idempotence et des événements du runtime universel.
- La lecture de la demande par ID ne prouve pas, à elle seule, que l'utilisateur est autorisé à créer une offre pour cette demande.

**Risque à confirmer :** contournement du chemin métier canonique et contrôle d'autorisation incomplet. Aucun exploit ni changement de données n'a été tenté.

### 2. Envoi de message
Fichier : `app/demands/conversation/actions.ts`.
- `sendConversationMessage` authentifie l'utilisateur, résout son acteur, puis insère `demand_id`, `offer_id`, `sender_actor_id` et `body`.
- Avant l'insertion, cette action ne charge pas explicitement la demande et ne vérifie pas dans le code serveur que l'offre fournie appartient à cette demande.
- La sécurité dépend donc fortement des contraintes et politiques RLS de `public.messages`.
- `loadConversation` vérifie que la demande existe et tente de charger l'offre, mais l'accès effectif dépend aussi de RLS.

**Risque à confirmer :** associations demande/offre incohérentes ou autorisation trop large si la politique de base accepte un cas non prévu.

### 3. Route canonique CREATE_OFFER
Fichier : `app/api/actions/create-offer/route.ts`.
- Authentifie le Bearer token, récupère le profil et exige un membership de tenant.
- Refuse le choix arbitraire si plusieurs tenants sont présents.
- Exécute `executeUniversalAction` avec `actionKey: CREATE_OFFER` et une clé d'idempotence.
- La règle qui lie l'offre, la demande et le tenant fournisseur reste à vérifier dans le runtime et la fonction SQL.

## Suite recommandée (sans écriture en production)
1. Ajouter des tests API/RLS négatifs : utilisateur non propriétaire sur demande, offre liée à une autre demande, tenant non autorisé, et répétition de la même clé d'idempotence.
2. Définir si la route historique doit être retirée, transformée en brouillon via un workflow explicite, ou redirigée vers le runtime universel. Ne pas la supprimer avant validation de l'UX et des besoins brouillon.
3. Vérifier la CI du commit courant, notamment le test participant nouvellement ajouté.
4. Comparer ces constatations aux politiques et contraintes réelles de Supabase en lecture seule.

## Limite
Cette revue est basée sur le code source de la branche. Elle ne prouve pas à elle seule un exploit en production et ne remplace pas les tests avec les rôles/JWT et le schéma réel. Aucune migration ou modification de données de production n'a été effectuée.

## Mise à jour — garde de cohérence demande/offre ajoutée

Le commit `e14c3d64ff86ab96f1e22a931a3620da7b1ae78a` ajoute une vérification applicative de cohérence dans `app/demands/conversation/actions.ts` :

- `loadConversation` refuse désormais une offre dont `demand_id` ne correspond pas au `demandId` demandé.
- `sendConversationMessage` vérifie avant l'INSERT que l'offre existe et correspond à la demande fournie ; une paire incohérente est refusée.
- Cette garde est une défense en profondeur pour l'intégrité du couple demande/offre. Elle ne remplace pas RLS et **ne règle pas à elle seule** l'autorisation d'un utilisateur étranger qui fournit une demande et une offre étrangères mais cohérentes entre elles.
- Les erreurs de vérification ne retournent pas les détails bruts de la requête d'offre.

### Validation
Le changement a été poussé sur la branche de la PR #26. Typecheck, build, Playwright et tests SQL doivent être revalidés sur le nouveau commit avant de considérer le correctif vérifié. Aucun test authentifié contre la base de production n'a été lancé ; aucune migration, écriture de données ou opération de production n'a eu lieu.

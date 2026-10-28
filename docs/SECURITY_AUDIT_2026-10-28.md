# QIMA — Audit sécurité immédiat (read-only)

Date : 28 octobre 2026 (KST)  
Branche de travail : `fix/create-offer-status-contract`  
Projet Supabase inspecté : `QIMA` (`yyulzlnrfcbaxovzjbnh`)  
Méthode : lecture des sources GitHub et requêtes SQL SELECT sur métadonnées/policies/fonctions.  
**Aucune écriture ni migration Supabase, aucun changement de policy, aucune fusion ou mise en production.**

## Résumé exécutif

**Security Gate : NOT PASS.** Deux sujets demandent une correction/test avant d'autoriser le lancement public. Les constats ci-dessous ne signifient pas qu'une attaque a été exécutée contre la production ; ils décrivent des comportements permis par les définitions SQL inspectées.

## SEC-P0-01 — Contrat de participation aux messages trop permissif (risque élevé)

### Preuve source

La fonction déployée `public.is_message_participant(p_message_demand_id, p_message_offer_id, p_sender_actor_id)` contient un premier `EXISTS` qui retourne vrai dès que `p.actor_id = p_sender_actor_id` pour l'utilisateur courant. Elle ne rattache pas cette première branche à la demande ni à l'offre. La policy INSERT sur `public.messages` exige cette fonction et `sender_actor_id = current profile actor`.

Conséquence logique : un utilisateur authentifié qui renseigne son propre acteur comme expéditeur peut satisfaire ce prédicat même si la demande/l'offre ciblée appartient à une autre conversation. Cela peut permettre l'insertion de messages hors conversation autorisée. Le contrôle de lecture est également basé sur la même fonction et doit être testé séparément.

### Limites de la preuve

Le test `tests/sql/legacy-messages-rls-regression.sql` reproduit ce prédicat dangereux dans un schéma synthétique puis teste une variante plus stricte. Il ne se connecte pas à Supabase et ne modifie pas la fonction déployée. Le constat production vient de la lecture de la définition SQL réelle ; aucun message n'a été inséré dans la base réelle pendant cet audit.

### Action recommandée

Préparer une migration corrective minimale, en liant l'utilisateur à une vraie relation de participant sur la paire demande/offre et en vérifiant la cohérence `offers.demand_id = messages.demand_id`. Garder l'envoi par le demandeur et le fournisseur réellement concernés ; refuser les combinaisons demande/offre incompatibles. Ajouter des tests négatifs de lecture et d'insertion dans l'environnement isolé. **Ne pas appliquer en production avant revue et validation.**

## SEC-P0-02 — Privilèges de tables très larges malgré RLS (à vérifier/corriger)

### Preuve source

Les métadonnées `information_schema.role_table_grants` montrent des privilèges `DELETE`, `INSERT`, `SELECT`, `UPDATE`, `TRUNCATE`, `TRIGGER` accordés aux rôles `anon` et/ou `authenticated` sur plusieurs tables historiques, notamment `public.demands`, `public.offers`, `public.profiles` et `public.messages`. Certaines tables n'ont pas tous ces privilèges, mais `TRUNCATE` apparaît notamment pour `demands`, `offers`, `profiles`, `messages`, `dt_sessions` et `product_requests`.

RLS filtre les opérations compatibles avec RLS, mais ne remplace pas les privilèges SQL de table ; notamment, `TRUNCATE` ne suit pas les policies RLS de ligne. Il faut vérifier quels privilèges sont réellement nécessaires aux appels REST/API et supprimer uniquement ceux qui ne le sont pas.

### Limites de la preuve

La présence d'un grant ne prouve pas à elle seule que chaque opération est directement exposée via PostgREST ou qu'un utilisateur a pu l'exécuter. C'est une configuration excessive à traiter avec priorité, pas la preuve d'une suppression de données.

### Action recommandée

Faire l'inventaire exhaustif des grants effectifs et des usages applicatifs, préparer une migration minimale `REVOKE` testée sur une base jetable, puis contrôler les parcours normaux et les rôles `anon`/`authenticated`. Ne pas révoquer en bloc sans vérifier les dépendances.

## SEC-P1-03 — Création d'offre : autorisation demande/tenant non établie

Le RPC `public.execute_create_offer_v1` vérifie le tenant de l'utilisateur et l'existence de la demande, mais les définitions inspectées ne prouvent pas que ce tenant/fournisseur est autorisé à répondre à cette demande. La table `public.demands` inspectée n'a pas de colonne `tenant_id`. Il faut décider si les demandes publiées sont ouvertes à tous ou ciblées par une règle d'accès avant de modifier le code.

## SEC-P1-04 — Route de création d'offre historique séparée

`app/api/offers/route.ts` écrit directement dans `public.offers`, sans passer par le runtime universel. Elle permet un prix absent pour les brouillons, alors que le parcours `CREATE_OFFER` exige un prix. Décider explicitement si le brouillon indépendant reste autorisé ; ensuite, aligner et tester les contrôles d'accès et de validation.

## SEC-P1-05 — Sélection ambiguë du tenant dans la création de demande produit

Dans `app/api/product-requests/route.ts`, la route lit les memberships et utilise `.limit(1).maybeSingle()`. Si un utilisateur appartient à plusieurs tenants, la route choisit le premier renvoyé sans demander de sélection, contrairement à la route de publication qui refuse l'ambiguïté. Ce n'est pas à lui seul la preuve d'un accès inter-tenant, car l'insertion utilise le tenant sélectionné et RLS vérifie le membership ; c'est toutefois un comportement ambigu/incohérent qui peut créer une demande dans le mauvais tenant. Recommandation : refuser plusieurs tenants ou utiliser un tenant actif explicitement validé côté serveur.

## Prochain ordre de travail

1. Créer/mettre à jour un correctif isolé pour `is_message_participant`, avec tests négatifs cohérents avec le schéma réel.
2. Auditer tous les grants effectifs et préparer une migration minimale de moindre privilège.
3. Corriger la sélection de tenant dans la route `product-requests`.
4. Finaliser le contrat de sécurité demande/tenant/fournisseur et les deux chemins de création d'offre.
5. Exécuter CI, tests PostgreSQL et CodeQL ; revue avant toute fusion.

**Statut final : audit initial utile terminé ; corrections production non appliquées.**

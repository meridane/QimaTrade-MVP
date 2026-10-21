# QIMA V1 — Plan de test de bout en bout

Date de préparation : 20 octobre 2026  
Branche de travail : `feature/offer-publication-matching`  
Portée : parcours fournisseur → publication d'offre → matching acheteur.  
Important : ce plan est à exécuter dans un environnement de test contrôlé, avec des comptes et données de test. Ne pas créer de données artificielles dans la production.

## Préparation

- [ ] Confirmer l'environnement de test et les variables Supabase utilisées.
- [ ] Préparer deux comptes distincts : un fournisseur et un acheteur.
- [ ] Vérifier que chacun est authentifié, possède un profil QIMA lié à un acteur et un tenant autorisé.
- [ ] Choisir un Product Master actif et noter son identifiant.
- [ ] Préparer une demande acheteur liée à ce même Product Master.
- [ ] Préparer une deuxième demande liée à un autre Product Master pour tester l'isolation du matching.
- [ ] Utiliser des valeurs de test clairement identifiables et noter les identifiants créés.

## Scénario principal — fournisseur vers acheteur

### A. Connexion et accès

- [ ] Le fournisseur se connecte avec Google.
- [ ] Le fournisseur arrive dans son espace sans boucle de redirection.
- [ ] L'acheteur se connecte avec Google dans une session distincte.
- [ ] Un utilisateur non connecté qui ouvre une route protégée est redirigé vers la connexion.
- [ ] Les deux comptes ne peuvent pas accéder aux données privées l'un de l'autre sans autorisation.

Résultat attendu : chaque compte possède une session propre et les accès sont limités par les permissions.

### B. Création de l'offre fournisseur

- [ ] Ouvrir le parcours de création d'offre.
- [ ] Sélectionner ou rattacher l'offre au Product Master actif prévu.
- [ ] Saisir nom, quantité positive, devise autorisée, prix facultatif et attributs.
- [ ] Soumettre l'offre.
- [ ] Vérifier qu'un identifiant d'offre est renvoyé et que l'offre apparaît dans la liste.
- [ ] Vérifier dans la base de test que `product_master_id` correspond au produit attendu, que `provider_actor_id` correspond au fournisseur et que `lifecycle = published`.
- [ ] Vérifier qu'une quantité nulle/négative, un prix invalide ou une devise non prise en charge est rejeté.
- [ ] Vérifier qu'un utilisateur non authentifié ne peut pas créer d'offre.

Résultat attendu : une offre valide est créée une seule fois, attribuée au bon fournisseur et publiée conformément à l'action « Submit offer ».

### C. Matching côté acheteur

- [ ] Ouvrir le matching de la demande liée au même Product Master.
- [ ] Vérifier que l'offre publiée du fournisseur apparaît.
- [ ] Vérifier que l'évaluation explique les critères quantité, budget, devise, marché et attributs demandés.
- [ ] Créer une offre de test liée à un autre Product Master et vérifier qu'elle n'apparaît pas dans le matching courant.
- [ ] Vérifier qu'une offre avec `lifecycle` différent de `published` n'apparaît pas.
- [ ] Vérifier le comportement si le Product Master de la demande est absent ou invalide.
- [ ] Vérifier que les erreurs de lecture ne sont pas présentées comme une liste de correspondances vide sans diagnostic lorsque cela empêche réellement le matching.

Résultat attendu : seules les offres publiées du même Product Master sont proposées ; les critères de correspondance sont explicables.

### D. Contrôles d'autorisation

- [ ] Tenter d'ouvrir l'identifiant d'une demande non accessible avec le compte acheteur de test.
- [ ] Tenter de lire ou modifier une offre appartenant à un autre fournisseur via les chemins API disponibles.
- [ ] Vérifier les réponses attendues (refus d'accès ou ressource indisponible) et l'absence de fuite de données.
- [ ] Confirmer que les tests n'ont pas exigé de policy RLS permissive ni de droits supplémentaires.

Résultat attendu : l'accès est refusé lorsque l'utilisateur n'est pas autorisé ; aucune modification globale des permissions n'est requise pour faire passer le scénario.

## Scénario conversation — après le matching

- [ ] Depuis une offre correspondante, utiliser l'action de conversation si elle est disponible.
- [ ] Vérifier que les participants sont exactement les comptes autorisés.
- [ ] Envoyer un message de test et vérifier sa persistance.
- [ ] Vérifier que l'autre participant peut le lire et qu'un tiers ne le peut pas.
- [ ] Noter tout bouton visible qui n'a pas d'action fonctionnelle.

Résultat attendu : la conversation est distincte du matching et n'est accessible qu'aux participants autorisés.

## Preuves à enregistrer

Pour chaque étape, noter :

- date/heure et environnement (sans inclure de secrets) ;
- compte de test utilisé (rôle, jamais le mot de passe ou le jeton) ;
- résultat : PASS / FAIL / BLOCKED / NOT RUN ;
- URL ou route testée ;
- identifiants des données de test, si applicables ;
- capture d'écran ou extrait de log expurgé ;
- erreur complète si échec, en supprimant cookies, tokens, clés et données personnelles.

## Règles de clôture

- Ne marquer une fonction `VALIDÉE` que si le scénario correspondant passe de bout en bout.
- Un build réussi ou un test API de validation ne prouve pas le fonctionnement du parcours métier.
- Tout échec doit être reproduit et attribué au fichier, à la règle RLS ou à la configuration concernée avant correction.
- Ne pas fusionner la PR ni déployer en production uniquement sur la base de ce plan ; les résultats réels sont requis.


## Résultats d'inspection du code — 20 octobre 2026

Les résultats ci-dessous sont des constats de revue de code, pas des tests métier exécutés sur Supabase.

- **FINDING-PUBLISH-DEMAND-01 — Corrigé dans la branche de travail :** la fonction SQL `dt_publish_product_request` créait une ligne `demands` avec `demand_status = 'draft'` alors que la demande source `product_requests` recevait `status = 'published'`. Le pont a été aligné pour créer la demande métier en `published`. Migration à appliquer uniquement après revue et validation en environnement de test.
- **FINDING-OFFER-MASTER-01 — Corrigé dans la branche de travail :** l'endpoint multipart pouvait accepter un `productMasterId` différent du Product Master de la demande. Le serveur dérive maintenant l'identifiant de la demande et rejette une valeur contradictoire.
- **FINDING-OFFER-OWNER-01 — Corrigé dans la branche de travail :** l'endpoint multipart et l'action serveur vérifient maintenant que le demandeur est le propriétaire de la demande avant de créer l'offre.
- **FINDING-MATCH-OWNER-01 — Corrigé dans la branche de travail :** la page de matching vérifie la session, le profil QIMA et le `requester_actor_id` avant d'exposer le matching d'une demande.
- **FINDING-CONVERSATION-PARTICIPANTS-01 — Corrigé dans la branche de travail :** les actions de conversation exigent une paire demande/offre associée à un match accepté, vérifient que l'acteur courant est le propriétaire de la demande ou du fournisseur, refusent l'accès aux tiers et refusent un échange où le même acteur serait des deux côtés.
- **FINDING-CONVERSATION-UI-01 — Corrigé dans la branche de travail :** les rejets/erreurs inattendus du chargement et de l'envoi sont interceptés pour éviter une promesse non gérée dans l'interface.

### Exécution des tests

- **CI-PR23-01 — PASS :** GitHub Actions `QIMA CI`, run [39423877081](https://github.com/meridane/QimaTrade-MVP/actions/runs/39423877081), commit `5bcc76bddf4c68a25eaf07497a61d3e1b244d930`. Installation, audit, TypeScript, build et tests Playwright existants ont réussi avant ces nouveaux changements.
- **CODEQL-PR23-01 — PASS :** run [39423877094](https://github.com/meridane/QimaTrade-MVP/actions/runs/39423877094), même tête de PR.
- **E2E-BUSINESS-01 — BLOCKED / NOT RUN :** pas d'exécution réelle des deux comptes sur un Supabase de test ni preuve d'accès RLS. Aucun compte, aucune donnée métier et aucun jeton Supabase de production n'ont été utilisés pour cette revue.
- **CI-BRANCH-01 — À EXÉCUTER :** les changements dans `feature/e2e-demand-conversation-guards` doivent passer par TypeScript, build, Playwright et CodeQL. Les tests Playwright ajoutés sont des tests de garde-fou HTTP/route, ils ne remplacent pas le test avec deux comptes.
- **RLS-REVIEW-01 — À FAIRE :** examiner les politiques et privilèges existants des tables `demands`, `offers`, `matches` et `messages` avant d'affirmer que l'isolation est garantie par la base. Aucune policy RLS n'a été modifiée dans cette branche.

### Limites restant à vérifier

- Le workflow et les statuts exacts de la table `demands` doivent être confirmés sur une base de test pour s'assurer que `published` est une valeur admise par toutes les contraintes/triggers de la version actuellement déployée.
- Le parcours `product_requests` → action universelle → RPC `dt_publish_product_request` → demande visible côté matching reste à exécuter avec un compte de test.
- Le flux d'acceptation d'offre via `respondToOffer` doit être vérifié de bout en bout et protégé contre une acceptation par un acteur qui n'est pas propriétaire de la demande. La branche actuelle ne modifie pas encore cette action.
- Le chargement des conversations doit être validé avec les policies RLS existantes. Le contrôle applicatif ajouté ne remplace pas ces policies.

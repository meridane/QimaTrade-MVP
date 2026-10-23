# QimaTrade — Registre maître de validation intégrale (MVP + V1)

Date de cadrage : 23 octobre 2026
Branche de travail : `chore/qima-free-autopilot-review`
Statut global : **NON VALIDÉ — travail à poursuivre**
Portée : plan de couverture complet et traçabilité documentaire. Ce document n'affirme pas que les tests ont été exécutés.

## 1. Règle non négociable

Aucune fonctionnalité ne sera considérée comme terminée parce qu'une page, une route, une table, une fonction SQL ou une CI existe.

Chaque exigence doit passer par les étapes suivantes :
1. **Spécifiée** : exigence et règles métier liées à une source Notion ou à une décision approuvée.
2. **Implémentée** : fichiers de code et migrations versionnées identifiés.
3. **Testée localement** : cas positif, cas négatif, limites et erreurs.
4. **Testée de bout en bout** : parcours utilisateur complet dans un environnement isolé.
5. **Sécurité vérifiée** : authentification, autorisation, ownership, isolation inter-utilisateurs/tenants et validation des entrées.
6. **Documentée** : résultat, commit SHA, environnement, date, preuve et limites consignés.
7. **Acceptée** : validation explicite selon les critères ci-dessous.

Si une ancienne fiche MVP est marquée VALIDÉ/PASS mais qu'aucune preuve reproductible n'existe, que le test échoue aujourd'hui ou que le comportement n'est pas démontré sur le code courant, **le test est rouvert et recommencé**. Les anciens résultats sont conservés comme historique, jamais effacés ni présentés comme une validation actuelle.

## 2. Statuts normalisés

- `NON AUDITÉ` : pas encore examiné.
- `À FAIRE` : exigences ou implémentation manquantes.
- `À TESTER` : code présent, preuve comportementale insuffisante.
- `ÉCHEC` : un test actuel a échoué.
- `BLOQUÉ` : dépendance ou environnement empêche de tester.
- `PASS LOCAL` : cas réussi localement, SHA et logs enregistrés.
- `PASS E2E` : parcours complet réussi dans environnement isolé.
- `PASS SÉCURITÉ` : autorisations et isolation prouvées par tests positifs et négatifs.
- `ACCEPTÉ V1` : tous les niveaux requis sont passés, documentation complète.
- `DÉPLOYÉ VÉRIFIÉ` : déploiement autorisé puis vérification post-déploiement documentée.

Les statuts sont propres à chaque test et environnement. Un PASS local ne vaut pas PASS E2E ; un PASS E2E ne vaut pas PASS SÉCURITÉ ; aucun de ces statuts ne vaut DÉPLOYÉ VÉRIFIÉ.

## 3. Inventaire fonctionnel intégral à fermer

Le registre fonctionnel détaillé est maintenu dans [QIMA_V1_FUNCTION_REGISTER.md](../QIMA_V1_FUNCTION_REGISTER.md). Chaque ligne ci-dessous est un lot obligatoire de validation. Tous commencent au minimum avec une vérification de l'état réel sur le SHA courant ; aucun n'est accepté sur la seule base d'une présence technique.

| ID | Fonction / périmètre obligatoire | Minimum de preuve avant acceptation |
|---|---|---|
| AUTH-01 | Connexion Google, callback, session, déconnexion, expiration | Parcours valide, callback absent/invalide, retour sûr, reprise de session |
| AUTH-02 | Profil, onboarding, validation/reprise | Nouveau compte, champs requis, interruption/reprise, état incomplet |
| AUTH-03 | Rôles, permissions, SUPERADMIN et accès refusés | Matrice de rôles et tests utilisateur autorisé/non autorisé |
| TAX-01 | Domaines, catégories, sous-catégories, Product Master | Références, recherche, liens, données officielles, accès RLS, intégrité |
| DT-01 | Arbre de décision MVP | Parcours complet, réponses, sélection, persistance et reprise |
| DT-02 | Arbre de décision universel configurable | Configurations valides/invalides, branches, réponse, reprise, actions, permissions |
| OFFER-01 | Création, modification, lecture, publication d'offres | Validation, prix/quantité/devise, ownership, statut, erreurs, pièces jointes |
| DEM-01 | Demande et qualification | Création, sauvegarde, rechargement, édition, publication, ownership |
| MATCH-01 | Matching expliqué | Scénarios positif/négatif pour quantité, budget, devise, marché, attributs, tri et doublons |
| CHAT-01 | Conversations et messages | IDs Demand + Offer, participants, messages multiples, rechargement, horodatage, idempotence, isolation |
| TRANS-01 | Cycle transactionnel | États/transitions approuvés, acteurs, historique ; QIMA ne conserve pas les fonds |
| SHIP-01 | Transport et suivi | Demande, devis/acceptation si applicable, états, preuve manuelle/API, erreurs |
| SHOW-01 | Showcase/publications | Création, affichage, modification, statut, séparation publication/transaction |
| TRUST-01 | Signaux/score de confiance | Modèle approuvé, calcul explicable, données absentes, abus, tests de non-régression |
| POLICY-01 | Moteur de politiques | Configuration métier approuvée, allow/deny/unknown, ordre, erreurs et audit |
| RULE-01 | Moteur de règles | Opérateurs, types, valeurs absentes, limites, UNKNOWN, cas invalides |
| WF-01 | Workflows/transitions | Transitions autorisées/interdites, acteur, état précédent, concurrence et audit |
| EVENT-01 | Outbox/événements/consommateurs | Enregistrement atomique, réservation, retries, échec/DLQ, idempotence, supervision |
| NOTIF-01 | Notifications/préférences/livraison | Création, lecture, préférences, livraison, erreurs, doublons |
| ADMIN-01 | Administration utilisateurs/rôles/configuration | Écrans, actions autorisées/refusées, confirmations et journalisation |
| AUDIT-01 | Journal d'audit/historique | Acteur, action, cible, horodatage, immutabilité/accès, couverture des actions sensibles |
| UI-01 | Tableau de bord utilisateur | Navigation, données réelles isolées, chargement, états vides/erreurs, responsive, accessibilité |
| UI-02 | Tableau de bord administrateur | Fonctionnalités administratives, permissions, filtres, états vides/erreurs, responsive |
| QA-01 | Automatisation QA | Tests unitaires/contrats, navigateur E2E, tests de sécurité, rapports reproductibles |
| OPS-01 | Build, déploiement, secrets, logs/observabilité | Variables sans fuite, santé, logs, alertes, procédure de rollback documentée et autorisée |

## 4. Parcours MVP à recommencer et fermer

### MVP-A — Authentification et accès
- A01 : utilisateur neuf se connecte par Google.
- A02 : callback absent, mal formé ou expiré est rejeté proprement.
- A03 : session valide, rafraîchissement, déconnexion et session expirée.
- A04 : onboarding incomplet, sauvegarde, reprise et fin.
- A05 : chaque rôle reçoit uniquement les accès autorisés.
- A06 : compte non autorisé ne peut pas lire ni modifier des ressources privées.
- A07 : SUPERADMIN est correctement reconnu sans contourner les contrôles.

### MVP-B — Taxonomie et Product Master
- B01 : parcourir domaines/catégories/sous-catégories.
- B02 : rechercher et sélectionner un Product Master canonique.
- B03 : valider liens parent/enfant et références orphelines.
- B04 : données officielles et valeurs d'attributs correctes.
- B05 : lecture/écriture avec rôles différents, sans accès non autorisé.
- B06 : cas vides, inconnus, valeurs invalides, pagination/recherche si disponibles.
- B07 : retrouver et rejouer les tests Notion 34–48 ; rouvrir tout test sans preuve actuelle.

### MVP-C — Decision Tree
- C01 : démarrer une session et recevoir le premier nœud attendu.
- C02 : soumettre une réponse valide et suivre la bonne branche.
- C03 : réponse manquante/invalide/incompatible rejetée.
- C04 : sélection produit, détails et attributs attendus.
- C05 : rechargement/reprise sans perte ou saut incohérent.
- C06 : session d'un utilisateur inaccessible à un autre.
- C07 : RPC et appels SQL réels testés en environnement isolé, pas uniquement simulés.

### MVP-D — Demand et Qualification
- D01 : créer une demande avec les champs requis.
- D02 : sauvegarder qualification et vérifier les données après rechargement.
- D03 : modifier uniquement le budget sans effacer devise, date, géographie, termes, documents ou attributs.
- D04 : liste, détail, édition et réouverture gardent le même identifiant.
- D05 : demande visible seulement au propriétaire et aux acteurs explicitement autorisés.
- D06 : valeurs invalides, champs vides, limites et échec de sauvegarde affichent une erreur claire.
- D07 : décisions de source de vérité entre colonnes relationnelles et `scope` doivent être retrouvées/validées avant toute modification de modèle.

### MVP-E — Offre et publication
- E01 : créer une offre valide et la retrouver après rechargement.
- E02 : quantité/prix/devise/produit invalides sont rejetés.
- E03 : édition partielle préserve les champs non modifiés.
- E04 : publication suit le statut et les permissions attendus.
- E05 : un autre utilisateur ne peut pas modifier l'offre d'autrui.
- E06 : pièce jointe et erreurs de stockage, si applicables.
- E07 : offres/demandes ne sont jamais mélangées par IDs ou contexte.

### MVP-F — Matching explicable
- F01 : demande et offres utilisent le même Product Master canonique.
- F02 : scénarios quantity pass/fail.
- F03 : scénarios budget pass/fail, prix/devise manquants.
- F04 : scénarios devise et marché pass/fail.
- F05 : attributs requis pass/fail et attributs absents.
- F06 : classement stable et explication correspondant au score affiché.
- F07 : offre non compatible exclue ou clairement signalée selon la règle approuvée.
- F08 : utilisateur ne peut pas matcher/lire des objets non autorisés.
- F09 : cas sans offre, données incomplètes et erreurs.

### MVP-G — Conversation et messages
- G01 : ouvrir la conversation avec Demand ID et Offer ID corrects.
- G02 : vérifier participants autorisés et rejet d'un non-participant.
- G03 : envoyer plusieurs messages dans l'ordre attendu.
- G04 : messages et auteur sont persistés et réapparaissent après rechargement.
- G05 : horodatage et ordre cohérents.
- G06 : double clic/retry ne crée pas de doublon lorsque l'idempotence est attendue.
- G07 : conversation d'une demande/offre ne révèle pas celle d'une autre.
- G08 : erreurs de réseau/validation affichées sans effacer le texte de l'utilisateur.
- G09 : retrouver une fiche TEST 14 Conversation si elle existe ; sinon créer une fiche dédiée dans Notion sans écraser les archives.

### MVP-H — Parcours complet de régression
Rejouer intégralement, avec des comptes et données synthétiques :
**Google login → onboarding → taxonomie/Product Master → Decision Tree ou création Demand → qualification → liste/édition/rechargement → matching expliqué → sélection offre → conversation → plusieurs messages → rechargement → contrôles d'accès.**

Chaque étape doit vérifier l'identifiant utilisé par l'étape suivante, la persistance en base et l'absence de fuite inter-utilisateurs. Un échec d'une étape fait échouer le parcours complet et ouvre un ticket avec preuve.

## 5. Lots V1 additionnels obligatoires

- V1-01 : transaction et règles de transition, sans détention de fonds par QIMA.
- V1-02 : transport, devis/acceptation et suivi.
- V1-03 : showcase/publication et distinction avec transaction.
- V1-04 : trust score/signaux, modèle approuvé et explication.
- V1-05 : moteur de policies, règles et résultat UNKNOWN.
- V1-06 : workflow déterministe, transitions et audit.
- V1-07 : outbox/worker/consommateurs, retries et DLQ ; existence de fonctions seules insuffisante.
- V1-08 : notifications et préférences.
- V1-09 : interfaces admin et utilisateur, responsive et erreurs.
- V1-10 : journal d'audit vérifié par actions métier réelles.
- V1-11 : opérations, observabilité, sauvegarde et procédure de retour arrière documentée.

Les règles métier absentes ou ambiguës doivent devenir des questions/décisions ouvertes ; aucune règle n'est inventée pour faire passer un test.

## 6. Sécurité et intégrité — portes bloquantes

1. **Migration provenance** : l'audit récent signale un écart entre les migrations enregistrées sur Supabase et les fichiers SQL versionnés. Retrouver la série canonique et établir une correspondance avant toute migration.
2. **RLS/grants** : examiner table par table policies, grants, fonctions, vues, triggers, usages applicatifs et dépendances. L'absence de policy n'est pas automatiquement la preuve qu'une table est inutilisée.
3. **Cross-tenant** : tester les rôles anon/authenticated et les utilisateurs/tenants synthétiques dans un environnement isolé qui reflète réellement les policies et RPC Supabase.
4. **Secrets** : aucune clé secrète, token ou donnée personnelle dans le code, les logs, les captures ou les artefacts.
5. **Aucune opération de production** : pas de reset, migration, changement de droits/policies, suppression, merge ou déploiement sans autorisation explicite.
6. **Limite du harness** : un fixture PostgreSQL synthétique avec shim `auth.uid()` ne prouve pas à lui seul le comportement du projet Supabase réel.

État de départ connu au 23 octobre : **Security Gate NOT PASS**. Il reste ainsi jusqu'à la production de preuves suffisantes.

## 7. Documentation à tenir à jour

Pour chaque exigence/test, enregistrer :
- ID unique et description ;
- lien vers la décision/fiche Notion source ;
- fichiers applicatifs et migrations concernés ;
- préconditions et données synthétiques ;
- étapes exactes et résultat attendu ;
- résultat observé, logs/capture/rapport ;
- commit SHA, branche, environnement et date ;
- statut normalisé ;
- défauts ouverts, responsable/prochaine action ;
- lien PR/commit correspondant ;
- limites de la preuve.

Documents Git à garder synchronisés :
- `docs/QIMA_V1_FUNCTION_REGISTER.md` — inventaire des fonctions ;
- `docs/audits/2026-10-23-documentation-status-review.md` — état documentaire/sécurité ;
- `docs/audits/2026-10-23-blueprint-register-comparison.md` — écarts Blueprint/registre ;
- `docs/audits/2026-10-23-demand-workflow-next-tests.md` — tests du parcours Demand ;
- ce registre maître — couverture totale et règles de fermeture.

Notion reste la source d'intention/décisions et de fiches de test ; Git reste la source du code et des migrations versionnées. Les mises à jour Notion doivent être confirmées par la réponse de l'outil ; si elles échouent, signaler l'échec et conserver la mise à jour Git comme telle, sans prétendre que Notion a été modifié.

## 8. Ordre d'exécution sans raccourci

- Phase 0 — inventaire complet des tests Notion et du code courant ; rattacher chaque test à un ID de fonctionnalité.
- Phase 1 — reconstruire les fixtures/environnements isolés gratuits et reproductibles ; ne pas utiliser la production.
- Phase 2 — sécurité/auth/permissions et provenance des migrations (bloquant).
- Phase 3 — MVP-A à MVP-C : auth, taxonomie, Decision Tree.
- Phase 4 — MVP-D à MVP-G : Demand, Offer, Match, Conversation.
- Phase 5 — MVP-H : parcours E2E complet et régressions.
- Phase 6 — V1-01 à V1-11 : toutes les fonctions restantes.
- Phase 7 — revue UI, responsive, accessibilité, erreurs, documentation et reprise des tests en échec.
- Phase 8 — revue finale de couverture ; chaque exigence est ACCEPTÉ V1 ou possède un blocage explicitement documenté.
- Phase 9 — toute mise en production est un jalon distinct qui nécessite autorisation explicite et vérification post-déploiement.

Ne jamais passer à la phase suivante en masquant un échec ou un test non exécuté. Les tests bloqués restent visibles et ont une action de déblocage.

## 9. Premier travail concret après ce plan

1. Extraire la liste complète des fiches de tests Notion, y compris TEST 34–48 et tous les tests du Decision Tree, du workspace/projet et des transactions.
2. Comparer chaque fiche à un scénario de ce registre, sans modifier les statuts historiques.
3. Créer la matrice de traçabilité avec une ligne par test Notion et par test nouveau.
4. Vérifier les tests actuellement présents dans `tests/e2e`, scripts de sécurité, CI et migrations versionnées.
5. Exécuter uniquement les tests sans écriture de production ; tout test exigeant une base ou un secret absent est marqué BLOQUÉ avec raison.
6. Publier le rapport de couverture manquante avant de modifier le code métier.

## 10. Critère final de fin de projet

Le parcours n'est terminé que lorsque :
- toutes les fonctions du registre sont couvertes ;
- tous les tests MVP ont été retrouvés et rejoués ou recréés, y compris les tests précédemment « validés » ;
- tous les scénarios de régression et de sécurité requis ont des preuves actuelles ;
- aucune anomalie bloquante n'est cachée ;
- les décisions métier et la provenance des migrations sont explicites ;
- Git et Notion ont des liens de traçabilité cohérents ;
- les limites restantes sont acceptées explicitement ;
- aucune fonctionnalité n'est faussement déclarée validée.

**État actuel : le travail n'est pas terminé. Ce registre définit la couverture attendue ; les tests doivent encore être exécutés et les preuves ajoutées.**

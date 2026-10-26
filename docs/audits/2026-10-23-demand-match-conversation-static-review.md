# QimaTrade — revue statique ciblée Demand / Match / Conversation

Date : 23 octobre 2026
Branche : `chore/qima-free-autopilot-review`
Nature : lecture du code Git uniquement. **Aucun test runtime n'a été exécuté et aucun code applicatif n'a été modifié.**
Référence de conception : TESTS Notion 12–15 et 28–30.

## 1. Fichiers relus

- `app/demands/qualification/actions.ts`
- `app/demands/qualification/page.tsx`
- `app/demands/match/page.tsx`
- `app/demands/conversation/page.tsx`
- `app/demands/conversation/actions.ts`
- `app/demands/list/page.tsx`

## 2. Constats et tests à écrire

### FINDING-QM-01 — Qualification : mise à jour partielle susceptible d'effacer des données

**Code observé :** `qualifyDemand()` lit `existingScope`, puis construit `nextScope` avec `...existingScope` mais remplace intégralement `qualification` par les valeurs reçues. Il met aussi à jour `budget`, `currency`, `deadline`, `geography`, `documentation_status` et `demand_status` à partir de l'appel.

**Risque :** si une soumission n'envoie pas tous les champs déjà sauvegardés, les champs non envoyés ou vides peuvent être remplacés par `null`, une chaîne vide, un tableau vide ou le statut `draft`. Le fait que le formulaire actuel précharge des valeurs ne garantit pas que tous les appels futurs sont complets.

**Source de régression :** [TEST 30 — Partial Update Must Not Erase Data](https://app.notion.com/p/3c6595ef6360811293fbd2ad532e107f) exige qu'une modification du budget seul conserve termes commerciaux, géographie, date, devise et documents ; [TEST 28](https://app.notion.com/p/3c6595ef6360811da2aff06ac1df1841) et [TEST 29](https://app.notion.com/p/3c6595ef636081a6bf27f5abfd76bbaa) exigent persistance/rechargement.

**Statut :** risque confirmé par lecture du code, comportement runtime à prouver. Ne pas marquer comme bug reproduit tant que le test isolé n'a pas échoué.

**Test requis :** créer une demande synthétique avec tous les champs, relire la ligne, appeler la mise à jour avec seulement le budget modifié, relire et comparer chaque champ hors budget. Ajouter aussi un test de soumission complète du formulaire pour préserver le comportement normal.

**Correction envisagée après test :** définir explicitement le contrat d'update partiel/complet ; pour un update partiel, fusionner les valeurs reçues avec la qualification existante et ne modifier que les colonnes fournies. Ne pas implémenter avant d'avoir établi la sémantique souhaitée et un test rouge reproductible.

### FINDING-QM-02 — Matching : valeurs manquantes comptées comme compatibles

**Code observé :** dans `app/demands/match/page.tsx`, `budgetOk` est vrai si le budget de la demande est nul **ou si le prix de l'offre est nul** ; `currencyOk` est vrai si la devise de la demande ou celle de l'offre est absente ; `marketOk` est vrai si le marché cible ou le marché de l'offre est absent.

**Risque :** une donnée absente peut augmenter le score comme si le critère était validé. Cela peut présenter une offre comme compatible sans preuve de budget/devise/marché. La règle métier pour UNKNOWN/missing n'est pas complètement fixée par la fiche historique TEST 13.

**Statut :** constat statique confirmé ; résultat fonctionnel et règle attendue à valider.

**Tests requis :** offres avec prix/devise/marché absents ; budget absent ; devise/marché manquants des deux côtés ; vérifier le score affiché, l'explication et le classement. Définir si le résultat doit être PASS/FAIL/UNKNOWN plutôt que traiter l'absence comme PASS. Ne pas inventer la règle métier.

### FINDING-QM-03 — Conversation : vérification explicite des participants absente des actions lues

**Code observé :** `loadConversation()` vérifie l'identité de l'utilisateur et l'existence de la demande et de l'offre, puis interroge `messages`. `sendConversationMessage()` vérifie que le message n'est pas vide, la longueur et l'identité, puis tente un INSERT. Ces actions ne contiennent pas de vérification explicite que l'acteur participe à la demande/offre.

**Risque :** la sécurité dépend donc des politiques RLS et contraintes serveur/base effectives. Puisque le Security Gate reste NOT PASS, la protection des conversations ne peut pas être inférée de ce code seul.

**Statut :** absence de contrôle explicite constatée dans les actions ; vulnérabilité exploitable non confirmée tant que policies et RPC ne sont pas vérifiées.

**Tests requis :** deux acteurs synthétiques, demande/offre et messages liés ; le participant autorisé peut lire/écrire ; le non-participant ne peut ni lire ni écrire, même en connaissant les IDs. Vérifier également qu'une paire Demand/Offer incohérente est rejetée.

### FINDING-QM-04 — Matching et conversation s'appuient sur l'isolation RLS

**Code observé :** la page Match lit une demande par ID et des offres par Product Master sans contrôle d'ownership explicite dans ce composant. Les actions de conversation interrogent les demandes/offres/messages avec des IDs fournis. Ces lectures peuvent être correctement filtrées par RLS, mais le code seul ne prouve pas cette garantie.

**Tests requis :** mêmes IDs appelés par deux utilisateurs/tenants ; vérifier le filtrage réel dans le Supabase de test représentatif et les politiques appliquées aux tables `demands`, `offers`, `messages`, `profiles`.

## 3. Ordre de travail proposé

1. Créer des tests de contrat isolés pour QM-01 et QM-02 sans données réelles.
2. Vérifier la structure/policies de test et les règles de source de vérité entre colonnes de `demands` et `scope.qualification`.
3. Reproduire les cas de participant/non-participant dans un environnement représentatif.
4. Corriger seulement les tests qui échouent, en séparant chaque correctif dans une branche/PR et en donnant le fichier complet modifié.
5. Rejouer les tests du parcours complet : qualification → reload → partial update → match → conversation → 3+ messages → reload → isolation.

## 4. Limites

- Ce rapport ne dit pas que les tests ont été exécutés.
- Aucune mutation de base, migration, modification de policy, merge ou déploiement n'a été effectué.
- Le fixture PostgreSQL local décrit dans le dépôt est synthétique et ne remplace pas les vrais RPC ni un schéma Supabase représentatif.

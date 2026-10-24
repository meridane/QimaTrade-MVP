# QimaTrade — contrat de tests de régression Demand / Match

Date : 24 octobre 2026
Branche cible : `chore/qima-free-autopilot-review`
Statut : **spécification de tests — non exécutée**.

Ce document transforme les constats de la revue statique en scénarios de régression. Il ne prétend pas que les tests existent déjà ni qu'un bug a été reproduit.

## Pourquoi ne pas ajouter immédiatement un test unitaire classique ?

Le dépôt expose actuellement `test:e2e = playwright test`, avec `tests/e2e` comme répertoire de tests. `package.json` ne déclare pas Vitest/Jest ni de commande de tests unitaires. Ajouter un test qui copie simplement la logique actuelle dans un fichier séparé donnerait une fausse assurance : il testerait la copie, pas le code de production.

La première étape est donc de définir le contrat attendu, puis de choisir une couture testable (fonctions pures extraites dans un module partagé, ou tests d'intégration contre un Supabase local représentatif). Aucune donnée réelle ni base de production ne doit être utilisée.

## QM-01 — Une mise à jour partielle ne doit pas effacer la qualification

Source métier : [TEST 30 — Partial Update Must Not Erase Data](https://app.notion.com/p/3c6595ef6360811293fbd2ad532e107f), complété par TEST 28 et TEST 29.

### Jeu de données synthétique initial

```json
{
  "budget": 40000,
  "currency": "USD",
  "deadline": "2026-12-31",
  "geography": "Casablanca",
  "scope": {
    "product_master_id": "synthetic-product-id",
    "commercial_terms": "FOB",
    "documentation": "certificate required",
    "qualification": {
      "budget": 40000,
      "currency": "USD",
      "deadline": "2026-12-31",
      "geography": "Casablanca",
      "commercial_terms": "FOB",
      "documentation": "certificate required",
      "attributes": [{ "key": "purity", "value": "99.5" }]
    }
  }
}
```

### Scénarios

| ID | Action | Résultat attendu |
|---|---|---|
| QM-01a | Modifier uniquement le budget de 40 000 à 42 000 USD | Tous les autres champs sauvegardés restent identiques. |
| QM-01b | Recharger puis rouvrir la qualification | Les valeurs persistées sont identiques avant et après le rechargement. |
| QM-01c | Soumettre le formulaire complet avec des changements explicites | Les changements demandés sont sauvegardés ; les autres propriétés de `scope` restent présentes. |
| QM-01d | Envoyer une valeur absente/non fournie selon le contrat partiel | Elle ne doit pas être assimilée silencieusement à une demande d'effacement. |
| QM-01e | Demander explicitement d'effacer un champ, si cette action est supportée | Seul le champ visé est effacé ; les autres restent inchangés. |

### Contrôles de comparaison

Comparer avant/après : `scope.product_master_id`, `scope.commercial_terms`, `scope.documentation`, `scope.qualification.currency`, `deadline`, `geography`, `documentation_status`, `demand_status` et les attributs. Le comportement des statuts doit être fixé explicitement avant le test : une sauvegarde partielle ne doit pas remettre automatiquement la demande en brouillon ou les documents à incomplet sans règle métier validée.

### Risque statique qui motive les tests

Dans `app/demands/qualification/actions.ts`, `qualifyDemand()` reconstruit tout l'objet `qualification` à partir de l'entrée et fixe les statuts à `incomplete` et `draft`. C'est un risque identifié à la lecture du code ; aucune reproduction runtime n'est encore disponible.

## QM-02 — Une donnée manquante n'est pas une preuve de compatibilité

Source métier historique : [TEST 13 — Explainable Match](https://app.notion.com/p/3c6595ef636081c0a172ed67c0bf50b8). Ce test documente les critères et le score, mais ne tranche pas complètement la sémantique des valeurs absentes. La règle doit donc être décidée avant de figer l'assertion finale.

### Scénarios minimums

| ID | Demande | Offre | Vérification |
|---|---|---|---|
| QM-02a | Budget défini, devise définie | Prix absent | Le critère ne doit pas être présenté comme un PASS certain ; afficher un état indéterminé ou appliquer la règle métier approuvée. |
| QM-02b | Budget/devise définis | Prix et devise présents, devise différente | L'offre ne doit pas recevoir un PASS devise. |
| QM-02c | Marché cible défini | Marché de l'offre absent | L'absence doit être visible et ne pas compter comme une correspondance confirmée. |
| QM-02d | Marchés présents | Marchés différents | Critère marché en échec. |
| QM-02e | Budget non spécifié dans la demande | Prix présent dans l'offre | Vérifier la règle métier : critère non applicable, pas automatiquement une preuve de compatibilité. |
| QM-02f | Quantité suffisante mais autres critères inconnus | Prix/devise/marché manquants | Le score et le tri ne doivent pas masquer les inconnues. |

**Décision métier requise :** choisir entre au moins trois états par critère (`PASS`, `FAIL`, `UNKNOWN`) et décider si `UNKNOWN` est exclu du score, pénalisé ou affiché séparément. Ne pas inventer ce choix à partir du code existant.

## QM-03 — Conversations : isolation des participants

Les tests doivent être exécutés uniquement avec des utilisateurs, demandes, offres et messages synthétiques dans un environnement de test isolé.

| ID | Acteur | Action | Résultat attendu |
|---|---|---|---|
| QM-03a | Participant autorisé | Lire la conversation | Accès autorisé selon le modèle métier. |
| QM-03b | Participant autorisé | Envoyer un message valide | Message lié à la bonne demande et à la bonne offre. |
| QM-03c | Non-participant connaissant les IDs | Lire les messages | Refus effectif côté serveur/base. |
| QM-03d | Non-participant connaissant les IDs | Insérer un message | Refus effectif côté serveur/base. |
| QM-03e | Participant d'une autre demande | Mélanger un ID de demande et un ID d'offre incohérents | Requête rejetée. |
| QM-03f | Participant | Envoyer deux fois rapidement le même message/action | Appliquer le contrat d'idempotence approuvé ; vérifier les doublons persistés. |

Les vérifications de l'interface seules ne suffisent pas. Il faut vérifier les politiques RLS réellement appliquées et les résultats côté serveur/base. Le fixture PostgreSQL existant est documenté comme un contrat synthétique et ne remplace pas l'exécution des RPC Supabase réels.

## Ordre d'implémentation des tests

1. Lire les tests E2E existants et le script du fixture PostgreSQL.
2. Extraire les fonctions pures de fusion de qualification et d'évaluation de critères dans des modules partagés, seulement après validation de la sémantique métier.
3. Ajouter des tests ciblant ces modules et brancher la commande de test dans CI.
4. Ajouter les tests d'intégration de persistance et d'isolation dans une base locale jetable et représentative.
5. Exécuter les tests et enregistrer les sorties, versions, commit SHA et limites.
6. Corriger les implémentations uniquement après un test rouge reproductible ; relancer le test rouge puis toute la suite concernée.

## Garde-fous

- Pas de données de production.
- Pas de migration, reset, push, modification de policy, merge ou déploiement de production.
- Ne pas déclarer un test PASS sans journal d'exécution réel.
- Séparer « spécifié », « écrit », « exécuté » et « validé ».

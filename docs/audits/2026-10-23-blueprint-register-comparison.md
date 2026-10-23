# QimaTrade V1 — comparaison Blueprint / Registre fonctionnel

Date de revue : 23 octobre 2026  
Branche de travail : `chore/qima-free-autopilot-review`  
Portée : comparaison documentaire uniquement. Aucun code métier, schéma Supabase, donnée ou déploiement modifié.

## Sources consultées

- Blueprint Notion : [QimaTrade V1 — Engineering Blueprint from Validated MVP](https://app.notion.com/p/3c6595ef6360816a8c19dd4650db2e89) — dernière édition visible : 24 août 2026.
- Index de tests Notion : [QimaTrade — MVP TESTS](https://app.notion.com/p/3c6595ef63608182adb9f9345817ed86) — dernière édition visible : 26 août 2026.
- Registre Git : [docs/QIMA_V1_FUNCTION_REGISTER.md](https://github.com/meridane/QimaTrade-MVP/blob/chore/qima-free-autopilot-review/docs/QIMA_V1_FUNCTION_REGISTER.md) — son en-tête indique une dernière vérification le 12 octobre 2026.
- État de sécurité récent : [rapport de revue documentaire du 23 octobre](https://github.com/meridane/QimaTrade-MVP/blob/chore/qima-free-autopilot-review/docs/audits/2026-10-23-documentation-status-review.md).

## Conclusion

Les documents sont globalement compatibles sur les priorités de sécurité, les tests réels de bout en bout et la distinction entre présence technique et fonctionnalité validée. Ils ne sont toutefois pas synchronisés sur les dates, l'ordre de priorité et la profondeur des tests. Le registre Git est un inventaire technique large ; le Blueprint documente plus précisément les invariants du parcours Demand → Qualification → Match → Conversation.

## Correspondances confirmées

| Sujet | Blueprint Notion | Registre Git | Conclusion |
|---|---|---|---|
| Demand / Qualification | Tests 12, 28–30 et règles de persistance | DEM-01 présent, test de création/sauvegarde à poursuivre | Même périmètre métier ; l'état de validation doit être attaché à chaque scénario, pas seulement au module |
| Match | Test 13, critères expliqués séparément | MATCH-01 présent, calcul/explication/doublons à vérifier | Concordance ; présence du code ne prouve pas le parcours complet |
| Conversation | Demand et Offer doivent être liées par IDs ; tous les messages persistés | CHAT-01 présent, participants/envoi/lecture/isolation à tester | Concordance ; manque une preuve récente de test de bout en bout dans le registre Git |
| Source de vérité | Décision explicite requise entre colonnes de `demands` et `demands.scope` | TAX-01 et DEM-01 listés, mais cette décision n'est pas répétée dans le tableau principal | Ajouter un lien explicite vers la règle d'architecture, sans choisir la solution à la place du propriétaire |
| Sécurité et ownership | Contrôle de l'acteur, tests utilisateur autorisé/non autorisé | AUTH-03 et audit P0 RLS | Concordance sur la priorité ; le rapport sécurité récent reste NOT PASS |
| Parcours de régression | Demand → Qualification → List → Edit → Qualification → Match → Conversation → plusieurs messages | Parcours vertical recommandé, mais pas détaillé à ce niveau | Le parcours du Blueprint doit devenir un scénario QA traçable |
| Fonctions moteur | Blueprint insiste sur workflow déterministe, source de vérité et intégrité | DT-02, POLICY-01, RULE-01, WF-01 et EVENT-01 présents techniquement, configurations métier vides | Ne pas considérer ces moteurs prêts à l'usage métier |

## Écarts et incertitudes à traiter

1. **Fraîcheur documentaire différente.** Le Blueprint et l'index Notion datent d'août ; le registre Git affiche le 12 octobre. Le rapport sécurité du 23 octobre indique des constats plus récents. Ne pas écraser l'historique : ajouter des entrées datées et sourcées.
2. **Statuts de validation de portée différente.** Le Blueprint marque les tests 12 et 13 comme VALIDÉ dans son contexte MVP. Le registre V1 indique encore des vérifications à faire pour DEM-01 et MATCH-01. Ce n'est pas forcément une contradiction : le test MVP peut être validé tandis que la robustesse V1 reste à prouver. Les statuts doivent préciser le niveau (MVP, V1, sécurité, production).
3. **Test 14 Conversation.** Le Blueprint donne des exigences de conception, mais l'index des tests fourni ne montre pas de page nommée « TEST 14 — Conversation ». Ne pas supposer qu'un test détaillé existe ou est validé ; retrouver la preuve ou créer une fiche de test dédiée.
4. **Taxonomie / Product Master.** L'index Notion répertorie de nombreux tests de domaines, catégories, sous-catégories et Product Master (tests 34–48). Le registre Git résume cela en TAX-01. Il manque un lien direct vers ces preuves détaillées et leurs décisions validées.
5. **Parcours projet / transaction.** L'index Notion contient des tests Workspace, Participants, Tasks, Timeline, Orders, Inspections et Shipment. Le registre Git précise que les routes `app/projects/test` sont un espace de test et ne prouvent pas un parcours transactionnel QIMA V1 validé. Garder ces deux périmètres distincts.
6. **Migrations et RLS.** Le registre initial et les audits précédents décrivent 31 tables `public` sans policies. Le rapport du 23 octobre signale aussi un écart important entre migrations présentes dans le dépôt et migrations enregistrées sur Supabase. C'est un bloqueur de sécurité/provenance ; aucune migration distante ne doit être lancée pour résoudre l'écart sans retrouver et vérifier la source canonique.
7. **Automatisation et CI.** La CI récente a réussi sur un fixture PostgreSQL isolé et synthétique. Ce résultat ne valide pas les policies réelles de Supabase, les données de production ni tous les RPC du Decision Tree.

## Actions documentaires recommandées — ordre

- [ ] **D1 — Séparer les statuts** : distinguer explicitement « test MVP validé », « conformité V1 », « sécurité multi-tenant validée » et « déployé en production ».
- [ ] **D2 — Tracer les preuves** : ajouter au registre des liens vers les pages de tests Notion correspondant à DEM, MATCH, Conversation, Product Master et aux tests d'accès.
- [ ] **D3 — Créer/identifier le test Conversation** : vérifier les deux IDs (Demand + Offer), participants autorisés, messages multiples, horodatage et isolation entre utilisateurs.
- [ ] **D4 — Source de vérité** : consigner la décision approuvée pour les champs de qualification entre colonnes relationnelles et `scope`; jusqu'à cette décision, ne pas migrer ni réécrire le modèle.
- [ ] **D5 — Sécurité P0** : poursuivre l'inventaire des grants, policies, fonctions, vues et références des tables historiques, en lecture seule d'abord.
- [ ] **D6 — Provenance migrations** : retrouver la série canonique complète avant toute tentative de réconciliation avec l'historique distant.
- [ ] **D7 — Rafraîchir les dates** : actualiser les en-têtes de vérification uniquement après une revue réelle, sans marquer les fonctionnalités VALIDÉES sur la seule base d'un build réussi.

## Garde-fous

- Aucun changement de production, aucune migration Supabase, aucun reset, aucun merge ni déploiement dans cette revue.
- Ne pas supprimer de tables historiques et ne pas ajouter de policies génériques.
- Ne pas inventer de preuve de test ni transformer un statut MVP en validation V1.
- Le Notion reste la source d'intention et de décisions ; Git reste la source du code et des migrations versionnées.

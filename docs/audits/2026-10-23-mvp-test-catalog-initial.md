# QimaTrade — Inventaire initial des fiches MVP et écarts de traçabilité

Date d'inventaire : 23 octobre 2026
Source principale : Notion « QimaTrade — MVP TESTS »
Référence : https://app.notion.com/p/3c6595ef63608182adb9f9345817ed86
État : inventaire partiel en cours — aucune exécution actuelle de ces tests n'est revendiquée.

## 1. Fiches retrouvées par recherche Notion

| ID | Fiche | Source | Ce qu'elle représente à ce stade |
|---|---|---|---|
| TEST 01 | Project Workspace | https://app.notion.com/p/3c6595ef63608198bdc3f21b3f3e3501 | Preuve historique déclarée dans l'audit MVP ; à rejouer sur le code courant |
| TEST 02 | Participants | https://app.notion.com/p/3c6595ef63608105ab43f799b5488889 | Preuve historique ; matrice des permissions encore à compléter |
| TEST 03 | Tasks / Workflow | https://app.notion.com/p/3c6595ef6360816aa8b2efe12c28fc0a | Preuve historique ; transitions interdites/concurrence à retester |
| TEST 04 | Timeline / Events | https://app.notion.com/p/3c6595ef6360810680c9e0cafdcd3c07 | Preuve historique ; couverture automatique de toutes les mutations non démontrée |
| TEST 05 | Orders | https://app.notion.com/p/3c6595ef636081c69121d2d939623737 | Preuve historique ; liaison Demand/Offer→Order et validation serveur à retester |
| TEST 06 | Inspection Creation | https://app.notion.com/p/3c6595ef636081169a61ecec41e80a3c | Preuve historique ; permissions et erreurs à retester |
| TEST 07 | Inspection Findings | https://app.notion.com/p/3c6595ef636081d99cebe174cdd44816 | Preuve historique ; accès fournisseur/inspecteur/acheteur à retester |
| TEST 08 | Inspection Status Workflow | https://app.notion.com/p/3c6595ef6360815faaf8ec5287111228 | Preuve historique ; transitions invalides et permissions à retester |
| TEST 09 | Inspection Relations Order / Shipment | https://app.notion.com/p/3c6595ef63608105bad0e07b5475d125 | Preuve historique ; intégrité référentielle à retester |
| TEST 10 | Shipment Creation & Workflow | https://app.notion.com/p/3c6595ef63608193a561fbc63f6f2806 | Preuve historique ; annulation, transitions invalides et droits à retester |
| TEST 12 | Demand Qualification | https://app.notion.com/p/3c6595ef63608198a061f3e4f1090779 | Ancien MVP VALIDÉ ; rejouer sauvegarde, reload, ownership et édition |
| TEST 13 | Explainable Match | https://app.notion.com/p/3c6595ef636081c0a172ed67c0bf50b8 | Ancien MVP VALIDÉ ; rejouer score, explication, attributs et isolation |
| TEST 15 | MVP End-to-End | https://app.notion.com/p/3c6595ef636081e2a003c46133bf050c | Ancien MVP VALIDÉ ; parcours complet à rejouer sur le SHA courant |
| TEST 17 | Unauthorized Write Protection | https://app.notion.com/p/3c6595ef6360818f95a1ccded1e4f660 | PASS historique sur un scénario de non-participant ; pas une preuve RLS actuelle |
| TEST 18 | Double Submission / Idempotence | https://app.notion.com/p/3c6595ef636081539b22f030fcc8127e | PASS historique côté UI ; serveur et retries à retester |
| TEST 19 | Quantity invalide | https://app.notion.com/p/3c6595ef636081a69926f4dad7388b5c | Cas de validation négative à rejouer |
| TEST 27 | Important Requirements optionnels | https://app.notion.com/p/3c6595ef636081c9b123cee4e3947920 | Cas de champs optionnels à rejouer |
| TEST 28 | Qualification Persistence & Link Integrity | https://app.notion.com/p/3c6595ef6360811da2aff06ac1df1841 | Explicitement à exécuter avant V1 |
| TEST 29 | Demand Workflow Reload / No Data Loss | https://app.notion.com/p/3c6595ef636081a6bf27f5abfd76bbaa | Explicitement à exécuter avant V1 |
| TEST 30 | Partial Update Must Not Erase Data | https://app.notion.com/p/3c6595ef6360811293fbd2ad532e107f | Explicitement à exécuter avant V1 |
| TEST 34 | Category Engine: Qima 0 Decision-First Architecture | https://app.notion.com/p/3c6595ef636081e0955bd64c14ba4bec | Décision d'architecture marquée VALIDÉE, pas une preuve runtime |
| TEST 36 | Metals & Raw Materials: Dimension-Based Product Model | https://app.notion.com/p/3c6595ef636081018243e976c981ed8c | Architecture/validation de modèle ; exécution runtime à prouver |
| TEST 37 | Qima Trade Domains: Full Domain Validation | https://app.notion.com/p/3c6595ef63608188970dfccab0109420 | Architecture/taxonomie ; rejouer les données et contraintes |
| TEST 39 | Qima Object Type Architecture | https://app.notion.com/p/3c6595ef636081169db8fff76158a19e | Architecture ; ne pas compter comme test runtime sans preuve |
| TEST 41 | Human-Friendly Visual Decision Navigation | https://app.notion.com/p/3c6595ef636081e3b2b6e91c03bf050c | Décision UX ; navigation réelle à tester |
| TEST 42 | Industry & Infrastructure Product Master Framework | https://app.notion.com/p/3c6595ef6360815d9428eec6a0568cfc | Framework ; mapping et données à tester |
| TEST 43 | Mobility & Transport Product Master Framework | https://app.notion.com/p/3c6595ef636081ce9b3fd00c793cf04f | Framework ; mapping et données à tester |
| TEST 44 | Technology & Life Sciences Product Master Framework | https://app.notion.com/p/3c6595ef636081908a62d67cb06d9464 | Framework ; mapping et données à tester |
| TEST 45 | Consumer & Lifestyle Product Master Framework | https://app.notion.com/p/3c6595ef636081f3aa4cc6d518bffaaa | Framework ; mapping et données à tester |
| TEST 46 | Circular Economy Product Master & Circularity Layer | https://app.notion.com/p/3c6595ef636081fba85af1fcc4db2bba | Architecture ; données, règles et UX à tester |
| TEST 47 | Taxonomy → Product Mapping Stress Test | https://app.notion.com/p/3c6595ef636081eab288dfab0ac44121 | Stress test à exécuter sur les données courantes |
| TEST 48 | TD05 Technology & Life Sciences — Product Mapping Validation | https://app.notion.com/p/3c7595ef636081b2a1d8ca8dfea6ffcc | Mapping à vérifier sur les données et code actuels |

## 2. Lacunes d'inventaire — ne pas supposer qu'elles n'existent pas

- TEST 11 et TEST 14 n'ont pas été identifiés avec certitude lors des recherches effectuées. Cela ne prouve pas leur absence de Notion ; il faut poursuivre la recherche. En particulier, le Blueprint décrit les exigences Conversation, mais la fiche de test conversation autonome reste à retrouver ou à créer.
- Les tests 16, 20–26 et 31–33, 35, 38, 40 ne sont pas encore tous résolus par cette recherche ciblée. La liste ci-dessus est un inventaire partiel, pas le catalogue complet.
- La recherche Notion a aussi retourné l'index « QimaTrade — MVP TESTS », le registre « QimaTrade — MVP Engineering Test Registry » et l'« Audit 07 — Tous les MVP tests QimaTrade — 25 août 2026 ». Ces sources doivent être parcourues intégralement pour ne laisser aucune fiche de côté.

## 3. Conclusions provenant de l'Audit 07 Notion

Source : https://app.notion.com/p/f1bd4708b17749159f3aaeb40b8cea78

L'Audit 07 sépare explicitement :
- les tests historiquement déclarés fonctionnels/validés dans le MVP ;
- les tests récents (TEST 31 à TEST 46 notamment) qui représentent souvent des décisions de design/architecture et non des validations runtime.

Il signale également des écarts qui doivent être retestés : événements pas nécessairement générés par toutes les mutations critiques, matrice de permissions incomplète, conflits multi-utilisateurs non testés, historique complet non prouvé ; liaison Demand/Offer→Order et validation serveur à renforcer ; workflow d'inspection sans corrective action/evidence/approval complet ; workflow shipment positif validé mais annulation, transitions invalides et permissions insuffisamment testées.

Ces remarques historiques ne décrivent pas automatiquement l'état du code au 23 octobre 2026. Elles sont des exigences de régression à rejouer.

## 4. Règle de statut appliquée

À partir de maintenant, les fiches Notion restent inchangées historiquement tant qu'une mise à jour n'est pas explicitement autorisée et confirmée. Dans le registre Git, chaque ancien PASS est traité comme **PASS HISTORIQUE — À REJOUER** jusqu'à preuve actuelle. Les décisions d'architecture sont **DÉCISION DOCUMENTÉE — RUNTIME À PROUVER**, pas « fonction validée ».

## 5. Prochaine action

Continuer l'inventaire des fiches manquantes, surtout TEST 11, TEST 14, TEST 16, TEST 20–26, TEST 31–33, TEST 35, TEST 38 et TEST 40 ; ensuite construire la matrice complète entre chaque fiche Notion, les fonctions du registre, les fichiers du dépôt, les tests automatiques et les preuves requises.

# QIMA — Revue de l'état de la documentation

Date de revue : 2026-10-23 (UTC)
Dépôt : `meridane/QimaTrade-MVP`
Branche examinée : `chore/qima-free-autopilot-review`
PR de travail : [#25 — réparations de sécurité (DRAFT)](https://github.com/meridane/QimaTrade-MVP/pull/25)

## 1. Objectif et méthode

Cette revue consolide les documents et résultats visibles au moment de l'inspection. Elle ne remplace pas les spécifications fonctionnelles validées et ne marque aucune fonctionnalité comme prête sans preuve. Les états historiques restent identifiés comme tels.

Documents consultés :
- `docs/QIMA_V1_FUNCTION_REGISTER.md` (SHA du fichier consulté : `37389f98e13edd48514af8d3fc0c01718e423b5c`)
- `docs/audits/2026-10-23-current-security-gate.md` (SHA : `5af1f087c696f5ccd044a0e058d61884e5adc255`)
- `docs/testing/qima-local-postgres-harness.md` (SHA : `9cc05a264406d4ecf958a0bc29bac35b4559143a`)
- Notion : `QIMA — Coding Automation & Test Ledger`
- État GitHub Actions observé lors de cette revue.

## 2. État exécutif

- Le registre fonctionnel existe, mais sa date de dernière vérification affichée est le 12 octobre 2026. Il doit être actualisé après vérification fonctionnelle ciblée.
- Le rapport de sécurité du 23 octobre maintient le Security Gate à `NOT PASS` : l'isolation multi-tenant réelle n'est pas démontrée.
- Les sources consultées indiquent 157 migrations enregistrées sur Supabase distant contre 15 fichiers de migration présents dans le dépôt examiné. La source canonique complète n'a pas été retrouvée lors des recherches documentées.
- La fixture PostgreSQL synthétique A/B et ses assertions ont été exécutées par le job dédié de QIMA CI sur le commit `db37c2d39aca68fdfa46a8c88282cac4fe85da60` : le job `Run isolated PostgreSQL security-contract fixture` est indiqué `success`. Cette preuve valide le contrat synthétique exécuté par ce harnais, pas la sécurité du schéma réel Supabase.
- Les RPC réels du Decision Tree ne sont pas validés sur une base canonique.
- La PR #25 est ouverte, en brouillon et non fusionnée. Ne pas fusionner, déployer ou modifier la production dans le cadre de cette revue.
- Un run du workflow « QIMA 15-minute Autonomous Development Loop » sur `main` a terminé avec succès le 23 octobre à 05:35 UTC. Le succès du workflow ne prouve pas à lui seul qu'une tâche de documentation ou de code a été réalisée; le détail des étapes et artefacts doit être inspecté avant toute conclusion.

## 3. Inventaire fonctionnel existant

Le registre contient les domaines suivants. Les états ci-dessous reflètent le registre et non une nouvelle validation fonctionnelle :

| Domaine | ID(s) existants | État documenté | Preuve / prochaine action |
|---|---|---|---|
| Authentification, profil, onboarding et rôles | AUTH-01 à AUTH-03 | Présent dans le dépôt/la base, comportement à tester | Parcours connexion/callback, session, onboarding, permissions avec plusieurs comptes |
| Taxonomie et Product Master | TAX-01 | Présent dans le schéma historique et le dépôt | Vérifier les données officielles, références et accès RLS |
| Arbres de décision MVP et universel | DT-01, DT-02 | Présent; configuration et parcours universel à valider | Tester persistance, branches, reprise, réponses et actions; RPC réels bloqués par le schéma canonique |
| Offres et demandes | OFFER-01, DEM-01 | Routes présentes | Tester validation, propriété, statut, publication, pièces jointes et refus d'accès |
| Matching | MATCH-01 | Présent dans le dépôt et le schéma | Tester calcul, explication, doublons et acceptation |
| Conversations | CHAT-01 | Présent dans le dépôt et le schéma | Tester participants, lecture/écriture, isolation et temps réel |
| Transaction et transport | TRANS-01, SHIP-01 | Tables présentes; cycle métier non validé | Définir et tester les transitions; QIMA ne conserve pas les fonds |
| Showcase | SHOW-01 | Présent en base; UI à confirmer | Vérifier séparation showcase/publication/transaction |
| Confiance | TRUST-01 | Tables présentes; modèle V1 non validé | Définir les signaux, règles d'explication et tests avant de calculer des scores |
| Moteurs Policy, Rules, Workflow, Outbox/Event | POLICY-01, RULE-01, WF-01, EVENT-01 | Fonctions présentes; configurations métier vides selon le registre | Ajouter tests et configurations uniquement après validation des règles; worker/consommateurs à confirmer |
| Notifications | NOTIF-01 | Schéma présent; UI/livraison à tester | Vérifier création, préférences et livraison |
| Administration | ADMIN-01 | Partiel | Définir les écrans V1 et vérifier les permissions |
| Tableau de bord utilisateur et admin | UI-01, UI-02 | Utilisateur partiel; admin à faire/confirmer | Audit visuel responsive, états vides/erreur, navigation et accès admin |
| Qualité et opérations | QA-01, OPS-01 | Tests E2E et opérations à confirmer | Exécuter les contrôles sur le HEAD exact; vérifier secrets, logs et déploiement sans modifier la production |

## 4. Bloquants documentaires et techniques

### P0 — Source canonique des migrations
1. Chercher dans les autres dépôts privés, archives ou sauvegardes contrôlées la source complète des migrations et son historique.
2. Documenter la source trouvée et la méthode de réconciliation avant de proposer toute migration.
3. Si la source n'existe pas, obtenir une décision explicite sur la reconstruction contrôlée du schéma; ne pas fabriquer des migrations historiques.

Interdictions maintenues : aucun `supabase db reset` présenté comme une reproduction fidèle de la production, aucun `supabase db push` distant, aucune migration de production.

### P0 — Sécurité multi-tenant
1. Exécuter la fixture PostgreSQL jetable via `sh scripts/test-qima-security-fixture.sh` et archiver le résultat.
2. Examiner grants, RLS, memberships multiples et fonctions privilégiées sur une base locale fidèle seulement après réconciliation du schéma.
3. Garder le Security Gate à `NOT PASS` jusqu'à l'existence de preuves pertinentes et archivées.

### P1 — Registre V1
Pour chaque ID, préciser : statut actuel, lien vers l'implémentation, test associé, résultat sur un SHA précis, dépendances et décision fonctionnelle manquante. Séparer « code présent » de « parcours validé ».

### P1 — Spécifications de comportement
Relier les règles métier validées aux tests d'acceptation, notamment :
- ownership et isolation tenant;
- création/publication d'offre et de demande;
- matching explicable;
- participants et autorisation des conversations;
- transitions d'état et journal d'audit;
- idempotence des événements et reprises;
- permissions admin;
- onboarding et rôles.

Les détails manquants doivent être marqués « décision requise » et non inventés.

## 5. Contrôles GitHub observés pendant la revue

- QIMA CI — run `39896047987`, commit `db37c2d39aca68fdfa46a8c88282cac4fe85da60`, conclusion `success`. Les étapes TypeScript, audit dépendances, build production, Playwright smoke et fixture PostgreSQL isolée sont toutes indiquées `success`.
- QIMA CodeQL — run `39896048110`, même commit, conclusion `success`.
- Ces résultats ne prouvent pas l'isolation multi-tenant réelle et ne remplacent pas les tests SQL sur le schéma canonique.
- Le run du workflow autonome sur `main` (`39906596740`) s'est terminé avec succès, mais son résultat doit être lu comme un résultat de workflow, pas comme preuve de qualité du code produit.

## 6. Règles de mise à jour documentaire

Pour chaque travail futur :
- noter date, branche, SHA, fichiers modifiés et liens de preuves;
- conserver les statuts `PROPOSÉ`, `DÉCIDÉ`, `IMPLÉMENTÉ`, `TESTÉ`, `DÉPLOYÉ` distincts;
- ne jamais présenter un test non exécuté comme réussi;
- n'utiliser que des données synthétiques dans les tests;
- fournir le chemin exact et le fichier complet corrigé pour un rapport d'erreur;
- aucun merge, déploiement ou changement de production sans autorisation explicite.

## 7. Prochaine séquence de travail

1. Résultat confirmé pour le run CI `39896047987` : toutes les étapes, dont le harnais PostgreSQL isolé, sont indiquées `success`. Conserver la limite de portée : ce n'est pas une preuve de sécurité du schéma Supabase réel.
2. Examiner les spécifications de référence dans Notion et les comparer au registre, sans corriger silencieusement les contradictions.
3. Compléter les liens « fonctionnalité → implémentation → test → preuve » dans le registre.
4. Créer une liste explicite des décisions métier encore requises.
5. Seulement ensuite, déclarer la documentation fonctionnelle prête pour l'agent de coding.

## 8. Statut de cette revue

Cette page est une synthèse documentaire basée sur les fichiers et résultats consultés. Elle n'est pas une validation de production, ne certifie pas la sécurité du schéma distant et ne clôt pas les tâches P0 ci-dessus.

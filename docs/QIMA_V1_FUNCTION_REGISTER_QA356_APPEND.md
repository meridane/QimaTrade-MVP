# QA356 — validation stricte des sorties des assertions de nettoyage

Date : 12 novembre 2026 (KST)  
Dépôt : `meridane/QimaTrade-MVP` — PR #26  
Branche de travail : `work/qa356-assertion-output-contract-20261112-1045`

## État initial vérifié

- PR #26 : OPEN, DRAFT, mergeable, non fusionnée ; HEAD initial `4d0e716ab5a4db1764bc78702dce0e46519339f0`.
- Comparaison initiale avec `main` : 1 492 commits en avance, zéro en retard.
- Fichiers modifiés : 115 ; aucune review humaine ni thread de review.
- Dernier commit initial : `4d0e716`, réconciliation documentaire QA355. Le commit de code QA355 était `b5ed654`.
- QIMA CI #1282 : SUCCESS ; CodeQL #1232 : SUCCESS.
- Le statut combiné du commit initial ne montrait qu'un statut Vercel FAILURE / `api-deployments-free-per-day`. Les contrôles GitHub Actions étaient verts.
- Le registre canonique a été récupéré par son blob Git (le wrapper de contenu par chemin renvoyait un corps vide) ; aucune réécriture historique n'a été faite avant QA356.

## Objectif

Vérifier que les deux assertions bloquantes QA353 (nettoyage réussi) et QA354 (nettoyage échoué) refusent explicitement les sorties manquantes, vides ou incohérentes. Le job PostgreSQL réel, les scripts SQL et les règles de restauration en production ne sont pas modifiés.

## Modifications

1. `tests/ci/assert-prepared-transactions-cleanup-contract.sh` — nouveau script partagé avec deux modes :
   - `success` exige `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=success`, `CLEANUP_RAN=true`, `CLEANUP_EXIT_CODE=0` et `CLEANUP_FAILURE_OBSERVED=false`.
   - `failure` exige `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=failure`, `CLEANUP_EXIT_CODE=52`, `CLEANUP_FAILURE_OBSERVED=true` et l'absence de `CLEANUP_RAN`.
   - Les diagnostics d'entrée invalide sont déterministes et commencent par `ERROR:`.

2. `tests/ci/test-prepared-transactions-cleanup-assertions.sh` — nouveau test du contrat partagé :
   - accepte les deux combinaisons valides ;
   - rejette huit combinaisons invalides : marqueur de succès manquant, code de sortie de succès manquant, marqueur d'échec incohérent, code d'échec manquant, code 51 inattendu, marqueur d'échec manquant, marqueur de succès présent pendant un échec et outcome de nettoyage contradictoire.

3. `.github/workflows/ci.yml` :
   - transmet aussi `cleanup_exit_code` et `cleanup_failure_observed` au job d'assertion du chemin succès ;
   - remplace les assertions shell inline par le script partagé en mode `success` ou `failure` ;
   - ajoute une étape Verify pour les huit cas négatifs ;
   - ajoute un checkout explicite du dépôt aux deux jobs d'assertion, afin que le script partagé soit présent dans leur workspace.

4. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh` :
   - vérifie le nouveau test de sorties négatives ;
   - vérifie les deux nouvelles sorties du harness succès ;
   - vérifie que chaque job d'assertion effectue un checkout avant d'appeler le script partagé ;
   - conserve les contrôles `if: always()`, les dépendances propres à chaque harness et l'absence de `continue-on-error` sur les assertions bloquantes.

## Validation et correction intermédiaire

- Le premier cycle après le premier câblage, **QIMA CI #1283** (run `43136908901`), a échoué dans les deux jobs d'assertion : ceux-ci invoquaient le nouveau script partagé sans avoir fait checkout du dépôt. Le journal indiquait `No such file or directory`. Les autres contrôles déjà exécutés — Verify, audit, TypeScript, build et jobs PostgreSQL — étaient réussis.
- Correction : ajout d'un checkout explicite dans les deux jobs d'assertion et ajout d'une vérification statique qui impose cette étape.
- **QIMA CI #1284 : SUCCESS**, run `43137010733` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43137010733.
  - Verify : le contrôle de câblage, le test des huit combinaisons invalides, l'isolation QA355 et le garde de version PostgreSQL ont réussi.
  - Journal QA356 : les deux contrats valides ont été acceptés et les huit combinaisons invalides ont été rejetées avec diagnostic `ERROR:`.
  - npm ci, npm audit au seuil high, TypeScript, build Next.js, installation Chromium et Playwright : SUCCESS.
  - Playwright : **347 tests réussis en 10,4 secondes**.
  - PostgreSQL 16 : **29/29 étapes réussies**, intégration CREATE_OFFER, RLS/ACL, migrations jetables, restauration et nettoyage des ressources réussis.
  - PostgreSQL 17.6 : **14/14 étapes réussies**.
  - Harness QA353 : échec de setup volontaire, nettoyage réussi ; assertion indépendante SUCCESS.
  - Harness QA354 : échec de setup volontaire et de nettoyage (code 52) ; assertion indépendante SUCCESS.
  - Les deux jobs de simulation conservent une conclusion individuelle `failure` attendue ; leurs assertions indépendantes réussissent. La conclusion du workflow global est SUCCESS.
- **CodeQL #1234 : SUCCESS**, run `43137010709` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43137010709.
- Le premier CodeQL #1233 sur le commit intermédiaire `e2a11fe` a également réussi.
- Le statut combiné du commit de code final continue d'afficher Vercel FAILURE / `api-deployments-free-per-day`. Ce quota n'est pas un échec du build Next.js, réussi dans CI. Aucun nouveau Preview QA356 n'est revendiqué.

## Commits QA356

- `2d06a7977cec5cbce1362b169f5323defcbb211a` — script partagé d'assertion.
- `a542974a4889b6fecf0d54f3bc2e7d9318a403ea` — huit cas négatifs et deux cas valides.
- `e847efe4050e2fdecbef54b172b783a182275f56` — câblage workflow et sorties.
- `e2a11fe393e209584a4ee1c35697893b6c81aed0` — vérification statique du câblage.
- `c8e8fc928507e11814b6a9c9e2e42741d44b9383` — checkout des deux jobs d'assertion.
- `63892f9239570e0d7dac276467ccce33c74fd4fb` — vérification statique du checkout.

Fichiers techniques uniques : les quatre fichiers listés dans la section Modifications. Les mises à jour documentaires sont séparées et ignorées par le déclencheur CI `paths-ignore: docs/**`.

## État final de la PR

- HEAD de code validé : `63892f9239570e0d7dac276467ccce33c74fd4fb`.
- PR #26 : OPEN, DRAFT, mergeable, non fusionnée.
- Comparaison finale avant documentation : 1 498 commits en avance sur `main`, zéro en retard ; 117 fichiers modifiés.
- Reviews humaines : 0 ; threads : 0.
- Les commits documentaires QA356 sont postérieurs au HEAD de code testé. Ils ne modifient pas le code couvert par CI #1284 et CodeQL #1234.

## Interprétation et périmètre

- Les huit rejets sont des tests synthétiques de contrat d'assertion ; ils ne constituent pas une preuve d'incident ou de vulnérabilité en Production.
- Les jobs PostgreSQL utilisent les environnements jetables habituels.
- Aucune donnée, migration, fonction SQL, schéma, politique RLS, grant, secret ou configuration Supabase Production n'a été modifié.
- Aucun déploiement Production, aucune fusion, aucun force-push et aucune modification des protections de branche.

## Prochaine étape

QA356 est validé par CI #1284 et CodeQL #1234. La prochaine tâche non bloquante peut examiner le comportement des sorties d'assertion en cas de résultat de harness `skipped` ou de job dépendant annulé, sans modifier le job PostgreSQL réel. La décision métier sur le lien tenant/demande et les contrats MKT-1.2 / MKT-1.3 restent distincts et ne doivent pas être inventés.

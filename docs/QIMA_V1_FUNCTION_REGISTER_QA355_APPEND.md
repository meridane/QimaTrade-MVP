# QA355 — isolation des harnesses de restauration parallèles

Date : 12 novembre 2026 (KST)  
Dépôt : `meridane/QimaTrade-MVP` — PR #26  
Branche de travail : `work/qa355-parallel-cleanup-harness-isolation-20261112-0936`

## Objectif

Vérifier que les scénarios QA353 (setup échoué, restauration réussie) et QA354 (setup échoué, restauration échouée) peuvent s'exécuter simultanément sans partager leur état temporaire ni contaminer les sorties GitHub Actions. Le job PostgreSQL 16 réel et son nettoyage bloquant restent inchangés.

## Modifications

1. `tests/ci/test-prepared-transactions-harness-isolation.sh`
   - Lance en parallèle les deux modes du véritable harnais `test-prepared-transactions-always-cleanup-runtime.sh`.
   - Attribue à chaque processus un `RUNNER_TEMP`, un fichier d'état et un `GITHUB_OUTPUT` distincts.
   - Attend le code 0 pour le chemin de restauration réussie et le code 52 pour le chemin d'échec contrôlé.
   - Exige exactement les sorties `cleanup_ran=true`, `cleanup_exit_code=0`, `cleanup_failure_observed=false` pour le succès.
   - Exige exactement `cleanup_exit_code=52` et `cleanup_failure_observed=true` pour l'échec, sans sortie `cleanup_ran`.
   - Vérifie les marqueurs QA353/QA354 et la baseline simulée 0 dans les deux répertoires.
   - Utilise `timeout 30s` par processus et supprime tous les fichiers temporaires à la sortie.

2. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh`
   - Vérifie que les deux jobs de simulation n'ont aucune dépendance `needs` l'un envers l'autre.
   - Vérifie qu'ils utilisent chacun un runner GitHub-hosted `ubuntu-latest`.
   - Vérifie que chaque assertion bloquante dépend uniquement de son propre job de simulation.
   - Vérifie `if: always()`, l'absence de `continue-on-error` dans les assertions et l'absence de références croisées aux sorties de l'autre harness.

3. `.github/workflows/ci.yml`
   - Ajoute à Verify l'étape `Verify parallel prepared-transaction cleanup harness isolation`.
   - Ne modifie pas les étapes du job PostgreSQL réel ni ses règles de restauration.

## Validation GitHub Actions — état au moment de l'inscription

- Le nouveau commit de code QA355 est `b5ed6544831fe1b9ee4507719fb14815691ea2fe`.
- **QIMA CI #1278** : `in_progress`, run `43128751019` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43128751019
  - Le job Verify a terminé avec succès les étapes `Verify workflow concurrency isolation`, `Verify prepared-transaction always-cleanup workflow wiring` et le nouveau test `Verify parallel prepared-transaction cleanup harness isolation`.
  - `npm ci` a également réussi ; le build Next.js était encore en cours à la dernière inspection.
  - Les jobs PostgreSQL 16 et PostgreSQL 17.6 étaient encore en cours.
  - Les deux harnesses ont terminé avec les échecs contrôlés attendus ; les deux jobs d'assertion correspondants ont réussi.
- **CodeQL #1228 : SUCCESS**, run `43128751016` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43128751016
- Les validations de référence sur le HEAD précédent étaient QIMA CI #1277 SUCCESS (run `43119716248`) et CodeQL #1227 SUCCESS (run `43119716356`).
- **Vercel :** le statut du nouveau HEAD de code est resté `pending` lors de la dernière inspection ; le HEAD précédent avait le statut `build-rate-limit`.

## Commits et état de la PR

- `f33799b9417c327f43e40dba206d9683fda0a396` — assertions statiques d'indépendance des jobs.
- `55847b9c3fb3d24b7e6dfdc731f43dc32e4a7904` — test runtime concurrent d'isolation.
- `b5ed6544831fe1b9ee4507719fb14815691ea2fe` — ajout du test au workflow CI.
- PR #26 : OPEN, DRAFT, non fusionnée, mergeable ; 1 485 commits, 114 fichiers modifiés, zéro commit en retard sur `main`, aucune review humaine ni thread au contrôle initial.
- La branche de travail et la branche de la PR étaient identiques après fast-forward avec SHA attendu `903530a397daa0987edebe9fcbac74c54ba234a7`.

## Interprétation et périmètre

- Le test runtime lance deux processus Bash concurrents dans des répertoires temporaires distincts sur un même runner ; le contrôle statique vérifie l'absence de dépendance entre les deux jobs GitHub et l'isolation des références de sorties.
- Les simulations restent synthétiques et utilisent les mocks existants de Docker/PostgreSQL. Elles ne prouvent aucun incident ni vulnérabilité en Production.
- Aucun code applicatif, SQL, migration, donnée, fonction, schéma, politique RLS, grant, secret ou configuration Supabase Production n'a été modifié.
- Aucun déploiement Production, aucune fusion, aucun force-push et aucune modification des protections de branche.

## Résultats définitifs — CI #1278 et CodeQL #1228

- **QIMA CI #1278 : SUCCESS**, run `43128751019` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43128751019.
  - Verify : 21/21 étapes réussies, dont les contrôles de concurrence, le contrat statique QA353/QA354 et le test runtime concurrent QA355.
  - npm ci, npm audit au seuil high, TypeScript, build Next.js et installation Chromium : SUCCESS.
  - Playwright : **347 tests réussis en 12,8 secondes**.
  - PostgreSQL 16 : **29/29 étapes réussies** ; intégration CREATE_OFFER, RLS/ACL, migrations jetables et restauration des transactions préparées réussies ; baseline `max_prepared_transactions=0` et absence de ressources résiduelles confirmées.
  - PostgreSQL 17.6 : **14/14 étapes réussies** ; intégration et compatibilité réussies.
  - Harness QA353 : setup échoué volontairement (47), restauration réussie ; assertion bloquante SUCCESS.
  - Harness QA354 : setup échoué volontairement (47), restauration échouée volontairement (52) ; assertion bloquante SUCCESS.
  - QA355 : le journal confirme l'exécution simultanée des deux chemins avec des `RUNNER_TEMP` et `GITHUB_OUTPUT` distincts ; le chemin succès a émis uniquement les sorties attendues (code 0, `cleanup_ran=true`), le chemin échec uniquement le code 52 et `cleanup_failure_observed=true`.
- **CodeQL #1228 : SUCCESS**, run `43128751016` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43128751016.
- **Vercel : FAILURE / build-rate-limit** (`api-deployments-free-per-day`) pour le HEAD documentaire final. Ce quota ne constitue pas un échec du build Next.js, qui a réussi dans CI. Aucun Preview QA355 n'est revendiqué et aucun déploiement Production n'a eu lieu.

## Prochaine étape

QA355 est validé par CI #1278 et CodeQL #1228. QA356 peut vérifier que l'assertion bloquante échoue proprement si une sortie de harness manque, est vide à tort ou contient une valeur inattendue, sans changer le parcours PostgreSQL réel.

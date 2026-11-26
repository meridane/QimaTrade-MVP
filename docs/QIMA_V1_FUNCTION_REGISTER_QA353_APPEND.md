# QIMA V1 Function Register — QA353 Append

Date : 12 novembre 2026 (KST)  
Dépôt : `meridane/QimaTrade-MVP`  
PR : [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branche de la PR : `fix/create-offer-status-contract`

## État initial vérifié

- PR #26 : OPEN, DRAFT, non fusionnée ; HEAD initial `78aeb1c84916be123221920ba2fa634fb4acb6e9`.
- Comparaison initiale avec `main` : 1 465 commits en avance, zéro en retard ; 109 fichiers modifiés ; aucune review humaine ni thread de review.
- QIMA CI #1271 et CodeQL #1221 : SUCCESS.
- Le registre canonique `docs/QIMA_V1_FUNCTION_REGISTER.md` a été lu via son blob GitHub (1 606 673 caractères). Sa fin contenait QA351 ; les résultats QA352 étaient encore dans l'appendice séparé `QIMA_V1_FUNCTION_REGISTER_QA352_APPEND.md`. Les deux sections QA352 et QA353 sont ajoutées au registre canonique par le commit documentaire qui suit cet appendice.

## Priorité QA353

Vérifier le contrat de workflow, pas seulement les scripts isolés : après un échec de setup qui a déjà publié `restore_required` et `baseline`, le runner GitHub doit exécuter le nettoyage `if: always()`, lui transmettre les sorties du setup en échec, et faire échouer le contrôle bloquant si le nettoyage n'est pas confirmé.

## Modifications

1. `.github/workflows/ci.yml`
   - Ajout dans le job `verify` d'un contrôle statique de la liaison du workflow.
   - Ajout du job isolé `prepared_transactions_always_cleanup_contract`. Son étape de setup échoue volontairement avec le code 47 après avoir écrit `baseline=0`, `restore_required=true` et un état simulé partiel (10) dans `RUNNER_TEMP`.
   - Le job est marqué `continue-on-error: true` au niveau du job uniquement pour que cet échec attendu ne fasse pas échouer le workflow. Son étape de nettoyage conserve `if: always()` et exécute le véritable `restore-prepared-transactions-config.sh` avec des mocks Docker/psql/pg_isready inertes.
   - Les sorties `setup_outcome`, `cleanup_outcome` et `cleanup_ran` sont exposées comme sorties de job.
   - Ajout d'un job séparé et bloquant `prepared_transactions_always_cleanup_assert` (sans `continue-on-error`, avec `if: always()`) qui exige `setup_outcome=failure`, `cleanup_outcome=success` et `cleanup_ran=true`.
   - Le job PostgreSQL 16 réel reste bloquant : ni le job `postgres-integration`, ni son étape de restauration ne portent `continue-on-error`.
2. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh`
   - Vérifie la présence et l'ordre du setup, du test de blocage de nettoyage et de la restauration dans le job PostgreSQL 16.
   - Vérifie `if: always()`, les deux sorties du setup, l'absence de `continue-on-error` sur la restauration réelle, les sorties du job de test et l'assertion dépendante bloquante.
3. `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`
   - Vérifie que le setup simulé est signalé en échec et que ses deux sorties ont été transmises.
   - Exécute le véritable script de restauration avec des mocks locaux inertes : le marqueur initial 10 revient à 0 ; l'ordre docker/pg_isready/psql est contrôlé ; zéro transaction préparée et zéro base résiduelle sont retournées ; aucun socket, Docker réel ou serveur externe n'est appelé.
   - N'écrit `cleanup_ran=true` que si la restauration et toutes les postconditions réussissent.

## Résultats GitHub Actions — HEAD code QA353

- **QIMA CI #1272** : SUCCESS (run `43118123723`), 5 jobs au total :
  - PostgreSQL 16 : SUCCESS. Le contrôle statique de workflow est passé dans le job Verify ; le parcours SQL complet a réussi ; l'étape réelle de restauration a confirmé `max_prepared_transactions=0`, zéro transaction préparée résiduelle et zéro base de migration résiduelle. Le service PostgreSQL 16 et son réseau Docker ont été arrêtés/supprimés dans le post-cleanup.
  - Job runtime QA353 : le step de setup a échoué intentionnellement avec le code 47 ; le step `if: always()` a réussi. Le journal contient `QA353 runtime contract passed`.
  - PostgreSQL 17.6 : SUCCESS ; intégration et compatibilité terminées ; le service et le réseau Docker ont été supprimés dans le post-cleanup.
  - Verify : SUCCESS ; npm ci, npm audit (seuil high), TypeScript, build Next.js, installation Chromium et Playwright ont réussi ; **347 tests Playwright réussis en 8,2 s**.
  - Assertion QA353 : SUCCESS ; les sorties réellement exposées par le job runtime étaient `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=success`, `CLEANUP_RAN=true`.
- **CodeQL #1222** : SUCCESS (run `43118123729`).
- **Vercel** : status SUCCESS ; Preview [HJ39qJRx6biKb71RTPhxBQ2xxe6r](https://vercel.com/bmk1/qimatrade-mvp/HJ39qJRx6biKb71RTPhxBQ2xxe6r). Il s'agit d'un Preview, pas de Production.
- Le job runtime QA353 affiche une conclusion de job `failure` parce que le step de setup est volontairement en échec ; son job-level `continue-on-error: true` empêche cet échec attendu de faire échouer le workflow. Le job d'assertion séparé, bloquant, a réussi. Le run QIMA CI global est SUCCESS.

## Portée et interprétation

- Le test runtime prouve que le runner GitHub a bien exécuté l'étape `if: always()` après un step en échec, transmis les sorties de ce step et exécuté le vrai script de restauration contre des commandes simulées.
- Le parcours nominal de restauration réelle a aussi réussi contre le service PostgreSQL 16 jetable du job principal.
- L'assertion statique confirme que l'étape de restauration du job PostgreSQL principal n'est pas masquée par `continue-on-error` ; une erreur de cette étape reste donc bloquante pour ce job.
- Le scénario de setup en échec et les mocks sont synthétiques. Ils ne démontrent aucun incident, aucune vulnérabilité exploitée ni aucun changement dans Supabase Production.
- Aucun code applicatif, SQL de migration, schéma, donnée, fonction, politique RLS, grant, secret ou configuration Supabase Production n'a été modifié. Aucun déploiement Production, aucune fusion et aucune modification des règles de protection.

## Commits et état PR

Branche de travail : `work/qa353-prepared-transaction-always-cleanup-workflow-contract-20261112-0807`.

- `18233ae0c40e1f9b701c3a4e0992113ed5c458a9` — ajout du test statique de liaison du workflow.
- `ea04a7e1776564d34b97f2f7043766413034c67f` — ajout du harnais runtime GitHub Actions.
- `5bbe246dd2daeed6361cb4b8beac7e8ccb1ec5ea` — commit sans changement de blob (tentative de correction d'échappement, aucun fichier modifié).
- `4519e07f645aad130f314993176c874941ba3d0e` — intégration des deux jobs runtime et de l'étape statique dans le workflow.
- `d28a9097d1f0d7f6c08fbdd8bdb570b3e209eb87` — assertion explicite des sorties dans le test statique.

Comparaison avant intégration : la branche de travail était 5 commits en avance sur la branche PR et zéro en retard ; trois fichiers uniques modifiés. Fast-forward vers `fix/create-offer-status-contract` effectué avec `expected_sha=78aeb1c84916be123221920ba2fa634fb4acb6e9`, sans force-push.

État final vérifié : PR #26 OPEN, DRAFT, non fusionnée, mergeable ; HEAD `d28a9097d1f0d7f6c08fbdd8bdb570b3e209eb87`, 1 470 commits en avance sur `main`, zéro en retard, 111 fichiers modifiés, aucune review humaine ni thread de review.

## Prochaine étape

Le contrat de déclenchement et le passage des sorties sont maintenant testés. La prochaine extension non bloquante peut caractériser un échec synthétique de la commande de restauration dans le job runtime et vérifier que le job d'assertion le signale comme échec, sans transformer ce scénario en statut rouge non maîtrisé ni modifier le comportement Production. Les décisions métier MKT-1.2/MKT-1.3 et le modèle d'autorisation tenant/demande restent séparés et ne doivent pas être inventés.

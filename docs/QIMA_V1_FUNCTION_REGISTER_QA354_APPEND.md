# QimaTrade — QA354 : propagation d'un échec de restauration always()

Date : 12 novembre 2026

## État initial vérifié

- Dépôt : `meridane/QimaTrade-MVP`.
- PR #26 : OPEN, DRAFT, non fusionnée, mergeable ; branche `fix/create-offer-status-contract`.
- HEAD initial : `bc1956461a8d015d3468622ad57a2943d786d912`.
- PR initiale : 1 473 commits, 112 fichiers modifiés, zéro commit en retard sur `main`, aucune review humaine ni thread.
- QIMA CI #1274 : SUCCESS (run `43118643736`).
- CodeQL #1224 : SUCCESS (run `43118643860`).
- Le registre canonique `docs/QIMA_V1_FUNCTION_REGISTER.md` a été lu via le blob GitHub : 1 613 212 caractères, blob `f26ca8258524cf7a7a035150d8e3c4dca634b425`. L'endpoint de contenu direct a retourné un corps vide ; le blob Git a fourni le contenu complet.

## Priorité QA354

Compléter QA353 en vérifiant le chemin inverse : si le véritable script de restauration retourne une erreur, le runner GitHub doit exposer cet échec, ne pas publier de marqueur de succès, et un job d'assertion séparé et bloquant doit détecter le résultat exact.

## Modifications

1. `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`
   - Ajout du mode explicite `SIMULATE_RESTORE_FAILURE=true`.
   - Le faux client Docker simule l'application de RESET en ramenant l'état local à la baseline 0, écrit l'événement, puis retourne le code 52 pour représenter une réponse ambiguë.
   - Le harnais exécute le véritable `restore-prepared-transactions-config.sh` avec des commandes Docker/psql/pg_isready/sleep inertes.
   - Le mode d'échec exige le code 52, la séquence limitée à `docker-ps`, `pg-isready`, `docker-exec-reset`, l'état simulé 0, le diagnostic exact, l'absence de redémarrage et de vérification postérieure, l'absence de message de succès et l'absence de fuite des identifiants.
   - En cas de correspondance exacte, le harnais publie `cleanup_exit_code=52` et `cleanup_failure_observed=true`, n'écrit pas `cleanup_ran=true`, puis retourne 52 afin que l'issue du step reste `failure`. Le mode nominal continue à publier `cleanup_ran=true` uniquement après toutes les postconditions et écrit `cleanup_exit_code=0`.

2. `.github/workflows/ci.yml`
   - Ajout du job isolé `prepared_transactions_always_cleanup_failure_contract`. Son setup simulé échoue avec le code 47 après publication de la baseline et du marqueur de restauration ; son step `if: always()` exécute le vrai script de restauration en mode d'échec attendu.
   - Le job de simulation porte `continue-on-error: true` au niveau du job uniquement, afin d'isoler l'échec attendu. Le step de nettoyage lui-même n'a pas `continue-on-error`.
   - Les sorties de job exposent `setup_outcome`, `cleanup_outcome`, `cleanup_ran`, `cleanup_exit_code` et `cleanup_failure_observed`.
   - Ajout du job `prepared_transactions_always_cleanup_failure_assert`, sans `continue-on-error`, avec `if: always()`. Il exige setup en échec, cleanup en échec, code 52, marqueur d'échec observé et absence de `cleanup_ran`.
   - Le job PostgreSQL 16 réel et son step de restauration restent bloquants ; aucune tolérance n'a été ajoutée à ce parcours réel.

3. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh`
   - Vérifie le câblage du job d'échec, les sorties, le transfert des valeurs, `if: always()`, l'absence de tolérance sur le step de nettoyage et l'absence de tolérance sur le job d'assertion.
   - Vérifie que l'assertion dépendante exige le code 52 et l'absence du marqueur de succès.

## Corrections intermédiaires

- Le premier ajout YAML a échappé les séquences de fin de ligne deux fois dans les commandes `printf` du setup simulé.
- Correction dans le commit `fb9168cf3e4d9b63643fa5b44476082b967ab07b` : les deux commandes écrivent maintenant les sorties GitHub et l'état simulé sur des lignes séparées, comme dans le job QA353 existant.
- Le contrôle statique du workflow a réussi dans le job Verify de CI #1275.

## Validation GitHub Actions

- **QIMA CI #1275 : SUCCESS**, run `43119220610` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43119220610
  - Job Verify : 20/20 étapes réussies. `npm ci`, audit npm au seuil high, TypeScript, build Next.js, installation Chromium et Playwright réussis.
  - Playwright : **347 tests réussis en 12,3 secondes**.
  - PostgreSQL 16 : 29/29 étapes réussies. Intégration CREATE_OFFER, concurrence, RLS/ACL, migrations jetables, nettoyages de sessions et tests de transactions préparées réussis. La restauration réelle a ramené `max_prepared_transactions` à 0 et vérifié zéro transaction préparée et zéro base de migration résiduelle ; le conteneur et le réseau ont été supprimés au post-cleanup.
  - PostgreSQL 17.6 : 14/14 étapes réussies ; la version serveur a été vérifiée et les tests d'intégration/compatibilité ont réussi ; le conteneur et le réseau ont été supprimés.
  - Harness QA353 : le setup a échoué volontairement avec le code 47 ; le step `if: always()` a réussi ; le job d'assertion séparé a réussi avec `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=success`, `CLEANUP_RAN=true`.
  - Harness QA354 : le setup a échoué volontairement avec le code 47 ; le step de restauration a échoué volontairement avec le code 52 après le RESET simulé ; le journal contient `QA354 runtime contract passed`. Le job d'assertion séparé a réussi et a reçu exactement `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=failure`, `CLEANUP_EXIT_CODE=52`, `CLEANUP_FAILURE_OBSERVED=true`, `CLEANUP_RAN=` (vide).
  - Les deux jobs de harness ont une conclusion de job `failure` attendue ; les échecs sont explicitement isolés au niveau du job de simulation. Les deux jobs d'assertion restent bloquants et ont réussi. Le workflow global est SUCCESS.
- **CodeQL #1225 : SUCCESS**, run `43119220608` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43119220608
- CI #1274 et CodeQL #1224, contrôles initiaux du HEAD précédent, étaient également SUCCESS.

## Statut Vercel

- Le statut combiné du HEAD de code QA354 est FAILURE avec `build-rate-limit` / `api-deployments-free-per-day`.
- Aucun nouveau Preview n'est revendiqué pour QA354. Le build Next.js de GitHub Actions a réussi.
- Aucun déploiement Production.

## Commits et fichiers

Branche de travail : `work/qa354-cleanup-failure-outcome-20261112-0818`.

Commits de code :
- `96235c11ade0d2143dc01930c1b9e34783511f47` — mode de test du résultat de restauration ambigu.
- `15edf32d151cb535933f157e5c96de21fee0927a` — job de contrat d'échec et assertion bloquante.
- `fb9168cf3e4d9b63643fa5b44476082b967ab07b` — correction des échappements de fin de ligne dans le setup simulé.
- `45974f91cc9e6523d107b457097d8ad9d1c1080b` — vérification statique du job d'échec.
- `e3ff981ce9c8a7c15d6420b1317fc6d7d73e4179` — vérification statique du transfert du marqueur de succès.

Fichiers de code/workflow uniques :
- `.github/workflows/ci.yml`
- `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`
- `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh`

## État et interprétation

- Le HEAD de code QA354 `e3ff981ce9c8a7c15d6420b1317fc6d7d73e4179` a été intégré à `fix/create-offer-status-contract` par fast-forward avec `expected_sha=bc1956461a8d015d3468622ad57a2943d786d912`, sans force-push.
- Après intégration du code, la PR était OPEN, DRAFT, mergeable, non fusionnée ; 1 478 commits, 112 fichiers modifiés, zéro commit en retard sur `main`, aucune review humaine ni thread.
- Les scénarios de réponse ambiguë et les mocks sont synthétiques. Ils vérifient le contrat de propagation d'échec du workflow et des scripts ; ils ne démontrent aucun incident ni vulnérabilité en Production.
- Aucun code applicatif SQL, aucune migration, donnée, fonction, schéma, politique RLS, grant, secret ou configuration Supabase Production n'a été modifié.
- Aucun déploiement Production, aucune fusion, aucun force-push et aucune modification des protections de branche.

## Prochaine étape

QA355 peut vérifier que les deux jobs d'assertion restent toujours exécutés même si les deux harnesses échouent simultanément, et que les sorties ne se contaminent pas entre jobs. Cette vérification doit rester isolée et ne pas modifier le parcours PostgreSQL réel.


## Statut final après publication documentaire

- Les deux commits documentaires QA354 ont été intégrés par fast-forward à la PR après le HEAD de code `e3ff981ce9c8a7c15d6420b1317fc6d7d73e4179`.
- HEAD documentaire final : `79036936e83cd5cfed242794842a536f178984fe`.
- PR #26 : OPEN, DRAFT, non fusionnée, mergeable ; 1 480 commits, 113 fichiers modifiés, zéro commit en retard sur `main`, aucune review humaine ni thread.
- Comparaison `main...79036936` : 1 480 commits en avance, zéro en retard.
- Le HEAD documentaire ne déclenche pas de nouvelle QIMA CI/CodeQL car les seuls changements après le HEAD de code QA354 sont sous `docs/**`, ignorés par le workflow. La validation du code reste QIMA CI #1275 SUCCESS et CodeQL #1225 SUCCESS sur le HEAD de code `e3ff981`.
- Le statut combiné Vercel du HEAD documentaire reste FAILURE avec `build-rate-limit` / `api-deployments-free-per-day`. Aucun Preview QA354 revendiqué et aucun déploiement Production.

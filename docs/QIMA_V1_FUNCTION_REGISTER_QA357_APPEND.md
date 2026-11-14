# QA357 — gestion explicite des résultats skipped et cancelled

Date : 12 novembre 2026 (KST)  
Dépôt : `meridane/QimaTrade-MVP` — PR #26  
Branche de travail : `work/qa357-skipped-cancelled-cleanup-outcomes-20261112-1150`

## État initial vérifié

- PR #26 : OPEN, DRAFT, mergeable, non fusionnée ; HEAD initial `e71d85492dd485786ed8e3a070390dd2de2de1ad`.
- Comparaison initiale avec `main` : 1 500 commits en avance, zéro en retard ; 118 fichiers modifiés.
- Reviews humaines : 0 ; threads de review : 0.
- CI #1286 : SUCCESS ; CodeQL #1236 : SUCCESS.
- Le registre canonique a été lu via son blob Git : le wrapper `fetch_file` retournait un contenu vide pour ce gros fichier, tandis que le blob SHA `043acafaf704e5f1966efada094ec3c998163172` a fourni les 1 631 465 caractères complets.
- Le code QA356 était validé ; sa prochaine tâche recommandée était de caractériser les résultats de harness `skipped` et `cancelled`.

## Objectif

Vérifier qu'un job GitHub Actions réellement `skipped` ne peut pas être interprété comme un nettoyage réussi, et que le contrat d'assertion rejette également un résultat `cancelled`. Ne pas annuler un workflow complet pour fabriquer un résultat de test : cette annulation interromprait les autres contrôles de la même exécution.

## Modifications

1. `tests/ci/assert-prepared-transactions-cleanup-contract.sh` :
   - ajoute le mode `skipped`, qui exige `HARNESS_RESULT=skipped` et l'absence de toutes les sorties setup/nettoyage ;
   - ajoute le mode `cancelled`, qui refuse explicitement tout harness annulé, même si des sorties de succès ou d'échec sont fournies ;
   - conserve sans changement les contrats QA353 et QA354.

2. `tests/ci/test-prepared-transactions-cleanup-assertions.sh` :
   - accepte un résultat `skipped` uniquement si toutes les sorties sont vides ;
   - rejette six nouvelles combinaisons : résultat skipped absent, outcome de nettoyage publié par un job skipped, marqueur de succès publié par un job skipped, résultat cancelled absent, résultat cancelled accompagné de sorties de succès fabriquées, et résultat cancelled accompagné de sorties d'échec fabriquées ;
   - conserve les huit cas négatifs QA356. Le test vérifie donc 14 rejets négatifs au total, ainsi que les trois contrats valides success, failure et skipped.

3. `.github/workflows/ci.yml` :
   - ajoute `prepared_transactions_cleanup_skipped_contract`, volontairement conditionné par `if: ${{ false }}` ;
   - ses sorties référencent un step qui ne doit jamais s'exécuter ; si le job était lancé, ce step publierait délibérément des valeurs de succès, ce qui ferait échouer le contrat skipped ;
   - ajoute `prepared_transactions_cleanup_skipped_assert`, dépendant du job skipped, avec `if: always()`, checkout explicite et transfert de `needs.<job>.result` plus des cinq sorties ;
   - renomme l'étape Verify pour inclure les cas malformed, skipped et cancelled ;
   - ne modifie pas le job PostgreSQL 16 réel ni sa restauration bloquante.

4. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh` :
   - vérifie la condition qui force le job harness à skipped ;
   - vérifie les cinq sorties et l'assertion dépendante ;
   - impose `if: always()` et l'absence de `continue-on-error` sur l'assertion bloquante ;
   - vérifie la présence des cas cancelled synthétiques.

## Validation GitHub Actions et CodeQL

- Commit de code QA357 : `5ea274d558ec4fa6a60ea163ac07ec327e7bb2a7`.
- Correction de fixture : `a1d752c3b21c811f1b468db75f37e1c0349e054d`. Le format du `printf` de la step dormante a été corrigé pour que, si le garde `if: false` était retiré par erreur, elle publie réellement des lignes de sorties distinctes et fasse échouer l'assertion skipped. La step reste non exécutée dans le workflow validé.
- **QIMA CI #1287 : SUCCESS**, run `43144671044` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43144671044.
  - Verify : contrôle de câblage, tests de sorties malformed/skipped/cancelled, isolation QA355 et garde de version PostgreSQL : PASS.
  - Le test d'assertion confirme les huit cas négatifs QA356 et les six nouveaux cas QA357 rejetés avec diagnostic `ERROR:`.
  - Le job GitHub Actions `Prepared-transaction cleanup skipped-result contract` a réellement terminé avec la conclusion `skipped`.
  - Son job dépendant `Assert skipped cleanup harness cannot be treated as success`, avec `if: always()`, a terminé avec la conclusion `success`. Le journal contient : `QA357 passed: skipped harness exposed no cleanup outputs and was not treated as success.`
  - Harness QA353 : échec de setup volontaire ; nettoyage réussi ; assertion indépendante SUCCESS.
  - Harness QA354 : échec de setup et de nettoyage volontaire (code 52) ; assertion indépendante SUCCESS.
  - PostgreSQL 16 : job SUCCESS, y compris le parcours nominal de configuration/restauration et la suppression des ressources jetables.
  - PostgreSQL 17.6 : job SUCCESS, tests d'intégration et ACL réussis.
  - Verify : npm ci, npm audit au seuil high, TypeScript, build Next.js, Chromium : SUCCESS ; **347 tests Playwright réussis en 12,8 secondes**.
  - Les deux jobs harness QA353/QA354 conservent leur conclusion individuelle `failure` attendue ; le job skipped conserve `skipped`. Les assertions indépendantes réussissent et la conclusion globale CI est SUCCESS.
- **CodeQL #1237 : SUCCESS**, run `43144671047` : https://github.com/meridane/QimaTrade-MVP/actions/runs/43144671047.
- Statut Vercel du HEAD de code QA357 `a1d752c` : SUCCESS. Le build Next.js a également réussi dans CI.
- Aucun résultat réel `cancelled` n'a été provoqué : annuler le workflow aurait interrompu tous les contrôles de l'exécution. Le rejet du résultat `cancelled` est couvert par les six tests d'assertion synthétiques ; il n'est pas présenté comme une preuve de comportement runtime d'un job réellement annulé.

## Commits QA357

- `5ea274d558ec4fa6a60ea163ac07ec327e7bb2a7` — ajout des modes skipped/cancelled, des tests négatifs et du job skipped.
- `a1d752c3b21c811f1b468db75f37e1c0349e054d` — correction de la fixture de sorties du step qui ne doit pas s'exécuter.

Fichiers techniques uniques :
- `.github/workflows/ci.yml`
- `tests/ci/assert-prepared-transactions-cleanup-contract.sh`
- `tests/ci/test-prepared-transactions-cleanup-assertions.sh`
- `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh`

## État de la PR après validation du code

- HEAD de code QA357 validé : `a1d752c3b21c811f1b468db75f37e1c0349e054d`.
- PR #26 : OPEN, DRAFT, mergeable, non fusionnée.
- Comparaison après publication du code : 1 502 commits en avance sur `main`, zéro en retard ; 118 fichiers modifiés.
- Reviews humaines : 0 ; threads : 0.
- CI #1287 et CodeQL #1237 : SUCCESS.
- Vercel : SUCCESS pour le HEAD de code QA357.
- Les modifications documentaires qui suivent sont ignorées par le déclencheur CI `paths-ignore: docs/**`.

## Interprétation et limites

- Le résultat `skipped` a été observé sur un vrai job GitHub Actions et son assertion dépendante a réellement réussi.
- Le résultat `cancelled` est rejeté par les tests du script d'assertion, mais aucune annulation runtime n'a été déclenchée.
- Les scénarios skipped/cancelled sont des tests de contrat de workflow ; ils ne prouvent pas une vulnérabilité ou un incident Production.
- Tous les tests PostgreSQL utilisent les services jetables de CI.
- Aucune donnée, migration, fonction SQL, schéma, politique RLS, grant, secret ou configuration Supabase Production n'a été modifié.
- Aucun déploiement Production, aucune fusion, aucun force-push et aucune modification des protections de branche.

## Prochaine étape

QA357 est validé par CI #1287 et CodeQL #1237. La couverture runtime du résultat `skipped` est confirmée. Le résultat `cancelled` reste couvert synthétiquement ; ne pas annuler une exécution complète uniquement pour le simuler. La prochaine tâche utile peut examiner les conditions de dépendance et de propagation des sorties lorsque plusieurs jobs en amont sont skipped, sans toucher au job PostgreSQL réel. Les décisions métier tenant/demande et les contrats MKT-1.2 / MKT-1.3 restent distincts et ne doivent pas être inventés.

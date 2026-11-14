# QIMA V1 Function Register — QA396

## QA396 — changed-input idempotency replay preserves original state

**Status:** PENDING full CI validation  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa396-input-mismatch-replay-20261114-0939`  
**Base commit:** `a00c867c1d65610f95ab8ac6c50028977e9181d8`

## Scope

- Exercise the existing `execute_create_offer_v1` contract with one completed tenant-scoped idempotency key.
- The first call uses a valid JSON input `{"case":"qa396_original_input"}`.
- The replay uses the same tenant/key and identical effective parameters except for `p_input`, which becomes `{"case":"qa396_changed_input"}`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error.
- Require unchanged row counts in `idempotency_keys`, `action_executions`, `offers` and `action_events`.
- Verify the original request hash/result, completed execution input, offer, and success event remain unchanged.
- Static coverage pins the existing `'input', p_input` request-hash field and the mismatch rejection before new action-execution persistence.
- Integrate the static check in Verify and reuse the existing disposable PostgreSQL 16 and 17.6 runtime jobs.

## Validation state

- Source-level review confirms that `p_input` is already part of the existing request hash. No migration or application code is changed.
- The runtime scenario is appended to `tests/sql/create-offer-runtime.sql`; the static contract is `tests/sql/test-create-offer-input-mismatch-replay-contract.sh`.
- Full CI validation is pending. Do not mark QA396 CLOSED until Verify, the full PostgreSQL 16 job, and the full PostgreSQL 17.6 job succeed and both runtime logs contain the QA396 marker.
- The canonical register could not be read through the GitHub file-content endpoint in this run: it returned the known blob SHA but an empty content payload, including for requested line ranges. The existing canonical file was deliberately left untouched rather than overwritten from an incomplete reconstruction. This append records QA396; canonical-register synchronization remains blocked on a readable full-file or chunked retrieval path.

## Safety and decision boundaries

- No application code or migration is modified.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- The test uses disposable PostgreSQL CI fixtures only. Synthetic regression evidence is not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics, and MKT-1.3 numeric canonicalization remain subject to business approval.


## CI #1412 — runtime failure and corrective change (14 novembre 2026)

- QIMA CI [#1412](https://github.com/meridane/QimaTrade-MVP/actions/runs/43535965618) a exécuté avec succès le contrôle statique QA396 dans Verify. npm audit et TypeScript étaient également réussis au dernier contrôle; le build et Playwright n'avaient pas encore terminé à ce point.
- Les deux étapes runtime CREATE_OFFER ont échoué sur PostgreSQL 16 et PostgreSQL 17.6 au démarrage du bloc `DO $qa396_input_mismatch_replay$`. Le message PostgreSQL exact était `duplicate declaration at or near "v_replay_input"`.
- La revue du SQL confirme que la transformation du scénario QA395 avait conservé une première déclaration à la place de l'ancien `v_replay_offer_name`, puis inséré une seconde déclaration après `v_input`. Il s'agit d'un défaut du nouveau harness QA396, pas d'un échec de la fonction applicative ou de la migration.
- Correction : suppression de la première déclaration en doublon; le bloc conserve désormais une seule déclaration `v_replay_input` après `v_input`. Le contrat statique exige explicitement exactement une déclaration afin de prévenir une régression identique.
- Une nouvelle CI sur le commit corrigé est requise. CI #1412 n'est pas acceptée comme validation runtime QA396.
- Aucun code applicatif, migration, donnée Supabase Production, secret, configuration PostgreSQL persistante, règle de protection, fusion ou déploiement Production n'a été modifié. Aucun résultat synthétique n'est interprété comme preuve d'une vulnérabilité Production.

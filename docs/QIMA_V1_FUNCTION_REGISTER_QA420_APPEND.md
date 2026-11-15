# QIMA V1 Function Register — QA420

## QA420 — audit documentaire de la couverture du request hash CREATE_OFFER

**Statut : DOCUMENTATION AUDIT COMPLETE — aucune nouvelle régression runtime ajoutée ; la couverture existante des 16 champs métier est déjà cartographiée et le contrat statique QA382 la vérifie.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de référence du code audité :** [`ab4b8842cfe012704f4f231401c282a59d3451db`](https://github.com/meridane/QimaTrade-MVP/commit/ab4b8842cfe012704f4f231401c282a59d3451db).

## Constat vérifié
- La migration `20261027090000_fix_create_offer_action_status_contract.sql` construit un hash JSONB avec exactement 16 propriétés métier : `input`, `name`, `demandId`, `productMasterId`, `providerActorId`, `quantity`, `price`, `currency`, `conditions`, `market`, `geography`, `attributes`, `documentationStatus`, `lifecycle`, `offerType` et `pricingModel`.
- Le contrat statique existant `tests/sql/test-create-offer-request-hash-contract.sh` exige chaque mapping exactement une fois, vérifie que `p_tenant_id` et `p_idempotency_key` restent hors du payload hash et confirme que les 16 paramètres restent représentés dans le runtime.
- Le même contrôle vérifie aussi la portée tenant/key dans le runtime via le cas `fixture-same-key-two-tenants`. Le tenant et la clé sont donc documentés comme portée du verrou/lookup, pas comme propriétés du hash métier.

## Index de couverture existante
| Paramètre | Couverture runtime / contrat existant |
|---|---|
| `p_input` | `test-create-offer-input-mismatch-replay-contract.sh` ; QA82/QA83 |
| `p_name` | `test-create-offer-name-mismatch-replay-contract.sh` ; QA83 |
| `p_demand_id` | `create-offer-demand-mismatch-replay.sql` ; QA418 |
| `p_product_master_id` | `create-offer-product-master-mismatch-replay.sql` ; QA409 |
| `p_provider_actor_id` | QA84 (ordre du garde avant hash/status) ; QA419 (replay avec acteur fourni différent) |
| `p_quantity` | `test-create-offer-quantity-mismatch-replay-contract.sh` ; validations numériques dédiées |
| `p_price` | `test-create-offer-zero-price-mismatch-replay-contract.sh` ; QA112 pour l'échelle numérique |
| `p_currency` | `test-create-offer-currency-mismatch-replay-contract.sh` |
| `p_conditions` | `test-create-offer-conditions-mismatch-replay-contract.sh` et QA411 |
| `p_market` | `test-create-offer-market-mismatch-replay-contract.sh` et QA412 |
| `p_geography` | `test-create-offer-geography-mismatch-replay-contract.sh` et QA413 |
| `p_attributes` | contrôles key-order, array-order, SQL NULL/objet vide et SQL NULL/JSONB literal null ; QA410 |
| `p_documentation_status` | `test-create-offer-documentation-status-mismatch-replay-contract.sh` et QA414 |
| `p_lifecycle` | `test-create-offer-lifecycle-mismatch-replay-contract.sh` et QA415 |
| `p_offer_type` | `test-create-offer-offer-type-mismatch-replay-contract.sh` et QA416 |
| `p_pricing_model` | `test-create-offer-pricing-model-mismatch-replay-contract.sh` et QA417 |

## Décision de portée
- Aucun nouveau test de changement de prix, d'acteur ou de paramètre hashé n'est ajouté dans QA420 : les scénarios existants et le contrat statique couvrent déjà ces champs. Ajouter une variante redondante augmenterait le temps CI sans combler de lacune démontrée.
- Le lien métier entre `demandId` et `tenantId` reste une décision distincte : le modèle d'ownership/autorisation de la demande n'est pas approuvé dans les éléments consultés. Aucun test ne doit inventer cette règle ni qualifier une vulnérabilité à partir d'un fixture synthétique.
- QA420 est un audit documentaire, pas une nouvelle preuve runtime ni un constat de sécurité.

## Validation et limites
- QIMA CI [#1471](https://github.com/meridane/QimaTrade-MVP/actions/runs/43654514471) a validé le code/workflow de référence `ab4b8842` : Verify, PostgreSQL 16 et PostgreSQL 17.6 SUCCESS ; npm audit high, TypeScript, build Next.js et Playwright 347/347 SUCCESS.
- Le step `Verify CREATE_OFFER request-hash field coverage` a réussi dans le job Verify. Les deux runners PostgreSQL complets ont également réussi.
- Cette mise à jour QA420 ne modifie que la documentation. Le workflow QIMA CI ignore explicitement `docs/**` pour les événements push et pull_request ; aucun nouveau run applicatif n'est donc attendu pour ce commit documentaire. La preuve CI #1471 reste applicable au code inchangé.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié. Aucun déploiement Production, merge, force-push ou changement de règle de protection.

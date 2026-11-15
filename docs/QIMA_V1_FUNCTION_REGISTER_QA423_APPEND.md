# QIMA V1 Function Register — QA423

## QA423 — all supported currency codes are accepted, persisted and exactly replayed

**Statut : IMPLEMENTED — validation CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Commit de base :** `ccacb9890546c243916f11567a07ca1356848d66`.  
**Branche de travail :** `work/qa423-supported-currency-acceptance-20261115-1342`.

## Portée
- Caractériser positivement la liste exacte déclarée par la migration : `USD`, `EUR`, `KRW`, `MAD` et `CNY`.
- La relecture de `tests/sql/create-offer-runtime.sql` montre que les appels nommés existants n'utilisent explicitement que `USD` et `EUR` ; QA423 ajoute une couverture d'acceptation pour les trois codes restants tout en gardant une matrice complète des cinq codes.
- Chaque devise reçoit une clé d'idempotence et un nom d'offre distincts, avec les mêmes références synthétiques valides de tenant, acteur, demande et produit.
- Chaque premier appel doit retourner `status = succeeded`, persister le code exact dans `offers.currency`, et produire une seule ligne cohérente dans `idempotency_keys`, `action_executions`, `offers` et `action_events`.
- Un second appel identique avec la même clé doit retourner exactement le JSON initial, conserver le request hash et ne créer aucune ligne supplémentaire.
- Le contrôle statique vérifie la whitelist exacte, les cinq cas, les deux appels RPC par cas, les assertions de persistance/replay et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.

## Validation et limites
- Le SQL `tests/sql/create-offer-supported-currency-acceptance.sql` utilise uniquement les fixtures de CI jetables, `execute_create_offer_v1` et des assertions SELECT ; il ne contient aucun DML direct ni changement de schéma.
- Le contrôle statique est `tests/sql/test-create-offer-supported-currency-acceptance-contract.sh`.
- Le workflow exécute le contrôle statique dans Verify et le SQL sur PostgreSQL 16 et PostgreSQL 17.6.
- Aucun marqueur QA423 PASS n'est revendiqué avant les journaux runtime finaux des deux versions PostgreSQL.
- Le scénario synthétique caractérise le contrat existant et ne constitue pas un constat de vulnérabilité ni une décision métier sur les devises.
- Aucune donnée ni migration Supabase Production, aucun secret, grant, policy RLS ou configuration persistante n'est modifié. Aucun déploiement Production, merge, force-push ou changement de règle de protection.

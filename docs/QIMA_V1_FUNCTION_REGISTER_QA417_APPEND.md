# QIMA V1 Function Register — QA417

## QA417 — omission de p_pricing_model et replay avec NULL explicite

**Statut : IMPLEMENTED — validation QIMA CI en attente sur le nouveau HEAD.**  
**Target :** PR #26, branche `fix/create-offer-status-contract`.  
**Branche de travail :** `work/qa417-pricing-model-default-replay-20261115-0641`.  
**Commit de base :** `4f92de83c9eaf2f8d10a275d295a1f697c82d77a`.

## Portée

- Caractériser la signature existante `p_pricing_model text DEFAULT NULL::text`, sans modifier la migration.
- Confirmer que le mapping existant `'pricingModel', p_pricing_model` est couvert par le hash de requête et que la valeur est transmise à `create_offer_v1`.
- Le premier appel nommé dans `tests/sql/create-offer-runtime.sql` omet réellement `p_pricing_model`.
- Le replay utilise le même tenant et la même clé d'idempotence et fournit explicitement `p_pricing_model => NULL`.
- Tous les autres paramètres effectifs restent identiques, notamment `p_offer_type => 'fixture-offer-type-stable'`, `p_lifecycle => NULL`, `p_documentation_status => NULL`, `p_market => 'fixture-market-stable'` et `p_attributes => '{}'::jsonb`.
- Exiger le résultat JSON exact, le hash inchangé, l'exécution `COMPLETED`, `offers.pricing_model IS NULL`, l'événement `ACTION_SUCCEEDED` et l'absence de doublons dans les quatre tables de persistance.
- Le contrôle statique vérifie le défaut de signature, le mapping du hash, le forwarding, l'omission réelle du premier appel, le NULL explicite du replay, l'identité des autres paramètres, les assertions read-only et le câblage Verify/PostgreSQL 16/PostgreSQL 17.6.
- Le runtime est intégré à `create-offer-runtime.sql`, déjà exécuté par les deux runners PostgreSQL existants.

## Correction de workflow découverte pendant la relecture

- Le workflow contenait une deuxième clé YAML `run:` sous le step nommé pour le replay modifié de `p_offer_type`. Cette clé était destinée au contrôle statique QA416 mais n'avait pas son propre élément `- name`.
- Le workflow est corrigé : QA416 et QA417 ont maintenant chacun un step nommé distinct et une commande `run` unique.
- Le contrôle statique QA416 a été renforcé pour exiger son propre nom de step ; le contrôle QA417 vérifie aussi la présence des deux steps. Cette correction évite qu'un futur doublon de clé YAML masque un test.
- Aucun autre comportement de workflow n'est modifié.

## Validation

- Prérequis : QA415 est CLOSED sur QIMA CI [#1449](https://github.com/meridane/QimaTrade-MVP/actions/runs/43634745260), avec Verify, PostgreSQL 16, PostgreSQL 17.6, les deux marqueurs runtime et Playwright 347/347 réussis.
- QA416 reste IMPLEMENTED / validation en attente sur le HEAD précédent. Le nouveau run doit exécuter QA416 et QA417 ensemble après correction du câblage.
- Au début de cette exécution, le HEAD `4f92de83c9eaf2f8d10a275d295a1f697c82d77a` n'avait aucun run QIMA CI associé ; CodeQL [#1400](https://github.com/meridane/QimaTrade-MVP/actions/runs/43637027564) était SUCCESS et le statut combiné Vercel indiquait `build-rate-limit`.
- Aucun résultat runtime QA417 n'est revendiqué avant les journaux complets PostgreSQL 16 et 17.6.

## Sécurité et limites

- Le test utilise uniquement les fixtures PostgreSQL temporaires de CI et des valeurs synthétiques.
- La valeur NULL caractérise le défaut SQL ; elle ne définit ni n'approuve une taxonomie métier de pricing model.
- Aucune donnée ou migration Supabase Production, aucun secret, grant, politique RLS ou paramètre PostgreSQL persistant n'est modifié.
- Aucun déploiement Production, merge, force-push ou changement de règle de protection.
- Ce test caractérise un contrat existant ; il ne prouve aucune vulnérabilité Production.
- Le modèle d'autorisation demand/tenant et les décisions métier MKT-1.1, MKT-1.2 et MKT-1.3 restent soumis à approbation explicite.

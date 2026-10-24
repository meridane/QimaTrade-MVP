# QimaTrade — rapprochement des audits au 23 octobre 2026

Date : 23 octobre 2026
Branche : `chore/qima-free-autopilot-review`
Statut : **NO-GO pour la V1 multi-tenant — validations actuelles insuffisantes**
Aucune écriture Supabase, migration, fusion ou mise en production effectuée pendant ce rapprochement.

## 1. Source d'audit Notion la plus récente consultée

[Audit global fonctionnel QIMA — 23 octobre 2026](https://app.notion.com/p/402595ef636081db98d0ec388b0f4743), dernière extraction visible le 23 octobre 2026 à 04:10 UTC.

Cet audit déclare explicitement qu'il n'a exécuté ni code, ni migration, ni RPC, ni pipeline CI, ni test E2E. Il distingue les éléments documentés, déclarés implémentés, testés selon une source et vérifiés indépendamment. Il juge la preuve d'exécution très faible et le Security Gate `NOT PASS / In Review`.

Il rapporte notamment :
- écart de provenance entre 157 migrations déclarées sur Supabase et 15 fichiers SQL dans le dépôt ;
- aucune preuve actuelle suffisamment archivée de tests RLS/cross-tenant sur un schéma canonique ou représentatif ;
- risque potentiel de confiance accordée par le serveur à des valeurs comme `targetNodeId` ou `ruleId` envoyées par le client pour `dt_submit_answer` ;
- flux de création d'offre possiblement direct vers `offers`, au lieu d'un pipeline commun de validation/commande idempotente/contrôle d'organisation/événement ;
- atomicité, idempotence, concurrence et provenance append-only pas suffisamment démontrées.

Ces éléments sont des constats de l'audit Notion, pas des bugs confirmés indépendamment par une exécution dans ce travail. Ils doivent être vérifiés dans le code courant et dans un environnement isolé.

## 2. Contrôles Git examinés en lecture seule

- `package.json` définit `typecheck`, `build`, `test:e2e` et `test:local-env`.
- `playwright.config.ts` cible `./tests/e2e` et démarre le serveur Next.js avec des valeurs Supabase factices.
- `.github/workflows/ci.yml` exécute installation, audit npm (non bloquant dans le workflow), TypeScript, build, tests Playwright et fixture PostgreSQL isolée.
- `scripts/test-qima-security-fixture.sh` utilise un PostgreSQL jetable et des fixtures synthétiques.
- `docs/testing/qima-local-postgres-harness.md` indique explicitement que le harnais n'est pas l'émulateur complet Supabase, n'utilise pas la base distante et ne teste pas les vrais RPC Supabase/Decision Tree.

### Limite de la vérification actuelle

Le présent rapprochement n'a pas exécuté ces commandes localement et n'a pas rejoué les workflows GitHub. Les résultats CI historiques rapportés dans les autres documents restent des preuves liées aux SHA et runs qui y sont cités ; ils ne doivent pas être généralisés au SHA actuel ni au schéma réel. L'audit Notion du 23 octobre, de son côté, n'a pas exécuté de tests. Ces deux sources ont des portées différentes et ne doivent pas être fusionnées en une seule affirmation.

## 3. Résultats de la revue documentaire MVP

- TEST 14 « Controlled Conversation » a été retrouvé dans le registre Notion. Son statut historique est « Validated » au 25 août, mais sa page est vide côté contenu ; seule la propriété Regression rule précise qu'il faut recharger la conversation et envoyer au moins trois messages liés aux mêmes IDs Demand et Offer.
- TEST 20 « Quantity extrêmement grande » rapporte qu'une quantité extrême a été acceptée et que la demande a été sauvegardée. La limite métier maximale est explicitement non définie : c'est une décision ouverte, pas une limite à inventer.
- TEST 21 rapporte que 10.5 et 0.000001 ont été acceptés. Ce résultat historique ne dit pas si ce seuil est correct pour chaque unité/produit.
- TEST 31–33 contiennent des décisions de conception : offre indépendante ou liée à une demande ; réservation distincte de l'offre ; offre représentant une capacité de fourniture et pas nécessairement un stock. Ils ne constituent pas des tests runtime.
- L'Audit 07 Notion du 25 août signale également des lacunes historiques sur événements automatiques, permissions, conflits multi-utilisateurs, liaison Demand/Offer→Order, transitions négatives Shipment et droits de changement de statut.

Le détail et les liens de ces fiches sont dans [l'inventaire initial du catalogue de tests MVP](./2026-10-23-mvp-test-catalog-initial.md).

## 4. Ordre d'exécution obligatoire

1. **Reproductibilité du schéma** : identifier le SHA de code et la source canonique de toutes les migrations ; produire une table de correspondance dépôt ↔ historique Supabase. Pas de reset, push ou migration distante pour combler le trou.
2. **Inspection du code décisionnel** : examiner les vraies fonctions RPC et routes serveur qui traitent réponses, nœuds cibles, règles, organisation et sessions. Toute donnée d'autorité doit être recalculée/vérifiée côté serveur.
3. **Offre verticale** : suivre le flux de bout en bout depuis le formulaire/UI jusqu'à la persistance, la commande, l'idempotence et l'audit ; confirmer s'il contourne ou non le Runtime décrit.
4. **Sécurité multi-tenant** : préparer un environnement isolé réellement représentatif des policies/RPC Supabase et tester utilisateurs/tenants synthétiques autorisés, non autorisés et sans membership.
5. **MVP régressions** : exécuter toutes les fiches historiques, y compris tests marqués Validated ; conserver preuves datées et SHA.
6. **Fonctions V1 restantes** : ne commencer à déclarer des fonctions acceptées qu'après la fermeture des bloqueurs précédents et des parcours E2E correspondants.

## 5. Conditions de sortie du blocage

- Source de migrations reproductible, revue et approuvée.
- Les tests RLS/cross-tenant échouent fermé pour les accès interdits et réussissent pour les accès légitimes.
- Les RPC recalculent et valident les transitions au lieu de faire confiance aux cibles fournies par le client.
- Le flux `CREATE_OFFER + ProductMaster` est atomique, idempotent, vérifié par rôle et audité.
- Les tests historiques MVP sont rejoués sur un SHA identifié ; aucun statut ancien n'est considéré comme preuve actuelle par défaut.
- Le registre Git relie chaque exigence à une décision Notion, aux fichiers/migrations, au test et à une preuve de résultat.
- Le Security Gate n'est marqué PASS qu'après validation indépendante du schéma/policies réels dans un environnement autorisé.

**État courant après cette revue : documentation enrichie, mais aucun test fonctionnel nouvellement exécuté. Security Gate reste NOT PASS.**

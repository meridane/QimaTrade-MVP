# QIMA — État courant du Security Gate

Date de mise à jour : 2026-10-23 (UTC)  
Branche : `chore/qima-free-autopilot-review`  
PR : [#25 — réparations de sécurité (brouillon)](https://github.com/meridane/QimaTrade-MVP/pull/25)  
Environnement : tests gratuits et isolés uniquement.

## État exécutif

**Security Gate : NOT PASS — sécurité multi-tenant non démontrée.**

| Domaine | Statut | Preuve / portée |
|---|---|---|
| PR | OPEN / DRAFT / NOT MERGED | [PR #25](https://github.com/meridane/QimaTrade-MVP/pull/25) |
| QIMA CI applicative | En cours au dernier contrôle avant ajout du test SQL | [Runs QIMA CI](https://github.com/meridane/QimaTrade-MVP/actions/workflows/ci.yml) |
| CodeQL | PASS sur le HEAD précédent `54a1f7ac7ac753db369977cd0fabbce8ea31f5aa` | [Runs CodeQL](https://github.com/meridane/QimaTrade-MVP/actions/workflows/codeql.yml) ; cette réussite ne couvre pas RLS |
| Vercel Preview | SUCCESS sur le HEAD précédent `54a1f7ac7ac753db369977cd0fabbce8ea31f5aa` | [Preview](https://qimatrade-mvp-git-chore-qima-free-autopilot-review-bmk1.vercel.app) ; ne vaut pas validation sécurité |
| Fixture PostgreSQL A/B | Préparée, pas encore exécutée dans cette session | [Harnais local](../testing/qima-local-postgres-harness.md) |
| RPC Decision Tree réels | NON TESTÉS sur une base canonique | Bloqués par l'écart de migrations |
| Production Supabase | Aucune mutation effectuée | Aucun reset, push, migration ou test d'écriture |
| Branche Supabase payante | REFUSÉE | Continuer avec une solution gratuite |

> Toute nouvelle modification de code/CI déclenche de nouveaux runs. Ne pas réutiliser un résultat d'un ancien SHA pour déclarer le HEAD courant validé.

## Blocage principal : historique des migrations

L'inventaire documenté trouve **157 migrations appliquées à distance contre 15 fichiers SQL dans le dépôt**. Aucune source complète des migrations n'a encore été retrouvée. Ne pas inventer les migrations manquantes, ne pas lancer `supabase db reset` en prétendant reproduire la production, et ne pas appliquer de migration distante.

## Actions effectuées suite à l'audit de la page Notion

- Ajout de ce rapport d'état unique pour séparer clairement le statut actuel des entrées historiques.
- Ajout à la CI de l'exécution du harnais PostgreSQL jetable via `sh scripts/test-qima-security-fixture.sh`. Le test n'utilise que des données synthétiques et un conteneur local PostgreSQL; il ne teste pas l'émulateur complet Supabase ni les RPC réels.
- Les nouveaux runs déclenchés par ces changements doivent être contrôlés sur le commit exact avant d'actualiser les statuts.

## Risques à traiter avant d'ouvrir le Security Gate

1. Exécuter et archiver le résultat de la fixture PostgreSQL A/B dans la CI.
2. Retrouver ou déclarer officiellement indisponible la source canonique des migrations.
3. Après récupération du schéma canonique, tester les vrais grants/RLS, les memberships multiples, l'idempotence, les mutations d'historique, les demandes produit et les fonctions `SECURITY DEFINER`.
4. Examiner les deux tables signalées sans RLS (`public.attribute_options`, `public.attribute_units`) et les fonctions/grants à privilèges sur un schéma de test correspondant au schéma réel.
5. Garder le Security Gate à NOT PASS jusqu'à preuve archivée pour les tests applicables.

## Garde-fous

- Pas de test d'écriture ni de test adversarial sur la production.
- Pas de migration, déploiement de production ou fusion de PR sans autorisation explicite.
- Pas de branche Supabase payante.
- Ne jamais présenter un build, un audit statique, CodeQL ou des smoke tests comme preuve d'isolation tenant.
- Pour chaque rapport d'erreur, documenter le chemin exact du fichier et fournir le contenu complet corrigé.

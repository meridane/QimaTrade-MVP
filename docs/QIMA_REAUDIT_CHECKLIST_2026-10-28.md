# QIMA — Checklist de ré-audit V1

Date de suivi : 2026-10-28
Branche : fix/create-offer-status-contract

| Domaine | État actuel | Reste à faire pour clôturer l'audit |
|---|---|---|
| CI TypeScript/build | Dernière exécution connue réussie avant les derniers tests | Vérifier le run CI associé au dernier commit |
| Tests PostgreSQL CREATE_OFFER | Réussis sur fixture isolée | Revalider après les changements CI |
| RLS messages historiques | Test synthétique précédent réussi | Vérifier le run actuel ; comparer le prédicat au schéma et aux workflows réels |
| RLS participants conversations/transactions | Nouveau test synthétique ajouté, résultat CI non confirmé | Exécuter et corriger les tests ; valider les vrais chemins métier et les politiques exactes |
| Autorisation CREATE_OFFER | Contrat de statut/idempotence amélioré dans la PR | Définir et tester l'autorisation demande ↔ tenant fournisseur, y compris refus négatifs |
| Route API offres historique | Route directe susceptible de contourner le runtime universel | Définir contrat métier ; tester permissions, idempotence et événements avant refactor |
| Migrations Supabase | Historique distant et local à réconcilier | Comparer les versions et produire un rapport de différences sans appliquer de migration |
| Tables historiques public / RLS et grants | Inventaire antérieur, plusieurs tables à analyser | Revoir table par table les grants, usages, vues/fonctions et politiques ; ne pas révoquer globalement |
| Parcours utilisateur E2E | CI navigateur en cours / résultat final à confirmer | Tester connexion, onboarding, demande, offre, matching, conversation et accès refusé |
| Google OAuth en conditions réelles | Code compilé, test interactif non confirmé | Tester connexion/callback/session et retour après erreur avec compte de test |
| Outbox/événements/notifications | Structures SQL présentes ; worker/consommateurs non confirmés | Vérifier worker, retries, idempotence, erreurs et supervision |
| Fonctionnalités UI/admin | Registre fonctionnel indique des éléments partiels ou à tester | Vérifier les écrans et parcours V1 sur le déploiement Preview |
| Déploiement | Preview Vercel READY sur le dernier SHA observé | Vérifier que le dernier commit reste READY et tester l'URL ; ne pas déployer en production |
| Registre des fonctionnalités | Existant mais à compléter | Mettre à jour chaque ligne avec statut, fichiers, tests et date de validation |

## Conditions de clôture
1. CI verte sur le dernier commit, y compris les tests SQL nouveaux et Playwright.
2. Aucun risque RLS P0 sans décision documentée et test de non-régression.
3. Contrat d'autorisation de CREATE_OFFER documenté et testé.
4. Réconciliation des migrations terminée sans écriture en production.
5. Parcours métier V1 testé de bout en bout et registre mis à jour.
6. Les points non vérifiés sont explicitement marqués « À TESTER », pas « VALIDÉ ».

## Limites de sécurité
Aucun test offensif ne doit être exécuté contre la production et aucune migration/grant de production ne doit être modifié dans le cadre de cet audit sans autorisation explicite. Les fixtures SQL sont synthétiques et ne prouvent pas à elles seules le comportement complet du schéma déployé.

## Suivi après revalidation — 28 octobre 2026

- HEAD contrôlé : `fac4c83853350bab61ce97a0a0881bcc9470f332`.
- QIMA CI : **SUCCESS** (typecheck, audit npm, build, Playwright et trois suites PostgreSQL isolées).
- CodeQL : **SUCCESS**.
- Vercel Preview : **SUCCESS** sur ce HEAD.
- **Qualification importante :** les suites legacy-messages et participant-self-enrollment sont des reproductions synthétiques du motif de politique observé. Elles ne chargent pas les politiques live exactes, et la proposition SQL de correction RLS n'est pas appliquée à la production. Le résultat vert valide le test du modèle, pas la correction du schéma live.
- La revue du registre de migration reste incomplète : 161 versions distantes rapportées contre 17 fichiers suivis dans la branche. Ce décalage de comptage n'est pas en soi une preuve de migration manquante.
- Prochaine priorité : construire un environnement de test jetable reproduisant les politiques/fonctions pertinentes et appliquer la proposition RLS uniquement à cet environnement ; établir la règle de visibilité d'une demande avant de modifier CREATE_OFFER.

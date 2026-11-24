# QIMA V1 Function Register — QA430

## QA430 — explicit empty DATABASE_URL rejection in the read-only migration-cleanup assertion

**Statut au moment de la publication :** correctif publié sur une branche de travail issue du HEAD validé 2b9a1ea457a9430499cb51f0d5cd6cc26a16528c ; validation CI du nouveau HEAD en attente.  
**Cible :** PR #26, branche fix/create-offer-status-contract.  
**Branche de travail :** work/qima-qa262-empty-db-url-assertion-20261124-1503.

## État initial relu

- PR #26 : OPEN / DRAFT / non fusionnée, mergeable=true, base main.
- HEAD officiel avant ce changement : 2b9a1ea457a9430499cb51f0d5cd6cc26a16528c.
- Comparaison GitHub : 2 362 commits devant main, 0 derrière.
- QIMA CI #1887 : SUCCESS sur le HEAD 2b9a1ea457a9430499cb51f0d5cd6cc26a16528c.
  - Verify : job 138222396752, SUCCESS ; journaux : npm audit au seuil high, TypeScript, build Next.js et 423 Playwright passed (36,2 s).
  - PostgreSQL 16 : job 138222396451, SUCCESS ; le journal confirme le garde-fou du runner participant, les 11 URL non autorisées, les cas DATABASE_URL unset/empty, les trois URL loopback autorisées et la régression RLS participant.
  - PostgreSQL 17.6 : job 138222396719, SUCCESS.
  - CodeQL #1815 : SUCCESS.
  - Vercel Preview : SUCCESS.
  - Les deux jobs de simulation prepared-transaction qui concluent failure sont des scénarios d'échec intentionnels ; leurs jobs d'assertion sont SUCCESS. Le job explicitement skipped est attendu. La conclusion globale de CI #1887 reste SUCCESS.

## Constat et changement

- Le test QA262 de tests/sql/test-legacy-messages-runner-guard.sh vérifiait déjà qu'une variable DATABASE_URL absente est rejetée avant tout appel au stub psql.
- Le runner tests/sql/assert-legacy-migration-database-absent.sh utilise le contrôle Bash de variable obligatoire, qui doit rejeter aussi bien une variable absente qu'une variable explicitement vide.
- La couverture ne distinguait pas encore le cas explicitement vide.
- Le test factorise maintenant l'assertion de configuration manquante et exécute deux cas séparés : env -u DATABASE_URL et env DATABASE_URL="".
- Chaque cas exige le code de sortie exact 1, le diagnostic obligatoire, un journal d'appels psql vide et l'absence d'identifiants dans la sortie.
- Le message final indique désormais unset/empty DATABASE_URL.

## Fichiers modifiés

- tests/sql/test-legacy-messages-runner-guard.sh — couverture de régression uniquement.
- docs/QIMA_V1_FUNCTION_REGISTER_QA430_APPEND.md — supplément append-only au registre.

Aucun runner, fichier SQL, migration, code applicatif, donnée Supabase, grant ou policy persistante n'a été modifié.

## Validation

- Vérification de transformation : le bloc QA262 existant a été remplacé exactement une fois ; le nouveau helper contient les deux cas distincts et conserve les autres scénarios.
- Aucun test shell local n'a été exécuté dans cet environnement.
- Les résultats CI #1887 cités ci-dessus valident le parent 2b9a1ea457a9430499cb51f0d5cd6cc26a16528c, pas ce nouveau cas.
- Après publication sur la branche PR, les nouveaux checks GitHub Actions, CodeQL et Vercel doivent être lus sur le nouveau HEAD avant de clôturer QA430.

## Limites et sécurité

- Ce test utilise un stub inerte et caractérise le contrat du runner dans CI ; il ne démontre pas une vulnérabilité exploitable en production.
- Le fichier canonique docs/QIMA_V1_FUNCTION_REGISTER.md a été relu par métadonnées : blob debec34cf4cf61a822e0be80229802ad0d30747d, taille GitHub 2 840 776 octets. L'API de lecture a renvoyé un contenu vide, y compris avec une plage de lignes ; pour éviter de remplacer ou tronquer un registre de 2,8 MB sans pouvoir le relire, cette entrée est publiée dans un supplément append-only. Le registre canonique est laissé intact.
- Aucune donnée ou migration Supabase Production, aucun secret, grant ou policy RLS persistante n'a été modifié. Aucun déploiement Production, merge, force-push ou changement de protection GitHub.

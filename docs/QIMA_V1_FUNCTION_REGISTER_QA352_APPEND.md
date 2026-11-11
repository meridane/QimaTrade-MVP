# QA352 — résultat ambigu après redémarrage PostgreSQL

Date : 12 novembre 2026

## État initial vérifié

- PR #26 : OPEN, DRAFT, non fusionnée, base `main`.
- HEAD initial : `48f87b1a1e4b11d7e537fd22f8bf6a9ec45e3af0`.
- 1 459 commits en avance sur `main`, zéro en retard ; 108 fichiers modifiés.
- Aucun review humain ni thread de review.
- QIMA CI #1266 et CodeQL #1216 étaient QUEUED au début de cette exécution.
- Le statut combiné du HEAD signalait Vercel SUCCESS pour le Preview existant.
- Le registre canonique `docs/QIMA_V1_FUNCTION_REGISTER.md` a été demandé sur la branche PR ; l'API Contents a retourné un contenu vide avec le blob SHA `0612a3b2e550f19e70681353984f698f9e9afdc7`. Le fichier n'a pas été remplacé.

## Priorité

Compléter QA351 par un test de résultat ambigu du redémarrage : le mock simule un redémarrage appliqué, puis `docker restart` retourne le code 43. Le script de restauration doit préserver le code d'erreur et ne pas annoncer une restauration confirmée.

## Modification QA352

Fichier de code modifié :

- `tests/sql/test-prepared-transactions-config-restore.sh`

Le mock Docker accepte désormais `MOCK_DOCKER_RESTART_APPLY_THEN_FAIL=true`. Il écrit le marqueur temporaire `restart-applied` avant de retourner le code configuré. Le marqueur est supprimé entre les cas et transmis uniquement au mock local.

Le nouveau scénario QA352 exige :

- code de sortie 43 ;
- présence du marqueur `applied`, prouvant l'effet simulé avant le retour d'erreur ;
- diagnostic exact `PostgreSQL service restart failed (docker restart exit 43)` ;
- séquence limitée à `docker-ps`, `pg-isready`, `docker-exec-reset`, `docker-restart` ;
- exactement une sonde de disponibilité (la sonde préalable au RESET) ;
- aucune requête SHOW, aucun contrôle des ressources résiduelles et aucun message de restauration réussie.

Le script de restauration de production/CI n'a pas été modifié. Toutes les commandes externes de ce test sont des mocks locaux ; aucun accès réseau ou base réelle n'est nécessaire au scénario.

## Validation

- Revue du diff GitHub : PASS ; le changement est limité au test de restauration.
- Exécution locale de Bash non disponible via la connexion GitHub utilisée pour cette exécution ; la validation exécutable est confiée à la CI de la PR.
- Statut CI/CodeQL du nouveau HEAD : à renseigner après le déclenchement et la fin des workflows.
- Aucun résultat PASS/FAIL n'est revendiqué avant la fin des jobs.

## Sécurité et périmètre

Ce test synthétique caractérise le comportement du script quand un redémarrage semble avoir été appliqué mais que le client reçoit un code d'erreur. Il ne prouve pas qu'un redémarrage ambigu s'est produit en Production ni qu'une vulnérabilité a été exploitée.

Aucune donnée Supabase Production, migration, fonction SQL, schéma, politique RLS, grant, secret ou configuration persistante n'a été modifié. Aucun déploiement Production, aucune fusion, aucun force-push et aucune modification des protections de branche.

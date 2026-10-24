# Exécuter la fixture de sécurité QIMA localement

## Ce que fait le harnais
Le harnais lance un PostgreSQL jetable dans Docker, crée les rôles de test `anon` et `authenticated`, fournit un shim local `auth.uid()`, applique la fixture synthétique, puis exécute les assertions RLS A/B et permissions. Il n'utilise aucune URL ou clé Supabase distante.

**Important :** ce n'est pas l'émulateur complet Supabase, ni une copie de la base de production. Il valide seulement le contrat RLS décrit dans la fixture. Les RPC Supabase et le vrai moteur Decision Tree ne sont pas testés ici.

## Prérequis
- Docker Desktop ou Docker Engine en fonctionnement.
- Docker Compose plugin.
- Git checkout de la branche `chore/qima-free-autopilot-review`.

## Exécution
Depuis la racine du dépôt, lance :
```sh
sh scripts/test-qima-security-fixture.sh
```

Le script :
1. démarre `docker-compose.qima-security.yml` sur `127.0.0.1:55432`;
2. applique `supabase/fixtures/qima_security_contract.sql`;
3. exécute `supabase/fixtures/qima_security_contract_tests.sql` avec `ON_ERROR_STOP=1`;
4. arrête et supprime le conteneur et le volume jetables, même en cas d'échec.

Le message `PASS` n'est affiché que si les commandes SQL se terminent sans erreur. Si Docker n'est pas installé ou démarré, le script s'arrête avec une erreur.

## Couverture actuelle
- accès anonyme au schéma et aux tables de fixture ;
- absence de privilèges client INSERT/UPDATE/DELETE sur sessions, observations, transitions et demandes produit ;
- visibilité attendue des données pour l'utilisateur synthétique A et l'utilisateur synthétique B.

## Limites
- Exécuter le harnais et conserver la sortie réelle avant de déclarer les assertions réussies.
- Ce test ne prouve pas la sécurité du schéma live.
- La base distante a 157 migrations déclarées appliquées alors que le dépôt ne contient que 15 migrations ; ne pas exécuter de reset/push sur la production.
- Ne jamais mettre de clés, JWT, mots de passe réels ou données personnelles dans la fixture.

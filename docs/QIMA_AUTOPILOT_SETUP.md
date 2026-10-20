# QIMA Autopilot — orchestrateur de développement toutes les 15 minutes

## Objectif

Toutes les 15 minutes, GitHub Actions examine le résultat des exécutions précédentes, lit le registre des fonctionnalités QIMA, choisit une tâche unique, lance OpenAI Codex pour effectuer le travail, puis prépare une Pull Request contrôlable.

## Cycle

1. Déclenchement par cron ou lancement manuel.
2. Vérification de la configuration et recherche d'une Pull Request créée par l'automate encore ouverte.
3. Si une PR de l'automate est ouverte, le cycle s'arrête pour éviter les changements concurrents. Après sa fusion ou fermeture, un cycle suivant peut traiter une nouvelle tâche.
4. Sinon, le workflow transmet à Codex le registre, les résultats des exécutions précédentes, les PR ouvertes et les dernières PR automatisées fusionnées.
5. Codex effectue une tâche limitée et lance les vérifications disponibles.
6. Le workflow exclut les modifications aux workflows/configurations GitHub, aux migrations Supabase et aux fichiers .env*.
7. Les changements sont poussés sur une branche qima-autopilot/*, et une PR est ouverte vers main. Aucune fusion automatique n'est autorisée.

## Activation requise une seule fois

1. Dans GitHub, ouvrir **Settings → Secrets and variables → Actions → New repository secret**.
2. Créer le secret **OPENAI_API_KEY** avec une clé API OpenAI valide.
3. Vérifier que GitHub Actions est autorisé dans **Settings → Actions → General** et que les workflows peuvent créer des Pull Requests.
4. Ouvrir **Actions → QIMA 15-minute Autonomous Development Loop → Run workflow** pour le premier essai.

La clé API doit être créée dans le compte API OpenAI et peut entraîner des frais API distincts de l'abonnement ChatGPT. Ne jamais mettre cette clé dans le code, un commit, une issue ou le chat.

## Contrôles et limites

- Cadence demandée : toutes les 15 minutes. GitHub peut retarder les déclenchements programmés en période de forte charge; l'exécution n'est pas garantie à la seconde près.
- Une seule exécution à la fois.
- Une seule PR d'automatisation ouverte à la fois.
- Aucune fusion, aucun déploiement et aucune modification de la base Supabase de production.
- La présence d'une PR ne prouve pas que son code est correct : il faut vérifier la CI et relire le diff avant fusion.
- Le workflow ne démarre pas l'agent tant que OPENAI_API_KEY n'est pas configurée.
- Le coût dépend du nombre de cycles réellement exécutés et de la consommation API; surveiller l'utilisation et définir un budget/une limite dans la plateforme API.

## Fichier du workflow

.github/workflows/qima-autopilot.yml

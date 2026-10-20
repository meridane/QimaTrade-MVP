# QIMA Autopilot — version 100 % gratuite en local

Cette variante n'utilise aucune clé API payante. Le modèle tourne sur le PC via Ollama; Aider pilote les modifications; GitHub CLI publie une Pull Request à relire.

## Coût et limites

- Aucun coût OpenAI API ni abonnement supplémentaire requis.
- Ollama, Aider et GitHub CLI sont gratuits/open source.
- Le PC doit rester allumé et connecté, avec Ollama actif.
- Sur une machine avec 8 Go de RAM, commencer avec qwen2.5-coder:1.5b. Le modèle local est moins performant et plus lent qu'un grand modèle cloud.
- Le téléchargement initial du modèle consomme environ 1 Go d'espace disque et de données Internet.
- Le cycle s'arrête si une PR qima-autopilot/* est déjà ouverte, afin d'éviter les changements concurrents.
- Les frais Internet et l'électricité ne sont pas inclus; il n'y a pas de frais IA/API.

## Installation Windows

1. Installer Ollama depuis https://ollama.com/download
2. Installer Python si nécessaire, puis Aider Chat selon https://aider.chat/docs/install.html
3. Installer GitHub CLI depuis https://cli.github.com/ puis exécuter gh auth login.
4. Télécharger le modèle avec ollama pull qwen2.5-coder:1.5b
5. Depuis la racine du dépôt, installer les dépendances avec npm install --no-package-lock --no-audit --no-fund
6. Installer Chromium avec npx playwright install chromium
7. Installer la tâche planifiée avec powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-qima-autopilot-local.ps1
8. Pour tester immédiatement, exécuter powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\qima-autopilot-local.ps1

## Fonctionnement

1. Vérifie les outils, le modèle local et l'authentification GitHub.
2. S'arrête si une PR d'automatisation est ouverte ou si le dépôt a des changements locaux non commités.
3. Lit docs/QIMA_V1_FUNCTION_REGISTER.md et le résultat du cycle précédent.
4. Crée une branche depuis origin/main et demande à Aider une tâche limitée.
5. Restaure les chemins protégés, puis lance npm run typecheck, npm run build et npm run test:e2e.
6. Crée une PR normale si les tests passent, sinon une PR brouillon. Aucune fusion ni aucun déploiement automatique.
7. Enregistre les résultats dans %LOCALAPPDATA%\QIMA-Autopilot\last-result.md et les logs dans le même dossier.

## Chemins protégés

Le runner restaure les modifications de .github/, supabase/migrations/, .env*, package.json et package-lock.json. Il ne lance pas de migration et ne modifie pas Supabase de production.

## Arrêter

Exécuter dans PowerShell :
Unregister-ScheduledTask -TaskName "QIMA Autopilot Local" -Confirm:$false

## Sécurité

- Vérifier le diff de chaque PR avant fusion.
- Ne pas donner de secrets de production au modèle local.
- Ne pas utiliser le script sur un répertoire contenant des changements non commités.
- Une PR n'est pas une preuve de correction; la CI et la revue restent obligatoires.

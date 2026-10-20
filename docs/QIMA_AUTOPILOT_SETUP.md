# QIMA Autopilot — version 100 % gratuite

La solution retenue est l'agent local Windows décrit dans [QIMA_AUTOPILOT_FREE_LOCAL.md](QIMA_AUTOPILOT_FREE_LOCAL.md).

Elle utilise Ollama pour exécuter un modèle de code local, Aider pour modifier le dépôt et GitHub CLI pour créer des Pull Requests. Aucune clé API OpenAI payante n'est nécessaire. Le PC doit rester allumé et connecté pour que la tâche planifiée fonctionne.

## Installation

Suivre le guide complet : [QIMA Autopilot local gratuit](QIMA_AUTOPILOT_FREE_LOCAL.md).

Le cycle est prévu toutes les 15 minutes, lit le registre de fonctionnalités et le résultat précédent, exécute TypeScript/build/E2E, puis ouvre une PR pour revue. Il ne fusionne pas automatiquement et ne modifie pas la base Supabase de production.

Le modèle local peut être moins performant qu'un agent cloud et dépend de la mémoire disponible sur le PC. Avec 8 Go de RAM, le guide recommande de commencer par qwen2.5-coder:1.5b.

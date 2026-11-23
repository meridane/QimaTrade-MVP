# QIMA V1 Function Register — append-only snapshot

## Vérification du HEAD précédent et travail suivant — 23 novembre 2026, 11:32 KST

### État GitHub lu avant modification

- Dépôt : `meridane/QimaTrade-MVP`.
- PR #26 : **OPEN / DRAFT / non fusionnée**, base `main`, head `fix/create-offer-status-contract`.
- HEAD PR lu : `b379b6232f947c08bd8c8f19f8ad19b6ccc52918`.
- Métadonnées PR : 2 313 commits, 287 fichiers modifiés, 92 092 insertions, 266 suppressions ; GitHub rapportait `mergeable=true`.
- Les dix derniers commits ont été relus. Les commits les plus récents avant cette intervention étaient documentaires ; le dernier code/test de la route CREATE_OFFER est dans l'ascendance de `b379b623`.
- Review threads : aucun ; reviews soumises : aucune.

### Clôture des contrôles du HEAD `b379b623`

- QIMA CI #1850 : **SUCCESS**.
- Job Verify « Typecheck, audit, build and browser tests » : **SUCCESS** ; journal Playwright : **422 passed (34.6s)**.
- Installation npm, audit npm au seuil bloquant `high`, TypeScript, build Next.js, installation Chromium, tests navigateur et fixture sécurité QIMA isolée : **SUCCESS**.
- Intégration PostgreSQL 16 : **SUCCESS**, y compris les tests CREATE_OFFER, replay, concurrence, garde provider actor, refus avant persistance, privilèges du runner et régressions RLS.
- Compatibilité PostgreSQL 17.6 : **SUCCESS**, y compris les tests CREATE_OFFER, replay, concurrence, wrapper-owner et ACL.
- Les deux jobs de simulation setup/cleanup ont une conclusion `failure` intentionnelle ; leurs assertions de contrôle sont **SUCCESS**. Le job attendu en `skipped` est correctement ignoré et son assertion est **SUCCESS**.
- CodeQL #1778 : **SUCCESS**.
- Statut Vercel du HEAD : **FAILURE** avec le lien de quota `api-deployments-free-per-day` / `build-rate-limit`. Ce statut est une limite de quota de déploiements Preview, pas un résultat de compilation. Aucun contournement n'a été tenté.

Liens :
- [QIMA CI #1850](https://github.com/meridane/QimaTrade-MVP/actions/runs/45097839714)
- [CodeQL #1778](https://github.com/meridane/QimaTrade-MVP/actions/runs/45097839702)
- [PR #26](https://github.com/meridane/QimaTrade-MVP/pull/26)

### Nouvelle tâche non bloquante

La migration `20261027090000_fix_create_offer_action_status_contract.sql` calcule le hash d'idempotence à partir de `p_input` **et** du paramètre UUID typé `p_provider_actor_id`. La route validait la casse de `profile.actor_id`, mais conservait le texte reçu dans `p_input.providerActorId`. PostgreSQL compare les UUID indépendamment de la casse, alors que la valeur chaîne incluse dans JSONB est sensible à la casse. Pour garder les deux représentations alignées, la route canonicalise désormais l'UUID acteur en minuscules après validation, comme elle le fait déjà pour `demandId` et `productMasterId`.

Modifications sur la branche de travail `work/qima-provider-actor-uuid-canonicalization-20261123-1132` :
- Commit `dac2ec316fc23c70c1c1a4ece8b326e8122313d3` — `app/api/actions/create-offer/route.ts` : crée `canonicalProviderActorId` après validation et l'utilise dans le payload d'action.
- Commit `f1dba2e854a4edf63d771da8e039c2d05b5dd1fd` — `tests/e2e/create-offer-route-contract.spec.ts` : nouveau test avec un `profile.actor_id` en majuscules ; vérifie que `p_provider_actor_id` et `p_input.providerActorId` sont tous deux canoniques en minuscules.
- Résultat CI de ces nouveaux commits : **pas encore disponible au moment de ce snapshot** ; ils doivent être publiés sur la branche PR par fast-forward puis vérifiés. Aucun nombre de tests n'est anticipé.

### Limitation de mise à jour du registre canonique

Le blob du registre canonique `docs/QIMA_V1_FUNCTION_REGISTER.md` a été relu par référence GitHub : SHA `134a22c21b4b5843aeb8468592b50142ddffd882`. L'API de contenu a renvoyé un contenu vide, y compris avec des plages de lignes explicites. Le fichier est très volumineux ; sans son contenu complet, le remplacer serait risquer d'effacer l'historique. Ce snapshot append-only est donc créé comme trace complémentaire et ne prétend pas remplacer le registre canonique. Réconciliation dans le fichier canonique à effectuer lorsqu'un accès sûr à son contenu complet sera disponible.

### Périmètre

Aucune donnée Supabase Production, aucune migration, aucun secret, grant ou policy RLS persistante n'a été modifié. Aucune migration n'a été appliquée. Aucun déploiement Production, merge, force-push ou changement des règles de protection n'a été effectué. Les tests synthétiques décrivent le comportement contrôlé et ne démontrent pas une vulnérabilité exploitable en Production.

# QIMA — Qwen Local Coding Readiness Master Specification

Status: documentation in progress; not certified complete. Date: 2026-10-26.
Repository: meridane/QimaTrade-MVP.

## Non-negotiable rules
- Treat this as a coverage index, not proof that features are implemented.
- Separate DOCUMENTED, PRESENT IN CODE, PRESENT IN DATABASE, TESTED, VALIDATED, PARTIAL, MISSING, BLOCKED and UNKNOWN.
- Before every task, read the canonical Notion requirement, this document, docs/QIMA_V1_FUNCTION_REGISTER.md, relevant code, migrations and tests.
- Never silently resolve business contradictions; record sources and impact. Prefer safe reversible technical decisions.
- Preserve existing functionality and design. No broad rewrites without a reason and explicit scope.
- No production writes, direct main-branch edits, automatic merges, deployments, secrets in prompts, blind migration replay, reset, or destructive data changes.
- Report exact files changed, tests actually executed and results. NOT RUN is not PASS.
- When asked for a manual fix, provide the full replacement file; when asked for ZIP, include the complete project and design.

## Sources of truth
1. QIMA Knowledge OS and canonical Notion documents: Engineering Blueprint, B4 SQL Model, glossary, API/contracts, architecture/decision records, Coding Automation & Test Ledger and MVP TESTS.
2. GitHub repository code, docs, tests, CI, PRs and migrations.
3. Read-only Supabase production schema, policies, grants, functions, extensions and migration ledger.
4. Verified local hardware/OS/model environment.
If sources conflict, record both exact sources, version/date, impact and a proposed resolution. Ask only for business-critical or destructive decisions.

## Functional coverage to inventory
- Identity: OAuth, callback, session, profile, onboarding, roles, actors, tenants, memberships and permissions.
- Product knowledge: Trade Domain → Category → Subcategory → Product Master, canonical IDs, classification and HS-code links where specified.
- Attribute Engine: definitions, types, schema validation, units, options, applicability, provenance, context, versions, values, audit and Action/DT links.
- Decision Tree Engine: trees, immutable versions, nodes, rules, evaluation, sessions, answers, revisions, transitions, terminal states, resume/reload, concurrency, idempotency, product selection and Product Request→Demand.
- Action Engine: definitions/versions, parameters, input validation, Action↔Attribute and Action↔DT, authorization, execution, results, events, correlation, idempotency, retries and errors.
- Universal runtime target: Action → Parameters → Context/Attributes → DT/Rules → Authorization → Execution → Persistence → Event/Audit → Result. DT remains a component, not duplicated in UI.
- Business flows: Demand → Qualification → Match → Conversation; offers; service-provider capabilities; transactions and transport; showcase/publication; notifications; trust signals; policy/rule/workflow engines; outbox/event consumers.
- Existing test-area flows: Project Workspace, Participants, Tasks, Timeline/Events, Orders, Inspections, Documents, Payment Requests/Payments and Shipments. Do not confuse app/projects/test with proof of a complete public transaction flow.
- UI/admin: every route/page, dynamic forms, user/admin dashboards, loading/empty/error/success states, responsive behavior, accessibility and existing design.
- Cross-cutting: audit, observability, privacy, retention, import/export and monitoring where specified.
For every function map: ID, user outcome, role/tenant, route/UI, API/RPC, Action, Attributes/context, DT/rules, tables/columns, policies/grants, state transitions, events, errors, tests, evidence, status and last verified date.

## Contracts and data model
Before runtime coding, establish canonical JSON/TypeScript schemas for Action, Parameter, Attribute, Context, Tree/Version/Node/Rule, Session/Answer/Transition, Execution/Event, Demand, Product Request, Offer, Match and stable errors. Document IDs, enums, states, tenant keys, FKs, UNIQUE/CHECK constraints, indexes, version rules, soft deletion/archive, transaction boundaries, API inputs/outputs, auth, error codes, pagination, concurrency and idempotency.
Publication lifecycle must be explicit: draft → validate → publish immutable version → execute exact version → archive without breaking historical sessions. Business logic and permissions remain server-side; an LLM cannot authorize actions.

## Security
- Verify identity, tenant and object ownership on every API/RPC and database mutation; never trust browser-supplied user/tenant/actor/target IDs.
- Review RLS, policies, effective grants, SECURITY DEFINER, pinned search_path, views, triggers, storage and functions used by policies.
- Negative tests: anonymous, forged user ID, foreign tenant/object ID, non-member, changed owner/tenant, direct read/write/delete, role escalation, stale revision, concurrent calls, duplicate idempotency key and changed payload under same key.
- Least-privilege credentials; no secrets in code, prompts, logs, commits or ZIPs.
- Do not blanket revoke RPC privileges or add permissive policies to silence advisors.
- Track each security finding. Do not mark Security Gate PASS without runtime evidence.

## Qwen local agent
First record actual OS, CPU, RAM, GPU/VRAM, disk, drivers and model/runtime versions. Select model/quantization only after testing actual hardware on repository-level tasks. Choose local runtime and coding agent/editor with repository context, diff review and command execution.
Start in read-only audit mode. Then enable bounded tasks on dedicated branches, never main. Use small commits, checkpoints, persistent progress journal, resumable queue, limited retries and stop conditions. No production credentials by default; no auto-merge or deploy. Agent must read task + specs + code + tests, inspect Git status, define acceptance criteria, make the smallest change, run tests, review the full diff and update the register. Never delete tests to get green CI or claim unrun checks passed.

## Test strategy / Definition of Done
- Unit: schemas, rules, normalization, state transitions and permission helpers.
- Contract: TS/JSON ↔ API ↔ DB, compatibility and stable errors.
- DB: migrations from known baseline, constraints, atomicity and rollback.
- Security: synthetic two-tenant users, RLS/RPC, forged IDs and direct writes.
- DT: branches, missing/invalid answers, terminal nodes, resume, exact version, stale revision, concurrency and idempotency.
- Runtime: required attributes, validation, authorization, atomic execution, events, retries and duplicate suppression.
- E2E: one complete documented UI→server/runtime→database→result journey, audit/event verification and UI error/empty/loading states.
Definition of Done = requirement linked, code/contracts/migration updated if needed, security reviewed, tests actually passed, design preserved, docs/register updated, diff reviewed and no hidden blocker. A green build alone is insufficient.

## Repository baseline from read-only inspection (main, 2026-10-26)
- Root contains .github, app, components, docs, lib, supabase, tests, middleware.ts, next.config.ts, package.json, playwright.config.ts and tsconfig.json.
- Stack: Next.js 15.5, React 19.1, TypeScript, Tailwind 4, Supabase SSR/client and Playwright.
- Scripts: dev, build, start, typecheck, test:e2e.
- App folders include auth/login/callback, decision-tree, demands, offers, request, service-provider, projects/test and APIs.
- lib includes actions, decision-tree and Supabase modules.
- E2E listing includes auth-smoke.spec.ts; broad business E2E coverage is unproven.
- Workflows include CI, CodeQL and qima-autopilot.yml. docs/QIMA_AUTOPILOT_SETUP.md describes GitHub Actions + OpenAI API, not local Qwen. It requires OPENAI_API_KEY and describes PR-based automation; do not activate paid API usage without explicit approval.
- docs/QIMA_V1_FUNCTION_REGISTER.md exists but last stated review date is 12 October 2026; reconcile it against current docs/code before treating as current.
- Root README is only a short MVP description, not a complete handover.

## Migration drift blocker
Last documented audit: 157 migration ledger entries remotely vs 15 SQL migration files in repository main. Repo alone is not a proven production reconstruction. Reconcile migration history and schema object-by-object; never run reset/push or replay a reconciliation migration blindly.
Files observed:
- 20260824065000_create_project_documents.sql
- 20260824080000_create_project_inspections.sql
- 20260829090000_create_decision_tree_v1.sql
- 20260829091000_create_decision_answer_transaction.sql
- 20260829091500_seed_decision_tree_v1.sql
- 20260829092000_link_decision_tree_to_canonical_taxonomy.sql
- 20260829093000_persist_selected_product_master.sql
- 20260829100000_product_requests_v1.sql
- 20260829102000_grant_authenticated_v1_decision_tree_access.sql
- 20260829110000_product_request_to_demand_bridge_v1.sql
- 20260829112000_add_product_request_updated_at.sql
- 20260829113000_improve_mvp_matching_and_country_fields.sql
- 20260829130000_fix_offers_insert_rls_actor_lookup.sql
- 20260901090000_security_gate_dt_v1.sql
- 20260901120000_action_definition_read_rpc_v1.sql

## Initial feature register (status from previous audit; revalidate)
AUTH-01 Google login/callback — routes present; interactive auth/session tests required.
AUTH-02 Profile/onboarding — schema present; progression/resume needs testing.
AUTH-03 Roles/permissions — schema present; two-account authorization tests required.
TAX-01 Taxonomy/Product Master — schema/data present; reconcile official references and access.
ATTR-01 Attribute Engine — definitions/data present; previous audit found action_attributes empty; trace values and provenance end-to-end.
DT-01 MVP Decision Tree — code/migrations present; test persistence and reload.
DT-02 Universal DT — schema/functions present; verify immutable versions, rules and resume.
ACT-01 Action definitions/parameters — code/tables present; previous audit observed 2 definitions and 7 parameters; runtime linkage unproven.
ACT-02 Action↔Attribute/DT — link tables exist; previous audit found action_attributes had zero rows.
RUN-01 Universal Action Runtime — runtime files exist; full Action→Parameters→Attributes→DT→Execution→Event path not demonstrated.
DEM-01 Demand qualification — routes present; test persistence, publish and ownership.
MATCH-01 Explainable matching — routes/schema present; test results, explanations and permissions.
OFFER-01 Offers — route/action present; test ownership, demand authorization, validation and idempotency.
CHAT-01 Conversations/messages — schema previously observed; confirm UI/API, participants and tenant isolation.
TRANS-01 Transactions — schema reported, no records in prior audit; lifecycle unproven.
SHIP-01 Transport — schema reported; confirm manual/API provider flow and transitions.
SHOW-01 Showcase/publication — schema reported; UI unconfirmed.
TRUST-01 Trust signals — schema reported; scoring rules not validated.
POLICY-01 Policy engine — functions/schema present; previously zero policies.
RULE-01 Rule engine — functions/schema present; previously zero rules.
WF-01 Workflows — functions/schema present; previously zero configured workflows.
EVENT-01 Outbox/events — schema/functions present; prior audit found no events and no confirmed worker.
NOTIF-01 Notifications — schema reported; delivery and UI unverified.
ADMIN-01 Admin tools — partial in previous register; inventory UI and permissions.
AUDIT-01 Audit trail — schema present; verify automatic writes and actor/time.
UI-01 User dashboard — partial; inspect routes, real data and responsive states.
UI-02 Admin dashboard — incomplete/uncertain; requirements need source mapping.
QA-01 Automated tests — auth smoke exists; full business E2E unproven.
OPS-01 Deployment/secrets/observability — verify environment setup without exposing secrets.

## Gates before autonomous coding
A. Inventory all Notion requirements, repository routes/server actions/modules, database tables/functions and tests; map them in the register.
B. Reconcile remote migrations/schema with repository migration files; no reset or blind replay.
C. Freeze Action/Attribute/DT/Context/Execution/Event contracts and prove one vertical slice on isolated test data.
D. Verify actual local hardware, benchmark model, test a small non-critical branch task, verify checkpoint recovery and rollback.
E. Only then allow a queue of bounded coding tasks with diff review and explicit protected actions.

## Launch checklist
- [ ] Canonical Notion source index and conflict rules documented.
- [ ] Every documented feature mapped to a register row.
- [ ] Every route/API/runtime module/SQL object/test inventoried.
- [ ] Migration drift report reviewed.
- [ ] Runtime contracts and one passing isolated vertical slice.
- [ ] Multi-tenant negative tests executed and recorded.
- [ ] Actual hardware/model benchmark recorded.
- [ ] Local agent reads/edits/tests on a branch and resumes from checkpoint.
- [ ] No production secrets, auto-merge or auto-deploy.
- [ ] CI and register updated with evidence and commit SHA.

**Current readiness: IN PROGRESS — NOT CERTIFIED COMPLETE.**
**Next task:** recursively inventory all routes, API endpoints, server actions, engine modules, SQL functions/tables and tests; then cross-reference each with canonical Notion requirements.

## 12. Recursive repository inventory — verified on main (2026-10-26)

The GitHub recursive tree was read from main at commit `0d35c13db81019867fe9929420b0a6916285fbf6`. GitHub returned `truncated=false`, with 102 files in the tree.

### File counts
- TypeScript `.ts`: 45
- React/TSX `.tsx`: 30
- SQL migrations: 15
- YAML workflows/config: 4
- Markdown: 3
- JSON: 2
- CSS: 1
- MJS: 1
- gitignore: 1

### UI pages found (23)
- `app/page.tsx`, `app/login/page.tsx`
- `app/decision-tree/page.tsx`, `app/decision-tree/service-provider/page.tsx`
- `app/demands/page.tsx`, `app/demands/list/page.tsx`, `app/demands/qualification/page.tsx`, `app/demands/match/page.tsx`, `app/demands/conversation/page.tsx`
- `app/offers/page.tsx`, `app/offers/new/page.tsx`, `app/offers/test/page.tsx`
- `app/request/new/page.tsx`
- `app/service-provider/page.tsx`, `app/service-provider/capabilities/page.tsx`
- Test workspace: `app/projects/test/page.tsx`, `app/projects/test/[id]/page.tsx`, and child pages for documents, inspections, orders, payment-requests, payments and shipments.

### API route handlers found (11)
- `app/api/actions/create-offer/route.ts`
- `app/api/decision-tree/answer/route.ts`
- `app/api/decision-tree/products/route.ts`
- `app/api/decision-tree/select-product/route.ts`
- `app/api/decision-tree/service-provider/session/route.ts`
- `app/api/decision-tree/session/route.ts`
- `app/api/offers/route.ts`
- `app/api/product-requests/publish/route.ts`
- `app/api/product-requests/route.ts`
- `app/api/service-provider/capabilities/route.ts`
- `app/api/service-provider/me/route.ts`

### Server-action files found (12)
- `app/demands/actions.ts`
- `app/demands/conversation/actions.ts`
- `app/demands/match/actions.ts`
- `app/demands/qualification/actions.ts`
- `app/offers/actions.ts`
- `app/projects/test/[id]/actions.ts`
- `app/projects/test/[id]/documents/actions.ts`
- `app/projects/test/[id]/inspections/actions.ts`
- `app/projects/test/[id]/orders/actions.ts`
- `app/projects/test/[id]/payment-requests/actions.ts`
- `app/projects/test/[id]/payments/actions.ts`
- `app/projects/test/[id]/shipments/actions.ts`

### Engine modules found (14)
**Action:** `lib/actions/create-offer.ts`, `engine.ts`, `index.ts`, `runtime.ts`, `types.ts`.
**Decision Tree:** `lib/decision-tree/db-adapter.ts`, `engine.ts`, `evaluator.ts`, `resolver.ts`, `seed.ts`, `server.ts`, `session-tree.ts`, `types.ts`, `version-resolver.ts`.

### Tests and instructions
- Only one test file appeared under `tests/` in the recursive tree: `tests/e2e/auth-smoke.spec.ts`. This does not prove there are no tests elsewhere, but coverage of the listed business flows is not demonstrated by this file inventory.
- No `AGENTS.md`, `CLAUDE.md` or Qwen-specific instruction file was found in the recursive tree.
- Workflows found: `.github/workflows/ci.yml`, `codeql.yml`, `qima-autopilot.yml` plus one additional YAML configuration in `.github/`.
- The repository has a small README (44 bytes according to the tree) and needs a proper developer handover guide before unattended work.

### Immediate implication
The coding agent must not start by implementing a new feature. First create a complete traceability matrix across these 23 pages, 11 APIs, 12 server-action files, 14 engine modules, the 15 migration files, all database objects and the existing test ledger. Review the code in each route/action to split it into individual business functions and acceptance criteria. File counts are an inventory aid, not a count of complete features.

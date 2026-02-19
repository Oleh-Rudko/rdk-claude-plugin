# rdk — Acuity PPM Development Workflow Plugin

Personal development workflow plugin with subagent orchestration and file handoff
to avoid compact. Each phase = isolated subagent, result in a file.

## Architecture

```
/rdk:plan → Phase 1-4 (Planning)
/rdk:execute → Phase 5 (Execution)
/rdk:review → Phase 6-7 (Review)
/rdk:resume → Compact recovery
```

### Flow

```
Task → epic.md
    ↓
rails-researcher → research-rails.md      (subagent EXIT)
hasura-researcher → research-hasura.md     (subagent EXIT)
typescript-deriver → research-types.md     (subagent EXIT)
react-planner → research-react.md         (subagent EXIT)
    ↓
Phase 2.5: Technical questions (if any)
    ↓
Orchestrator → plan.md (Epic → Stories → Tasks)
    ↓
architect → senior-review.md              (subagent EXIT)
    ↓
[Human approves]
    ↓
Execution → plan.md [x] + execution-log.md
    ↓
code-reviewer → code-review.md            (subagent EXIT)
architect → final-review.md               (subagent EXIT)
    ↓
✅ Done
```

### File Handoff Pattern

Each task creates a directory:

```
docs/plans/[YYYY-MM-DD]-[slug]/
├── epic.md              ← task description
├── research-rails.md    ← Rails: models, controllers, blueprinters
├── research-hasura.md   ← Hasura: schema, permissions, relationships
├── research-types.md    ← TypeScript: types derived from backend
├── research-react.md    ← React: components, hooks, queries
├── plan.md              ← Epic → Stories → Tasks with checkboxes
├── senior-review.md     ← Architect review of plan
├── execution-log.md     ← Execution log for each task
├── checkpoint-review.md ← Backend checkpoint (FULL mode only)
├── code-review.md       ← Code review results
└── final-review.md      ← Final verification
```

## Components

### Skills (knowledge, auto-activated)

| Skill | When | What |
|-------|------|------|
| task-workflow | Any task | Orchestrator: coordinates phases and subagents |
| quality-checklists | After changes | Quality checklists for Rails/Hasura/TS/React |
| rails-specialist | Working in rails_api/ | N+1, multi-tenant, RSpec, Blueprinter |
| hasura-specialist | Working in hasura/ | Permissions, access_groups, relationships |
| typescript-react | Working in client/ | No any, hooks rules, Apollo, Jest |
| code-review | Before commit | Delegates to code-reviewer agent |

### Agents (subagents, called by orchestrator)

| Agent | Phase | What it does | Output |
|-------|-------|-------------|--------|
| rails-researcher | 2a | Researches rails_api/ | research-rails.md |
| hasura-researcher | 2b | Researches hasura/metadata/ | research-hasura.md |
| typescript-deriver | 2c | Derives TS types from backend | research-types.md |
| react-planner | 2d | Plans React implementation | research-react.md |
| architect | 4, 7 | Senior review of plan and final check | senior-review.md, final-review.md |
| code-reviewer | 6 | Code review with quality checks | code-review.md |

### Commands

| Command | What |
|---------|------|
| `/rdk:plan [description]` | Start planning (Phase 1-4) |
| `/rdk:execute [story]` | Execute tasks (Phase 5) |
| `/rdk:review` | Code review + final check (Phase 6-7) |
| `/rdk:resume` | Restore context after compact |

## Modes

| Mode | When | Subagents |
|------|------|-----------|
| 🟢 Quick | < 15 min, typo/config | None |
| 🟡 Medium (default) | 15 min - 2 hours, 1-2 layers | Only needed ones |
| 🔴 Full | 2+ hours, 3+ layers | All |

## Stack

- Rails 7.2 API-only + Blueprinter + Lambdakiq + RSpec
- Hasura GraphQL + access_groups permission model
- React 18 + TypeScript + Apollo 3 + React Query 3
- Redux + Immutable.js + MUI 7 + AG Grid
- PostgreSQL, multi-tenant (Company → Org → Portfolio → Project)

## How It Works with instructions.md

Plugin **complements** instructions.md:
- `instructions.md` → pilot/copilot philosophy, approval flow, stop-list, language
- Plugin → execution process, subagent orchestration, quality checklists

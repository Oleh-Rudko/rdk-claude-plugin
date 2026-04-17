---
name: task-workflow
description: >
  MAIN ORCHESTRATOR. Use ALWAYS when starting a new task, feature, bug fix,
  or refactoring. Coordinates subagents for research, planning, and review.
  Each phase = separate subagent with file handoff to avoid compact.
  Results are written to docs/plans/[slug]/ as Epic → Stories → Tasks.
---

# Task Workflow — Orchestrator

You are the conductor. You coordinate specialized subagents, each working
in isolation and writing results to a file. This guarantees: no compact, full
documentation, maximum quality at every phase.

This skill does NOT duplicate instructions.md (pilot/copilot, approval flow, stop-list).

---

## ⚠️ PRINCIPLE: ACUITY ≠ TYPICAL APPLICATION

Acuity PPM has custom business logic that often differs from common patterns.
**NEVER assume how business logic should work** — always ask the human.

This applies to EVERY phase (Phase 1, Phase 2.5, Phase 5):
- Propose implementation alternatives: "We can do A or B — which fits better?"
- Ask about project specifics: "I see X, but how does this actually work in your project?"
- If no questions — skip and move on, don't slow down the process

Examples:
- "Typically access is through RBAC, but Acuity uses access_groups — what's correct here?"
- "Proposals have workflow draft→final→approved — should the new feature follow this?"
- "I see financial tracking has CapEx/OpEx — does this affect the new feature?"

---

## WORK MODES

Automatically determine the task scope, propose a mode, and wait for confirmation:
```
"I estimate this as 🟡 MEDIUM (bug fix, 2 layers — Rails + Hasura). OK?"
```
The human can agree or change the mode.

### 🟢 QUICK (< 15 min, 1 layer, 1-3 files)
Typo fix, config change, minor CSS, add one field.
- Subagents NOT needed
- Do it yourself, show what changed
- Run quality checks
- Plan file NOT needed, epic NOT needed

### 🟡 MEDIUM (15 min - 2 hours, 1-2 layers) ← DEFAULT
Bug fix, small feature in 1-2 layers.
- Subagents: only those needed for affected layers
- Create docs/plans/[slug]/ with epic.md (shortened) and plan.md
- Epic → Stories → Tasks (simplified)

### 🔴 FULL (2+ hours, 3+ layers)
Large feature across multiple layers, refactoring.
- All phases, all subagents
- Full documentation in docs/plans/[slug]/
- Epic → Stories → Tasks (full format)

**Default is MEDIUM. Escalate to FULL if the task touches 3+ layers or is obviously large.**

---

## TASK FILE STRUCTURE

For each task (MEDIUM/FULL) a directory is created:

```
docs/plans/[YYYY-MM-DD]-[slug]/
├── epic.md                  ← Phase 1: task description + clarifications
├── research-rails.md        ← Phase 2a: rails-researcher findings
├── research-hasura.md       ← Phase 2b: hasura-researcher findings
├── research-types.md        ← Phase 2c: required types (typescript-deriver)
├── research-react.md        ← Phase 2d: frontend plan (react-planner)
├── plan.md                  ← Phase 3: assembled plan (Epic → Stories → Tasks)
├── senior-review.md         ← Phase 4: architect review
├── execution-log.md         ← Phase 5: execution log (updated as you go)
├── checkpoint-review.md     ← Phase 5 (FULL only): backend checkpoint review
├── code-review.md           ← Phase 6: code review results
└── final-review.md          ← Phase 7: final verification
```

Not all files are required — depends on mode and affected layers.

---

## PHASE 1: UNDERSTANDING AND EPIC

**Who:** You (orchestrator), no subagents.
**Context:** Minimal — only conversation with the human.

1. Read the task from the human
2. Ask **strategic** questions (direction, approach) — SPECIFIC (A or B? not open-ended):
   - "REST endpoint or GraphQL?"
   - "New table or add field to existing one?"
   - "Which UI pattern — modal, drawer, separate page?"
   - The human can answer in 3 min, while a subagent would search for 10 min — always ask first
3. Ask **questions about alternatives and Acuity specifics** (if any):
   - "We can do A or B — which fits your use case better?"
   - "How does this typically work in Acuity? The standard approach might not fit"
   - If no questions — skip this step
4. Determine affected layers: Rails? Hasura? Frontend? DB?
5. Determine mode: Quick / Medium / Full
6. Create directory and `epic.md`:

```markdown
# Epic: [Task Name]
Date: YYYY-MM-DD
Status: 🟡 Planning
Mode: Full / Medium / Quick

## Description
[What needs to be done — in business terms]

## Business Context
[Why this is needed, what outcome is expected]

## Affected Layers
- [x] Rails backend
- [x] Hasura metadata/permissions
- [x] Frontend (React/TypeScript)
- [ ] Database migrations

## Clarifications
- [Answers to questions if any were asked]

## Constraints / Edge Cases
- [If known]
```

7. Show epic to the human, confirm everything is correct
8. Proceed to Phase 2

---

## PHASE 2: RESEARCH (SUBAGENTS)

**Key principle:** Each subagent works in ISOLATION, reads code, writes summary
to a file, and EXITS. Context is freed. The next subagent reads only files.

**Execution order:**
```
Modifying existing:              New feature from scratch:
2a (rails) ──┐ PARALLEL         2a (rails) ─→ 2b (hasura) SEQUENTIAL
             ├─→ 2c → 2d                          ├─→ 2c → 2d
2b (hasura) ─┘
```
- **Modifying existing** → 2a+2b in parallel (both research existing code independently)
- **New feature from scratch** → 2a then 2b (hasura-researcher can use rails findings)
- 2c always waits for 2a+2b (needs research-rails.md + research-hasura.md)
- 2d always waits for 2c (needs research-types.md)

### Phase 2a: Rails Research (if Rails is affected)

**Call subagent:** `rails-researcher`
**Input:** epic.md
**What it does:** Researches rails_api/ — models, controllers, services, migrations,
tests. Finds existing code to modify or use as a pattern.
**Output:** `research-rails.md`
**Then:** EXIT

### Phase 2b: Hasura Research (if Hasura is affected)

**Call subagent:** `hasura-researcher`
**Input:** epic.md
**What it does:** Researches hasura/metadata/ — schema, relationships, permissions,
actions, functions. Understands how new changes fit into the permission model.
**Output:** `research-hasura.md`
**Then:** EXIT

### Phase 2c: TypeScript Types Derivation (if Frontend is affected)

**Call subagent:** `typescript-deriver`
**Input:** epic.md + research-rails.md + research-hasura.md
**What it does:** Based on backend research, determines which TypeScript types
need to be created or modified. Looks at existing types in the project.
**Output:** `research-types.md`
**Then:** EXIT

### Phase 2d: React Planning (if Frontend is affected)

**Call subagent:** `react-planner`
**Input:** epic.md + research-types.md
**What it does:** Plans React components, hooks, queries/mutations.
Uses types from the previous phase, looks for existing patterns in code.
**Output:** `research-react.md`
**Then:** EXIT

**IMPORTANT:** If the task only affects Frontend (no Rails/Hasura) —
skip 2a and 2b, but still run 2c (types) and 2d (react).
Typescript-deriver in this case looks at existing API types and DB schema.

---

## PHASE 2.5: TECHNICAL QUESTIONS (AFTER RESEARCH)

**Who:** You (orchestrator), no subagents.
**Context:** epic.md + all research-*.md files.

After research, subagents may have uncovered ambiguities, alternatives, or decisions
that the human should make. **Always ask before Phase 3** if there is at least one question.

Typical questions after research:

**Technical alternatives:**
- "Found 2 ways to implement X in model Y — which is better: [A] or [B]?"
- "There's legacy code in Z — refactor or work around it?"
- "Permissions for this feature: through access_groups or separate mechanism?"
- "Existing component W can be reused but needs extension — OK?"

**Implementation variants (business level):**
- "Can be done as a separate module or embedded into existing one — what's better for you?"
- "Look, there's option A and option B — which fits your processes better?"

**Acuity specifics (when something non-standard is found):**
- "I see your portfolios have special access logic — should the new feature account for this?"
- "Found a custom pattern in X — is this a deliberate choice or legacy? Should I follow it?"
- "Standard approach here is Y, but yours is different — what's correct for Acuity?"

Rules:
- Questions are SPECIFIC with options (A or B?), not open-ended
- Include context of WHY you're asking (what research found)
- If research found no questions — **skip this phase** and proceed to Phase 3
- Add human's answers to epic.md in the "Clarifications" section

---

## PHASE 3: PLAN ASSEMBLY

**Who:** You (orchestrator).
**What you read:** All research-*.md files (NOT raw code — only summaries).

Create `plan.md` in Epic → Stories → Tasks format:

```markdown
# Plan: [Name]
Date: YYYY-MM-DD
Status: 🟡 Awaiting Approval
Based on: epic.md, research-rails.md, research-hasura.md, research-types.md, research-react.md

---

## Story 1.1: [Database / Migrations]
> [1-2 sentences about what we're doing and why]

- [ ] Task 1.1.1: [Specific action]
- [ ] Task 1.1.2: [Specific action]
- [ ] Task 1.1.3: Write RSpec tests for migrations

## Story 1.2: [Rails Backend]
> [1-2 sentences]

- [ ] Task 1.2.1: [Specific action]
- [ ] Task 1.2.2: [Specific action]
- [ ] Task 1.2.3: Update Blueprinter serializer
- [ ] Task 1.2.4: Write RSpec model + request specs

## Story 1.3: [Hasura Configuration]
> [1-2 sentences]

- [ ] Task 1.3.1: [Specific action]
- [ ] Task 1.3.2: Configure permissions for `user` role
- [ ] Task 1.3.3: Verify metadata consistency

## Story 1.4: [TypeScript Types]
> [1-2 sentences]

- [ ] Task 1.4.1: Create/update types for API response
- [ ] Task 1.4.2: Create/update GraphQL query types
- [ ] Task 1.4.3: Create/update form/component prop types

## Story 1.5: [React Frontend]
> [1-2 sentences]

- [ ] Task 1.5.1: [Specific action]
- [ ] Task 1.5.2: [Specific action]
- [ ] Task 1.5.3: Handle error/loading/empty states
- [ ] Task 1.5.4: Write Jest tests

## Story 1.6: Quality Assurance
- [ ] Task 1.6.1: Run full test suite (RSpec + Jest)
- [ ] Task 1.6.2: Run quality checks (tsc, lint, prettier)
- [ ] Task 1.6.3: Code review (code-reviewer agent)
- [ ] Task 1.6.4: Final senior review (architect agent)

---

## Execution Order
Story 1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6

## Open Questions
- [If subagents found something unclear — here]

## Risks
- [From research files]
```

Rules:
- Stories correspond to layers (DB, Rails, Hasura, Types, React, QA)
- Each Task = one action (5-20 min), specific, not abstract
- Tests — ALWAYS a separate task in each story
- Order: DB → Rails → Hasura → Types → React → QA
- Not all stories are needed — only for affected layers

Show the plan to the human and wait for approval.

---

## PHASE 4: SENIOR PLAN REVIEW

**Call subagent:** `architect`
**Input:** epic.md + plan.md + all research-*.md
**What it does:**
- Checks if plan is complete — nothing missed
- Correct execution order
- Edge cases and multi-tenant considered
- Performance concerns
- Risks that specialists might not see
**Output:** `senior-review.md`
**Then:** EXIT

If architect found issues — show to the human and update plan.md.

---

## PHASE 5: EXECUTION

**Who:** You (orchestrator), no subagents.
**Why not subagents:** Execution requires interaction with the human (approval, questions).

Create `execution-log.md` and work through Stories:

### Cycle for Each Task

```
1. Re-read plan.md — where you are now
2. Execute task
3. Update plan.md — mark [x]
4. Add entry to execution-log.md:
```

```markdown
### ✅ Task 1.2.1: [name]
**Timestamp:** HH:MM (start) → HH:MM (done)   ← track both for duration
**Done:**
- [specific changes]

**Files changed:**
- `path/to/file` — [what]

**Decisions made:**
- [if chose between options]

**Open questions:**
- [if something unclear for next tasks]
```

### Observability (append at the end of execution-log.md)

When the task is fully complete (after Phase 7), append a `## Metrics` section:

```markdown
## Metrics

**Phase durations:**
- Phase 1 (epic): ~5 min
- Phase 2 (research): ~12 min (4 subagents)
- Phase 3 (plan assembly): ~3 min
- Phase 4 (senior plan review): ~4 min
- Phase 5 (execution): ~75 min
- Phase 6 (code review): ~6 min
- Phase 7 (final review): ~3 min
- **Total wall-clock: ~108 min**

**Scope:**
- Stories: 5/5 completed
- Tasks: 22/22 completed
- Files changed: 17 (+432 / -38)
- Layers touched: Rails, Hasura, Frontend

**Review output:**
- Critical: 0
- High: 1 (fixed before merge)
- Medium: 4 (documented, deferred)
- Low: 7 (documented)

**Subagent calls:** rails-researcher, hasura-researcher, typescript-deriver,
react-planner, architect (×2), code-reviewer
```

Metrics are approximate (wall-clock since start of task is enough — no need to time
each subagent precisely). Purpose: identify bottlenecks across tasks over time
(e.g. "research keeps taking 15+ min — consider caching repeat lookups").

### Execution Rules
- Execute one Story at a time
- After each Story — run quality checks for that layer
- If a task turns out larger — split it and update plan.md
- If found a problem in existing code — log in execution-log, don't fix without approval

### 🔴 FULL MODE: Backend Checkpoint Review
In FULL mode — after completing backend stories (DB + Rails + Hasura),
**before moving to frontend** call `code-reviewer` subagent for checkpoint:

```
Story 1.1 (DB) → Story 1.2 (Rails) → Story 1.3 (Hasura)
    ↓
🔍 Backend Checkpoint (code-reviewer subagent)
    → Checks: N+1, multi-tenant, permissions, tests
    → Writes: checkpoint-review.md
    → If 🔴 Critical — fix BEFORE moving to frontend
    ↓
Story 1.4 (Types) → Story 1.5 (React) → Story 1.6 (QA)
    ↓
🔍 Full Code Review (Phase 6 — as usual)
```

This ensures frontend is built on verified backend.
In MEDIUM mode — this step is skipped (one review at the end is sufficient).

### ‼️ COMPACT RECOVERY
If compact occurred:
1. `find docs/plans -name "plan.md" -mtime -7` — find active plan
2. Read plan.md — which tasks [x], which not
3. Read execution-log.md — what was done last
4. Tell the human: "Restored. Last: [X]. Continuing with: [Y]"
5. Continue

---

## PHASE 6: CODE REVIEW

**Call subagent:** `code-reviewer`
**Input:** plan.md + execution-log.md + git diff
**What it does:**
- Checks each layer: N+1, any types, tests, permissions, multi-tenant
- Runs quality checks (rspec, tsc, lint, jest)
- Produces report: 🔴 Critical / 🟡 Important / 🟢 Suggestions
**Output:** `code-review.md`
**Then:** EXIT

If there are 🔴 Critical — fix and run code-reviewer again.

---

## PHASE 7: FINAL SENIOR CHECK

**Call subagent:** `architect`
**Input:** plan.md + execution-log.md + code-review.md
**What it checks:**
- All tasks in plan.md have [x]?
- execution-log has description for each task?
- code-review passed? 🔴 fixed?
- Nothing missed?
**Output:** `final-review.md`
**Then:** EXIT

---

## COMPLETION

After Phase 7:
1. Update epic.md — Status: `✅ Done`
2. Update plan.md — Status: `✅ Done`
3. **Memory distillation (optional but recommended).** Scan epic.md, plan.md, senior-review.md, code-review.md, final-review.md for **non-obvious** learnings worth persisting across sessions:

   - A project-specific pattern the team uses (not derivable from code) → `project` memory
   - Feedback the user gave during the task (correction OR confirmation) → `feedback` memory
   - External reference uncovered (dashboard URL, Linear project, Slack channel) → `reference` memory
   - User preference learned (e.g. "prefers Formik over RHF here") → `user` memory

   Do NOT save:
   - What the code does (visible in the diff)
   - Task-specific details that don't generalize
   - Anything already in an existing memory file

   If nothing clearly non-obvious emerged, **skip this step entirely** — noise in memory is costly.

4. Give the human a summary:

```
Task "[name]" completed.

Stories completed: N/N
Files changed: [count]
Tests: ✅ RSpec passing, ✅ Jest passing
Code review: ✅ No critical issues
Final review: ✅ Approved
Memory: [1 new entry | nothing worth saving]

Documentation: docs/plans/[slug]/
```

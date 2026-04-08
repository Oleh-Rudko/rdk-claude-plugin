# rdk — Acuity PPM Development Workflow Plugin

Personal development workflow plugin with subagent orchestration and file handoff
to avoid compact. Each phase = isolated subagent, result in a file.

> **Read-only by design.** All review output (`code-review.md`,
> `final-review.md`, `senior-review.md`) is written to local files in your
> repo. The plugin never posts to GitHub PRs, issues, or any external system.

## Architecture

```
/rdk:plan → Phase 1-4 (Planning)
/rdk:execute → Phase 5 (Execution)
/rdk:review → Phase 6-7 (Review)
/rdk:next → Compact recovery
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
| `/rdk:review [PR number]` | Code review + final check (Phase 6-7). Default: local working tree. With PR number: review a GitHub pull request |
| `/rdk:next` | Restore context after compact |

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

---

## Installation

This plugin is distributed via a personal Claude Code marketplace.

```bash
# 1. Add the marketplace
claude plugin marketplace add rdk-marketplace https://github.com/YOUR-GITHUB/rdk-claude-plugin

# 2. Install the plugin
claude plugin install rdk@rdk-marketplace

# 3. Verify
claude plugin list
# Should show: rdk@rdk-marketplace ✔ enabled
```

**For local development** (testing your own changes to the plugin without releasing):

```bash
cd your-project
claude --plugin-dir ~/Work/rdk-claude-plugin
```

This loads the plugin from your working directory, overriding the marketplace version. Useful for iterating on plugin changes.

**Per-project setup** (one-time, for each project where you'll use `/rdk:review`):

Add the code-review output directory to `.gitignore`:

```
docs/code-review/
```

The plugin writes review results to `docs/code-review/[YYYY-MM-DD]-[slug].md`. These files are personal/local artifacts — not committed to git. The `.gitignore` entry prevents accidental commits.

---

## Configuration (`.rdk-review.json`)

Optional. Drop a `.rdk-review.json` file in your project root to customize code review behavior:

```json
{
  "checks": {
    "rspec": true,
    "tsc": true,
    "lint": true,
    "jest": true,
    "hasura_consistency": true
  },
  "severity_overrides": {
    "any_type": "high",
    "missing_test": "medium"
  },
  "custom_rules": [
    {
      "pattern": "console\\.log",
      "severity": "high",
      "message": "Debug code left in diff"
    }
  ],
  "ignore_files": ["**/*.test.ts", "**/vendor/**"]
}
```

**Fields:**
- `checks` — enable/disable specific quality checks. Any check set to `false` is skipped entirely.
- `severity_overrides` — bump a rule's severity up or down (e.g. promote `any_type` from Medium to High).
- `custom_rules` — regex patterns to grep in the diff with custom severity and message. Useful for project-specific rules (no `debugger`, no TODO in controllers, etc.).
- `ignore_files` — glob patterns to exclude from review (test fixtures, vendored code, generated files).

**Fallback behavior:** if the file is missing or malformed, the plugin silently falls back to defaults and notes this in the Quality Checks section. No errors are raised. See `agents/code-reviewer.md` Step 0.5 for full semantics.

---

## What you get

Running `/rdk:review` produces a structured Markdown file at `docs/code-review/[YYYY-MM-DD]-[slug].md`. The file is **dual-audience** — written for both developers and QA testers.

**High-level structure:**

```
# Code Review: <branch-or-pr>
## Verdict: 🔴 Blocked / 🟡 Changes Needed / 🟢 Approved
## Quality Checks (RSpec / tsc / lint / jest / Hasura)
## Multi-Tenant Audit (dedicated section — always present)
## Changes since last review (optional — only if previous review exists)

# 🔴 CRITICAL ISSUES (must fix before merge)
## C1. <title>
  ### 👨‍💻 For Dev (technical, English)
    — file:line, exact code quote, suggested diff fix
  ### 🧪 For QA (how to test manually, Ukrainian)
    — manual test steps, expected vs bug behavior, verdict checkbox

# 🟠 HIGH PRIORITY ISSUES (should fix before merge)
## H1. <same structure as Critical>

# 📋 Additional notes — for developer reference
## 🟡 Medium issues (one-liner bullets)
## 🟢 Low / Suggestions (one-liner bullets)
```

**Key features:**

- **Dual-audience:** every Critical/High issue has a "For Dev" technical section AND a "For QA" manual test section. QA people without coding knowledge can verify bugs themselves.
- **Severity focus:** Critical and High at the top with full context. Medium and Low at the bottom as short references for the developer.
- **QA verdict checkbox:** every reported Critical/High issue has 4 checkboxes (Confirmed bug / Cannot reproduce / Not a bug / Already fixed) — QA actively marks each after testing.
- **Multi-tenant audit:** dedicated section for the highest-severity bug class in multi-tenant SaaS. Always present, even when clean.
- **Anti-hallucination:** the agent will not report issues without exact code quotes from the diff. Empty review is a valid and honest result.
- **Persistent:** saved to `docs/code-review/` in your repo (personal, gitignored). You can look back at historical reviews on the same branch.

---

## Team workflow (dev → QA → lead)

The plugin is designed for a 3-role team workflow:

```
1. DEV finishes work on a branch
       ↓
2. (Optional) DEV runs /rdk:review locally, fixes obvious issues
       ↓
3. DEV pushes, opens PR
       ↓
4. QA runs /rdk:review <PR-number>
       → reads Critical/High sections
       → follows "How to test" manual steps (in Ukrainian)
       → marks verdict checkboxes (☐ Confirmed / Cannot reproduce / etc.)
       → returns file to DEV with notes
       ↓
5. DEV fixes confirmed bugs
       ↓
6. QA re-runs /rdk:review <PR-number>
       → verifies fixes
       → "Changes since last review" section shows new commits and
         previously reported issues now fixed/still present
       ↓
7. When clean, LEAD approves and merges
```

**Why it works:** QA people can participate in code review without reading code. They get manual test steps in their language and verdict checkboxes to actively mark. Dev gets structured feedback with exact file:line references and suggested fixes. Lead gets a verified PR with a paper trail.

---

## Using with non-Acuity projects

This plugin is primarily tuned for the Acuity PPM project. However, you can adapt it to other projects with minimal friction:

**Auto-detect tech stack:** The code-reviewer agent checks for `Gemfile`, `package.json`, and `hasura/` in the project root to know which stacks apply. If you don't have Rails, it skips Rails-specific checks automatically. Same for frontend and Hasura.

**`.rdk-review.json` overrides:** Use the config file (see Configuration above) to:
- Disable checks that don't apply (e.g. `"hasura_consistency": false` for non-Hasura projects)
- Override severity for rules that matter less in your context
- Add custom rules specific to your codebase
- Ignore files/directories irrelevant to review

**What's still Acuity-specific:**

The `rails-specialist`, `hasura-specialist`, `typescript-react`, and `quality-checklists` skills encode Acuity-specific patterns (`ApiController + Secured`, access_groups permission chain, `serverHooksForGraphqlTS`, Lambdakiq background jobs, etc.). They are read by the code-reviewer agent as context.

For non-Acuity Rails/Hasura/React projects, the skills will still give reasonable guidance (N+1 detection, multi-tenant scoping, no `any` types), but the checklists will mention tools and conventions you don't have. This is cosmetic, not blocking — the agent is smart enough to apply the spirit of the checks even when the specific library names don't match.

**Future work:** A deeper split into universal cores (`rails-specialist-core`) + project-specific overlays (`rails-specialist-acuity`) is on the plugin's internal roadmap (P4). For now, `.rdk-review.json` is the main override mechanism, and auto-detection handles the 80% case.

---

## Review modes

`/rdk:review` supports two modes:

| Mode | Command | What it reviews | Quality checks |
|---|---|---|---|
| **Default** (local) | `/rdk:review` | Current working tree of the current branch (`git diff`) | Local toolchain (rspec, tsc, lint, jest, hasura) — run in parallel |
| **PR** (GitHub) | `/rdk:review 5190` | GitHub pull request #5190 (`gh pr diff`) | `gh pr checks` (real CI results) with graceful skip as fallback |

In PR mode, the agent does **not** check out the PR locally. It reads the diff via `gh pr diff`, fetches metadata via `gh pr view`, and reads CI status via `gh pr checks`. Your working tree is untouched.

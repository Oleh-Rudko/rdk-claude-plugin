# Changelog

All notable changes to the rdk plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the plugin uses [Semantic Versioning](https://semver.org/).

## [1.0.7] — 2026-04-17

### Removed
- **`/rdk:next` command** — not used in practice; compact recovery is trivial to do by reading the active `plan.md` directly. The SessionStart hook still surfaces the active plan path on startup.
- **`/rdk:commit` command** — not used in practice; follows the user's working style (`git commit` stays a manual, intentional action). The commit message / PR description drafting flow is available ad-hoc by asking Claude directly.
- **`commit-message-writer` agent** — no longer referenced after `/rdk:commit` removal.

### Changed
- Help and README updated to reflect 7 active commands (down from 9): `/rdk:plan`, `/rdk:execute`, `/rdk:review`, `/rdk:ui-test`, `/rdk:test-write`, `/rdk:qa-test`, `/rdk:help`.
- SessionStart hook message changed from "run /rdk:next to resume" to "read it to resume work".

## [1.0.6] — 2026-04-17

### Added
- **`qa-test-planner` agent** — proactively generates a manual QA test plan (in Ukrainian) from git diff or `gh pr diff`. Covers golden path, edge cases, permission matrix, multi-tenant isolation (mandatory), regression hot spots. Every case has Pass/Fail/Blocked/Skipped checkboxes and a Notes field.
- **`/rdk:qa-test [PR number]` command** — invokes the agent. Works on local working tree by default, or a GitHub PR when a number is passed. Output goes to `docs/qa-tests/[YYYY-MM-DD]-[slug].md`.
- **Dual-role QA flow:** `/rdk:review` finds bugs and writes verification steps for the bugs it found. `/rdk:qa-test` goes the other direction — assumes code is correct and writes a proactive test plan to catch integration bugs before merge. Use both for full coverage.

## [1.0.5] — 2026-04-17

### Added
- **Three optional agents:** `ui-tester` (Playwright MCP browser smoke tests), `test-writer` (generates missing RSpec + Jest tests), `commit-message-writer` (drafts commit + PR text without running git).
- **Three stand-alone commands:** `/rdk:commit`, `/rdk:ui-test`, `/rdk:test-write` — invoke the optional agents directly, bypassing the orchestrator.
- **`skills/rails-core`:** universal Rails 7 patterns (Zeitwerk, migrations, RSpec, Blueprinter basics, `audited`, N+1). Works standalone for non-Acuity Rails projects.
- **`skills/hasura-core`:** universal Hasura metadata patterns (permissions, relationships, computed fields) without Acuity-specific access_groups chains.
- **`skills/frontend-core`:** universal React 18 + TS patterns (hooks, tests, forms) without Acuity-specific snake_case / cents / portfolioState.
- **Extended thinking block** in `architect.md` — explicit reasoning about multi-tenant, execution order, cross-layer contracts before writing the review.
- **Memory distillation step** in Phase 7 (`task-workflow` skill) — persists non-obvious learnings to auto-memory across sessions.
- **Observability `## Metrics` block** appended to `execution-log.md` at task completion: phase durations, scope, review output counts, subagent calls.
- **Pre-review sanity checks** in PR mode (`/rdk:review <num>`) — warns on closed / draft / conflicting / stale-base PRs before delegating.
- **`scripts/validate.sh`** — lints plugin structure (agent frontmatter, command frontmatter, plugin.json version sync with marketplace.json).
- **Plugin hooks** (`.claude-plugin/hooks.json`) — SessionStart reminds about active plan; UserPromptSubmit suggests `/rdk:next` on compact recovery.
- **`LICENSE`** — MIT.
- **`docs/COOKBOOK.md`** — "how to add a new agent / skill / command" + debugging `permissionMode` issues.

### Changed
- **Model tier strategy applied to every agent.** Research agents (`rails-researcher`, `hasura-researcher`, `typescript-deriver`, `react-planner`) now use `claude-sonnet-4-6` (fast, cheap, sufficient). Critical-reasoning agents (`architect`, `code-reviewer`) use `claude-opus-4-7`. Previously all used `opus` alias (non-deterministic). Expected cost drop: ~40–60% on research phase, no quality loss.
- **Skill resolution via Glob** in every agent — works under both `--plugin-dir` and marketplace install paths. Previously hardcoded `.claude/rdk-plugin/skills/…` which could silently fail.
- **Explicit parallelism in `/rdk:plan`** — researchers called concurrently via a single message with multiple Agent tool calls (for tasks modifying existing code).
- **`rails-specialist` now acts as Acuity overlay** pointing to `rails-core` for universal patterns. Same for `hasura-specialist` → `hasura-core` and `typescript-react` → `frontend-core`.
- **README + `/rdk:help` updated** with new agents, model tiers, and new stand-alone commands.

### Fixed
- **Broken TypeScript template literal** in `typescript-deriver.md` (`Project =sQueryVars` → `ProjectsQueryVars`).
- **`$ARGUMENTS` echo at the end of `review.md`** removed (was producing a stray line in rendered output).
- **Version desync** between `plugin.json` (was 1.0.4) and `marketplace.json` (was 1.0.3) — both now 1.0.5.

## [1.0.4] — Prior state

Last release before the 2026-04-17 modernization pass. Plugin shipped with:
- 5 slash commands (`/rdk:plan`, `/rdk:execute`, `/rdk:review`, `/rdk:next`, `/rdk:help`)
- 6 agents (all on `opus` alias, hardcoded skill paths)
- 5 skills (rails-specialist, hasura-specialist, typescript-react, task-workflow, quality-checklists) with Acuity and universal content mixed together

See git history for earlier versions.

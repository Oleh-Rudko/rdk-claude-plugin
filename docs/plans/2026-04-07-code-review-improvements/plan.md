# Plan: Code Review Improvements for rdk-claude-plugin

**Date started:** 2026-04-07
**Owner:** rdk (Oleh-Rudko)
**Plugin location:** `/Users/rdk/Work/rdk-claude-plugin/`
**Status:** 📋 Planning phase — no implementation yet

---

## Context

The `rdk-claude-plugin` is a personal Claude Code plugin used by rdk for the Acuity PPM project. The user is happy with most of it but wants to significantly improve the **code review** part so that:
1. It works better for the user's team
2. It can be shared with other developers (pushed to GitHub, re-installed in their Claude Code)

This plan was created in a discussion session before any code changes. We will work through it **one point at a time**, with deep analysis on each point. No batch implementation.

---

## User's Hard Rules (confirmed in discussion)

These three rules override anything in the original 15-point list. They came from the user's actual frustrations with the current plugin behavior.

### Rule 1 — No GitHub PR writes (it's the rdk plugin doing this)

> "After code review is done, I don't like that it wants to — and does — update the pull request and write the found issues into it. I don't want this."

- **Confirmed:** The user said "it's my plugin doing this" — so the rdk plugin is the source, not native Claude Code or pr-review-toolkit.
- **Required behavior:** All output stays in Claude Code chat + local files (`code-review.md`). NEVER `gh pr comment`, `gh pr review`, `gh issue create`, `gh pr edit`.
- **Investigation needed:** Find which agent/command in the plugin actually runs these gh commands. They're not visible in `agents/code-reviewer.md` directly — likely in `architect.md` or in `commands/review.md` orchestration.

### Rule 2 — No conflict with native `/review`

> "When I do slash code review, I see code review from the native Claude Code and also the one from my plugin... it picks the rdk review instead of the native one."

- **Confirmed:** The plugin's skill or command is being auto-selected even when the user types just "code review" in natural language, instead of native `/review`.
- **Required behavior:** Plugin's review only activates when user explicitly types `/rdk:review` (or whatever we rename it to). Natural phrases "review my code" should fall through to native Claude Code.
- **Likely root cause:** `skills/code-review/SKILL.md` description is too broad and triggers on generic "review" mentions.

### Rule 3 — Output: only Critical + High, with QA test instructions

> "I want only critical and high issues shown at the end."
> "If there are real bugs, I want you to provide instructions for QA... they will test whether it's actually a bug or not."
> "The QA tester on our team uses Claude Code. For sure. They use Claude Code and they will be using this plugin."

- **Confirmed structure:**
  - **Top of output (main focus):** 🔴 Critical and 🟠 High issues only, each with manual test instructions for QA
  - **Bottom of output (secondary, "you can also look at this"):** 🟡 Medium and 🟢 Low/Suggestions, brief, for the developer's optional reference
  - **Do NOT** save Medium/Low to a separate file — show them in the same response, just lower
- **QA test instructions language:** Manual testing language for non-developer QA. Steps like "open the projects page, click Edit, verify the error toast appears". NOT `curl`, NOT `rspec`, NOT technical commands.
- **Special case to think about:** How to write QA instructions for non-UI bugs (N+1 queries, multi-tenant leaks, missing validations). QA may need dev tools / network tab / specific scenarios — different template than UI bugs.

### Real Workflow (corrected by user)

The actual team workflow is:

```
Dev finishes work
  ↓
(Optional) Dev runs /rdk:review themselves and fixes obvious issues
  ↓
QA runs /rdk:review (this is the main path)
  ↓
QA reads Critical/High issues + follows the "How to test" steps
  ↓
QA confirms which issues are real bugs vs false alarms
  ↓
Confirmed bugs go back to Dev → Dev fixes
  ↓
QA re-runs /rdk:review → re-tests
  ↓
When clean → goes to rdk (lead) → rdk approves and pushes to prod
```

**Critical implication:** The plugin must be usable by **a QA person who is not a developer**. This affects:
- Output language (no jargon)
- Test instructions (manual steps, not commands)
- Structure (Critical/High up top — that's all QA cares about)
- The whole UX should not assume the reader can read code well

---

## Senior-level mandate from user

> "On point four, I trust you — let's do what's right. Just think carefully about whether the design of the agents and everything as it is now needs changing or not. Why? Because Claude Code used to work one way, now it might work differently. But here you have to be a specialist, a senior, even a top-level one to handle this properly."

For each point: think as a senior engineer. Question whether the change is actually needed. If something in the original 15 points doesn't fit anymore — say so honestly. If something was true a year ago but Claude Code has evolved — say so. **Don't blindly implement.**

---

## How we work through this plan

For **each** point below, we go through 5 phases. Nothing gets implemented until the user explicitly approves the point.

| Phase | What happens |
|---|---|
| **1. Analysis** | Read current state. Find existing implementation. Identify root cause or current limitation. Investigate user's environment if needed. Output: written findings. |
| **2. Design** | Propose 1-3 design options with tradeoffs. Senior judgment: question whether the change is needed at all. Output: written design proposal + recommendation. |
| **3. Implementation** | Only after user approves the design. Edit/create files. Show diffs. |
| **4. Testing** | Run the changed code on a real scenario. Show output. |
| **5. Verification** | User confirms the result matches intent. Mark point as ✅ done. |

**Rule:** We do ONE point at a time. We do NOT start point N+1 until point N is verified.

---

## The 14 Points (in execution order)

### Status legend
- 📋 = Not started (planning only)
- 🔍 = Analysis in progress
- 🎨 = Design in progress
- 🔧 = Implementation in progress
- 🧪 = Testing in progress
- ✅ = Verified and done
- ❌ = Decided NOT to do (with reason)

---

## P0 — User's hard requirements (do these first)

### #A. ✅ Block all GitHub PR writes from the plugin

**Why P0:** Daily user frustration. Cheap to fix. Independent of other points.

**Phase 1 — Analysis tasks:**
- Grep entire `rdk-claude-plugin/` for `gh pr comment`, `gh pr review`, `gh pr edit`, `gh issue create`, `gh api.*pulls`
- Read all 6 agents (`code-reviewer`, `architect`, `rails-researcher`, `hasura-researcher`, `typescript-deriver`, `react-planner`)
- Read all 5 commands (`execute`, `help`, `next`, `plan`, `review`)
- Read all 6 skills
- Find where the GitHub write actually originates
- Confirm with user — "is THIS the behavior you saw?"

**Phase 2 — Design:**
- Add explicit `Forbidden:` block in each agent prompt: never `gh pr comment`, `gh pr review`, etc.
- Document in README: "All output stays in chat + local files only"
- Decide: should we restrict the `Bash` tool whitelist for code-reviewer agent to prevent any `gh` commands at all? (Safer but more rigid.)

**Phase 3 — Implementation:** Edit affected files, show diffs.

**Phase 4 — Testing:** Run `/rdk:review` on a real Acuity PR. Verify nothing appears in GitHub.

**Phase 5 — Verification:** User confirms.

**Open question for analysis:** May not be in agents at all — could be in a command file, or even in skill instructions that auto-load.

---

#### Session 3 resolution (2026-04-07)

Phase 1 Analysis re-confirmed (third time across Sessions 1, 2, 3) that
the rdk plugin makes **zero** `gh pr comment / review / edit` calls in any
executable file. The only matches are in `plan.md` itself as quoted
requirements.

Phase 2 Design proposed three strictness levels:

- **(a) Soft** — Forbidden-block in prompts + README policy statement
- **(b) Medium** — Soft + granular `Bash(<cmd>:*)` whitelist for `code-reviewer`
- **(c) Strict** — Medium + remove `Bash` entirely from the 5 read-only researcher agents

Initial agent recommendation was (c) Strict, on defense-in-depth grounds.

**User pushed back as senior:** "We do analysis. We do code review. We
only read. The wider and deeper the analysis, the better. Strict
whitelist would amputate exactly the capability the agents exist for.
Why is this point even here if Sessions 1+2 proved the problem isn't
in this plugin?"

**Senior re-assessment confirmed the user is right:**

1. The problem #A was written to solve does not exist in this plugin —
   Sessions 1+2 proved it, Session 3 grep confirmed it again.
2. Strict whitelist has real maintenance cost (yarn → pnpm migrations,
   new test runners, new utility commands all break the whitelist) and
   harms agents' analysis capability — `git log`, `git blame`,
   `gh pr view`, `gh pr diff` are legitimate research tools.
3. The "defense" protects against a hypothetical future regression by
   the plugin's only contributor (rdk himself), who explicitly knows
   the rule.
4. Wide analysis tools are a **feature** for a code review agent, not
   a bug. Senior judgment > sunk cost.

**Final decision: Soft minimum.** Single change applied:

`README.md` — added one blockquote paragraph in the preamble (between
the short description and `## Architecture`):

> **Read-only by design.** All review output (`code-review.md`,
> `final-review.md`, `senior-review.md`) is written to local files in
> your repo. The plugin never posts to GitHub PRs, issues, or any
> external system.

**Rejected and why:**

- **Strict `Bash(<cmd>:*)` whitelist** — overengineering, fragile under
  tooling evolution, harms analysis depth, no real risk to mitigate.
- **Forbidden-block in 6 agent prompts** — prompt bloat for zero benefit
  given the README policy already documents the boundary for any future
  contributor or sharing scenario. Three layers of defense for a
  non-existent threat is busywork.

**Files changed in Session 3:** `README.md` (3-line blockquote added),
`plan.md` (this resolution + status updates).

---

### #B. ✅ Eliminate naming conflict with native `/review`

**Why P0:** Daily user frustration. Cheap. Independent of other points.

**Decision made:** Option A — delete the `skills/code-review/` entirely. The user's
workflow is "I explicitly type `/rdk:review` when I want it". Auto-activation via
a skill was the wrong tool and caused collisions with native `/review` and with
the Anthropic `code-review` plugin.

---

#### Session 1 discoveries (2026-04-07)

**Phase 1 Analysis surfaced facts that reshaped the entire plan:**

1. **The user's rdk plugin is NOT enabled in `~/.claude/settings.json`.**
   `enabledPlugins` lists Anthropic plugins only (`code-review`, `pr-review-toolkit`, etc.).
   What the user thought was "my plugin running" was actually **root-level user files**:
   - `~/.claude/skills/code-review/SKILL.md` (Ukrainian, inline process)
   - `~/.claude/agents/code-reviewer.md` (Ukrainian)
   These were created by hand long ago, independent of the plugin.

2. **"The plugin posts to PR" was wrong.**
   Grep of the rdk plugin shows **zero** `gh pr comment` calls. The actual source
   is the Anthropic `code-review@claude-plugins-official` plugin (its
   `commands/code-review.md` has `allowed-tools: Bash(gh pr comment:*)` and step 8
   says "comment back on the pull request"). Rule #A in this plan still holds for
   the rdk plugin itself (no PR writes ever), but the original problem was not
   caused by the rdk plugin.

3. **Version mismatch.** Marketplace cache holds v1.0.1. Working dir is v1.0.2.
   Even if the plugin were enabled, marketplace would serve the outdated version.

4. **Language policy corrected.** User wants agents to respond in whatever
   language the task description uses (inherit language), NOT hardcoded English
   or Ukrainian. This makes the plugin universal for shared use.

5. **Official local dev workflow: `claude --plugin-dir <path>`.**
   Not symlinks, not rsync, not marketplace hacks. This flag loads a plugin
   from a local directory and takes precedence over any marketplace version.
   `/reload-plugins` refreshes changes within a session. See `DEV.md` at the
   plugin root for the full workflow.
   Reference: https://code.claude.com/docs/en/plugins.md#test-your-plugins-locally

---

#### Session 1 changes (complete)

- ✅ Deleted `skills/code-review/` from the working dir plugin
- ✅ Updated 6 agents to "inherit language from task description" instead of
  hardcoded Ukrainian or English
- ✅ Translated all Ukrainian quotes in `plan.md` to English
- ✅ Updated working agreement to universal language policy
- ✅ Updated `README.md` and `commands/help.md` skill tables (removed code-review row)
- ✅ Verified zero Cyrillic characters across the plugin
- ✅ Created `DEV.md` documenting `--plugin-dir` workflow

**Did NOT delete root-level duplicates yet** — they are the user's safety net
until `--plugin-dir` testing confirms the plugin works. Deletion is deferred to
step 4 below, in a new session.

---

#### Remaining steps for #B (new session required)

Phases 4–6 of #B must happen in a new Claude Code session started with
the `--plugin-dir` flag, because the current session doesn't have the plugin
loaded.

**Step 4 — Start a new session with the local plugin:**
```bash
cd ~/Work/acuity_org/acuity      # or any project you work on
claude --plugin-dir ~/Work/rdk-claude-plugin
```

**Step 5 — Verify and test:**
- Type `/rdk:review` → should run the plugin's review command
- Type "do code review" (natural language) → should NOT trigger rdk; should
  route to native Claude Code `/review` or Anthropic `code-review` plugin
- Type "review this code" → same as above
- Confirm no collision, both systems accessible

**Step 6 — Delete root-level duplicates** (only after step 5 passes):
- `~/.claude/skills/code-review/` — the old Ukrainian inline skill
- `~/.claude/agents/code-reviewer.md` — the old Ukrainian agent
- Optionally `~/.claude/plugins/marketplaces/rdk-marketplace/` — dormant v1.0.1 cache

---

#### Session 2 discoveries (2026-04-07, later same day)

Session 2 ran with `claude --plugin-dir ~/Work/rdk-claude-plugin` to execute
Step 5 (verify and test). The test **failed** and surfaced the real cause of
the collision, which Session 1 had misdiagnosed.

**Critical finding — the real source of the `/review` collision:**

Session 1 removed `skills/code-review/` from the working-dir plugin, assuming
that was what auto-triggered on natural-language "review this code". That
assumption was wrong. The plugin was already correctly namespaced as
`/rdk:review`; nothing in it ever registered a bare `/review`.

The actual trigger was `~/.claude/skills/code-review/SKILL.md` — a
**root-level user skill** with this description:

```yaml
description: >
  Код ревʼю процес. Використовуй коли потрібно перевірити якість коду після змін,
  перед комітом, або коли просять "/review", "перевір код", "зроби ревʼю".
```

Claude Code's LLM-level skill routing reads that description. When the user
typed `/review`, the LLM saw the literal string `/review` in the trigger
phrase and activated the root skill automatically — regardless of which
namespaced command (`/code-review:code-review`, `/rdk:review`,
`/pr-review-toolkit:review-pr`) the user actually selected from autocomplete.
The visible behavior looked like "the CLI picked the wrong command", but the
mechanism was LLM skill activation, not slash-command resolution.

**Confirmed via the official docs:**
Plugin slash commands are always namespaced (`/plugin:command`). A bare
`/review` never resolves to a plugin command. The `name:` field in
frontmatter only renames the command inside its namespace — it does not
create a global alias. See
https://code.claude.com/docs/en/plugins-reference.md#plugin-manifest-schema
for the manifest behavior and namespacing rules.

**Second finding — Anthropic's code-review plugin writes to PRs:**
The original rule `#A` in this plan said "the rdk plugin writes to PRs and I
don't want that". Session 1 already showed zero `gh pr comment` calls in the
rdk plugin. Session 2 confirmed the real source:
`~/.claude/plugins/cache/claude-plugins-official/code-review/unknown/commands/code-review.md`
has `allowed-tools: Bash(gh pr comment:*)` and step 8 explicitly says
"comment back on the pull request". That plugin is the user's `code-review`
entry in `enabledPlugins`. Rule `#A` for the rdk plugin remains (never post
to PRs), but the user's PR-write frustration is about the Anthropic plugin,
not rdk.

**Third finding — root vs plugin versions of shared files:**

Session 2 diffed the files that exist in both `~/.claude/` and the plugin.
Plugin versions are strictly newer and richer:

| File | Root version | Plugin version |
|---|---|---|
| `agents/code-reviewer.md` | Ukrainian hardcoded, `sonnet` | `opus`, inherit language, full project context |
| `agents/architect.md` | Ukrainian hardcoded, `sonnet` | `opus`, `permissionMode: plan`, inherit language |
| `skills/task-workflow/SKILL.md` | 177 lines | 444 lines |
| `skills/rails-specialist/SKILL.md` | 309 lines | 546 lines |
| `skills/typescript-react/SKILL.md` | 347 lines | 549 lines |

Root-level is a frozen snapshot from an older iteration. Plugin is the
evolved version (Session 1 inherit-language updates + earlier work).
**Unique in root-level (NOT in plugin)**: `skills/ai-chatbot/` and
`agents/workflow-companion.md`. These must be preserved.

**Fourth finding — marketplace cache still holds v1.0.1:**
`~/.claude/plugins/marketplaces/rdk-marketplace/` is a dormant copy of the
plugin at v1.0.1. It is not in `enabledPlugins`, so it should not load, but
it has its own `skills/code-review/SKILL.md` with the same `/review` trigger
phrases. Safest action: remove this directory after the user reinstalls the
plugin from GitHub at v1.0.2+.

**Fifth finding — `agents:` field is NOT required in `plugin.json`:**
Official docs state that if `agents:` is omitted from the manifest, Claude
Code auto-scans the default `./agents/` directory. The existing
`plugin.json` (which declares `commands` and `skills` but not `agents`) is
fine — agents load automatically.

---

#### Session 2 changes (complete in working dir, not yet committed)

1. **Disabled the root-level `code-review` skill** by renaming the directory
   and then the file:
   - `~/.claude/skills/code-review/` → `code-review.backup-2026-04-07/`
   - Inside backup: `SKILL.md` → `SKILL.md.disabled`
   - Reason: Claude Code reads `name:` from frontmatter, not from folder
     name, so renaming the folder alone wasn't enough. Renaming the file
     makes Claude Code's `SKILL.md` auto-discovery miss it.
   - This is a reversible `mv`, not `rm`. Revert with one command.

2. **Removed `name:` fields from all 5 plugin commands** to match the
   Anthropic-plugin style:
   - `commands/execute.md`, `help.md`, `next.md`, `plan.md`, `review.md`
   - The filename drives the command name. Before: `name: review` +
     `description`. After: only `description`.
   - Cosmetic change, no functional effect on namespacing.

3. **Plan file updated** (this section).

Not yet done in Session 2:
- Delete `~/.claude/agents/code-reviewer.md`, `architect.md`
- Delete `~/.claude/skills/task-workflow/`, `rails-specialist/`, `typescript-react/`
- Delete `~/.claude/plugins/marketplaces/rdk-marketplace/`
- Commit + push Session 1 + Session 2 changes to a feature branch
- Install the plugin from GitHub via marketplace so future sessions work
  without `--plugin-dir`

---

#### Remaining steps for #B (new ordering after Session 2)

The test at Step 5 **failed** in Session 2 — but for a reason that was
correctly diagnosed and partially fixed within that session. New
ordering:

**Step 5a — DONE (Session 2):** Disable the root `code-review` skill, clean
`name:` fields in plugin commands. Verified that `code-review` skill no
longer appears in Claude Code's skill list after the file rename.

**Step 5b — Next session:** Commit Session 1 + Session 2 changes to a
feature branch in the plugin repo, push to GitHub.

**Step 5c — Next session:** Install the plugin via marketplace so that
`enabledPlugins` includes `rdk@rdk-marketplace` and the plugin loads
without `--plugin-dir`. This will refresh the marketplace cache to v1.0.2+.

**Step 5d — Next session:** Start a fresh Claude session without
`--plugin-dir` and verify `/rdk:review`, `/rdk:plan`, the agents, and the
skills all load through the marketplace path.

**Step 6 (rewritten) — Delete root-level duplicates** (only after 5d passes):
- `~/.claude/skills/code-review.backup-2026-04-07/` (already disabled,
  delete for cleanup)
- `~/.claude/skills/task-workflow/` (plugin has better version)
- `~/.claude/skills/rails-specialist/` (plugin has better version)
- `~/.claude/skills/typescript-react/` (plugin has better version)
- `~/.claude/agents/code-reviewer.md` (plugin has better version)
- `~/.claude/agents/architect.md` (plugin has better version)
- `~/.claude/plugins/marketplaces/rdk-marketplace/` — dormant cache, will
  be recreated fresh at v1.0.2+ during marketplace install

**Keep in root-level (unique to root, not in plugin):**
- `~/.claude/skills/ai-chatbot/`
- `~/.claude/agents/workflow-companion.md`

**Step 7 — Git commit on a feature branch** (only with explicit user approval):
- Create branch: `git checkout -b feature/english-refactor-session-1`
- Commit Session 1 changes
- Do NOT push without approval

Once #B is fully verified, move on to #A (block PR writes, see discovery #2
for the clarified scope) and #C (output format with Critical/High + QA
instructions).

---

### #C. ✅ New output format: Critical + High focus, QA test instructions

> **Status:** DONE in Session 3 part 2 (2026-04-07). See "Session 3 part 2 summary" at the end of this file for full details, decisions, and next steps.

**Why P0:** This is the biggest UX change. Must be done before #1 (splitting agents) — otherwise we'd rewrite output structure twice.

**Phase 1 — Analysis tasks:**
- Read current output template in `agents/code-reviewer.md` (lines 159-232)
- Find any existing `code-review.md` files from past reviews to see real-world output
- Identify what's good in current format and what changes
- Map current 🔴/🟡/🟢 severity to new structure

**Phase 2 — Design:**

**Proposed new output structure:**

```markdown
# Code Review
Date: YYYY-MM-DD
Reviewer: rdk-claude-plugin
Branch/PR: ...

## Verdict: 🔴 Blocked / 🟢 Approved

## Summary table
| Severity | Count |
|---|---|
| 🔴 Critical | N |
| 🟠 High | N |
| 🟡 Medium | N (see bottom) |
| 🟢 Low/Suggestion | N (see bottom) |

## Quality checks
| Check | Status |
|---|---|
| RSpec | ✅/❌ |
| TypeScript | ✅/❌ |
| ESLint | ✅/❌ |
| Jest | ✅/❌ |
| Hasura consistency | ✅/❌ |

═══════════════════════════════════════════
# 🔴 CRITICAL ISSUES (must fix before merge)
═══════════════════════════════════════════

## 1. [Short title]
**File:** `path/to/file.rb:42`
**What's wrong:** [plain explanation, no jargon]
**Why it matters:** [user impact / data risk / security]

### How to test (for QA)
**What we're checking:** [one sentence]
**Steps:**
1. [Manual step in plain language]
2. [Manual step]
3. [Manual step]
**Expected result:** [what should happen]
**Bug behavior:** [what actually happens because of this issue]
**Verdict:** ☐ Confirmed bug ☐ Cannot reproduce ☐ Not a bug

### Suggested fix (for Dev)
```diff
- broken code
+ fixed code
```

═══════════════════════════════════════════
# 🟠 HIGH PRIORITY ISSUES (should fix before merge)
═══════════════════════════════════════════

[Same structure as Critical]

═══════════════════════════════════════════
# Additional notes (for developer reference)
═══════════════════════════════════════════

## 🟡 Medium issues
- `file.rb:10` — [one-line description]
- `file.tsx:25` — [one-line description]

## 🟢 Low / Suggestions
- `file.rb:5` — [one-liner]
- ...
```

**QA test instruction templates by issue type** (this is the hard part — different bug types need different test approaches):

| Issue type | QA test approach |
|---|---|
| **UI bug** | Click steps, visual verification |
| **N+1 query** | "Open page X. Open browser dev tools → Network tab. Look for `/graphql` request. Check the response time — should be under 500ms. If you see it loading for several seconds, this is the bug." |
| **Multi-tenant leak** | "Login as user from Company A. Go to URL with Company B's project ID. Check if you see the data — you should NOT." |
| **Missing validation** | "Fill the form with [bad value]. Try to submit. Should see an error. If form submits successfully, this is the bug." |
| **Permission bypass** | "Login as Reader role user. Try to do [action]. Should be blocked. If allowed, this is the bug." |
| **Memory leak / perf** | "Open page. Use it for 5 minutes doing [action]. Browser should not slow down. If it does, this is the bug." |

We'll refine these templates with the user during the design phase.

**Phase 3 — Implementation:**
- Edit `agents/code-reviewer.md` — rewrite entire "Output Format" section (lines 159-232)
- Add QA test instruction examples and templates
- Add explicit instruction: "Write test steps in plain language. Imagine the reader has never seen the codebase. No `curl`, no `rspec`, no shell commands — only browser actions and observations."

**Phase 4 — Testing:**
- Run on a real PR with known bugs
- Show output to user
- Have user pretend to be QA and follow the steps — do they make sense?

**Phase 5 — Verification:** User confirms the format works for a non-dev reader.

**Open questions for design phase:**
- For non-UI issues that genuinely cannot be tested manually (e.g., race condition in background job), do we still try to provide steps, or mark as `[Dev verification only]`?
- How verbose should each issue be? Trade off between thoroughness and overwhelming QA.

---

## P1 — High-impact improvements (after P0 done)

### #1. ❌ Split monolithic `code-reviewer` into specialized sub-agents (REJECTED)

> **Status:** REJECTED in Session 3 part 5 (2026-04-07) after senior judgment Analysis. Splitting would be net negative for this plugin given Session 3 improvements: Step 0.5 auto-detect already skips irrelevant layers, Step 7 Multi-Tenant Audit needs holistic view across layers, real Acuity PRs touch 1-2 layers max (0 PRs in last 2 weeks touched all 4 layers). See "Session 3 part 5 summary" at the end of this file for full reasoning.

**Why P1, not P0:** Big refactor. Should happen AFTER output format (#C) is locked. Also requires senior judgment — may not be needed at all.

**Phase 1 — Analysis tasks (this is the most important phase for this point):**
- **Senior question:** Is splitting actually necessary? Read pr-review-toolkit's split agents — are they actually better in practice, or just more fragmented?
- Sample 3-5 of user's recent Acuity PRs. Count files per layer. How many PRs touch all 4 layers vs single layer?
- Test current monolithic agent on a complex PR — does it actually "lose focus" on later layers, or is that my assumption?
- Check: how does Claude Code currently handle multiple parallel `Agent` calls? Has the harness changed since the plugin was written (Feb 2026)?
- Calculate token cost: 1 monolithic Opus call vs 5 parallel Opus calls — is the cost difference acceptable for the user?

**Phase 2 — Design (only if Analysis confirms split is worth it):**

Three options:

| Option | Structure | Pros | Cons |
|---|---|---|---|
| **A. By layer (5 agents)** | rails / hasura / frontend / security / test-coverage | Best focus, easiest to extend | Most token cost, more files |
| **B. 3 broader agents** | backend (rails+hasura) / frontend / security | Balanced | Less paralllelism |
| **C. By problem type** | correctness / security / tests / style | Different perspective per agent | Less intuitive, harder to maintain |

**Senior consideration:** If Analysis shows that current monolithic agent works well 80% of the time, we should NOT split. Splitting introduces complexity. Only justify if there's measurable improvement.

**Conditional execution principle (key):** Whichever option is chosen — only run sub-agents whose layer has changes. If `git diff` doesn't touch `hasura/`, don't spawn `hasura-reviewer`.

**Phase 3 — Implementation:**
- Create new agent files OR refactor existing one
- Update orchestrator (`commands/review.md`) to spawn agents in parallel
- Aggregate sub-agent outputs into single `code-review.md`

**Phase 4 — Testing:**
- Run on small PR (1 layer) — verify only relevant agent runs
- Run on big PR (all layers) — verify parallelism works, results aggregate correctly
- Compare output quality vs old monolithic version

**Phase 5 — Verification:** User compares before/after on a real review.

**Decision point:** I will be honest in Phase 1 if I think we should NOT do this. Senior judgment > sunk cost.

---

### #2. ✅ Anti-hallucination guardrails in agent prompt

> **Status:** DONE in Session 3 part 3 (2026-04-07). 5 new anti-hallucination rules added to the Rules section of `agents/code-reviewer.md`. See "Session 3 part 3 summary" at the end of this file.

**Why P1:** Cheap, high-impact, makes every other improvement more reliable.

**Phase 1 — Analysis tasks:**
- Read current prompt for "fluff invitations" — places where the prompt encourages the agent to find problems even when there are none
- Look at past `code-review.md` outputs (if any) for examples of likely hallucinated issues
- Read pr-review-toolkit's anti-hallucination patterns

**Phase 2 — Design:**
Add hard rules to agent prompt:
```
ANTI-HALLUCINATION RULES (mandatory):
1. NEVER report an issue without an exact quote from the diff (file:line)
2. If unsure about business logic — use ❓ Question, not 🔴 Issue
3. Before marking 🔴 Critical — Read the original file (not just diff) to confirm context
4. NEVER manufacture issues to justify your existence
5. If everything is good — say so. Empty review > fake review.
6. Use exact quoted code, not paraphrase
7. If a "potential" issue depends on assumption X, state assumption X explicitly
```

**Phase 3 — Implementation:** Edit `code-reviewer.md` prompt.

**Phase 4 — Testing:** Run on a clean PR (no real bugs). Verify it returns "Approved" instead of inventing issues.

**Phase 5 — Verification:** User runs on 3-5 real PRs over a week and confirms hallucination rate dropped.

---

### #3. ✅ Diff-first context loading

> **Status:** DONE in Session 3 part 3 (2026-04-07). New Step 2.5 "Context loading strategy (diff-first)" added to `agents/code-reviewer.md` with a 4-tier hierarchy. See "Session 3 part 3 summary" at the end of this file.

**Why P1:** Reduces token cost, focuses agent attention.

**Phase 1 — Analysis tasks:**
- Read current agent — does it Read full files or just diff?
- Identify when full-file context is actually needed vs when diff is enough
- Token cost estimate: full file read vs targeted Read with offset/limit

**Phase 2 — Design:**
Three-tier context strategy:
1. Start with `git diff` only
2. If diff is suspicious / unclear → `Read` file with `offset/limit` around changed lines
3. Only if logic is fundamentally unclear → `Read` whole file

Add to prompt: "Default to diff. Read files only when diff is insufficient. Never read whole file unless logic spans more than 100 lines."

**Phase 3 — Implementation:** Update agent prompt.

**Phase 4 — Testing:** Compare token usage before/after on same PR.

**Phase 5 — Verification:** User confirms speed/cost improvement without quality loss.

---

## P2 — Medium-impact improvements

### #4. ✅ PR mode (review by PR number)

> **Status:** DONE in Session 3 part 3 (2026-04-07). Implemented as `/rdk:review <PR-number>`. Branch and commit-range modes were NOT implemented (user explicitly opted for the simplest possible UX: only positional PR number, no flags, no branch mode). See "Session 3 part 3 summary" at the end of this file.

**Why P2:** Useful but not blocker. Comes after core review quality is fixed.

**Phase 1 — Analysis tasks:**
- Current command only does `git diff` (unstaged + staged)
- User often wants to review a specific PR by number, or compare branches
- Check `gh pr diff` syntax and capabilities

**Phase 2 — Design:**
```bash
/rdk:review                   # default: unstaged + staged
/rdk:review --pr 1234         # gh pr diff 1234
/rdk:review --branch foo      # git diff staging...foo
/rdk:review --commits 3       # last 3 commits
/rdk:review --since 2d        # changes in last 2 days
```

Pick command syntax: flags vs positional args.

**Phase 3 — Implementation:** Update `commands/review.md` to parse args, update agent prompt to accept scope parameter.

**Phase 4 — Testing:** Test all 4 modes.

**Phase 5 — Verification:** User uses each mode at least once.

---

### #6. ✅ Incremental review (focus on changes since last review)

> **Status:** DONE in Session 3 part 4 (2026-04-07) as **soft version**. No timestamp suffix, no backups — instead agent detects previous review file by filename lookup and adds optional "Changes since last review" section in output. Preserves `#C` overwrite simplicity. See "Session 3 part 4 summary".

**Why P2:** Saves time on iterative review cycles (QA → fix → re-review).

**Phase 1 — Analysis tasks:**
- How is `code-review.md` currently saved? Timestamped or overwritten?
- What's the user's actual iteration pattern — do they re-review after fixing?

**Phase 2 — Design:**
- Save reviews with timestamp: `code-review-2026-04-07-1430.md`
- On re-run: detect previous review, focus diff on "changes since last review"
- Output section: "Changes since last review"

**Phase 3 — Implementation:** Update agent + commands.

**Phase 4 — Testing:** Run review → make changes → re-run → verify focus on new changes.

**Phase 5 — Verification:** User uses iteration cycle and confirms.

---

### #7. ✅ Run quality checks in parallel

> **Status:** DONE in Session 3 part 4 (2026-04-07). Step 2 default mode now explicitly instructs the agent to "launch all checks in PARALLEL via multiple Bash tool calls in one message". ~3x faster. See "Session 3 part 4 summary".

**Why P2:** Pure performance improvement.

**Phase 1 — Analysis tasks:**
- Current code runs `rspec → tsc → lint → jest` sequentially
- Measure current total time on user's machine
- Verify Bash `run_in_background: true` works in agent context

**Phase 2 — Design:**
- Spawn all 4 checks in parallel via `run_in_background: true`
- Wait for all, then aggregate results
- Show streaming progress if possible

**Phase 3 — Implementation:** Edit agent's "Run Quality Checks" section.

**Phase 4 — Testing:** Compare time before/after.

**Phase 5 — Verification:** User confirms speed improvement.

---

### #8. ✅ Multi-tenant audit as separate dedicated section

> **Status:** DONE in Session 3 part 4 (2026-04-07). New Step 7 in `code-reviewer.md` with explicit Rails/Hasura/Frontend checklist + new "Multi-Tenant Audit" section in the Output Format template (always present). See "Session 3 part 4 summary" at the end.

**Why P2:** In Acuity multi-tenant violations are critical but currently get lost in general Rails checks.

**Phase 1 — Analysis tasks:**
- Read current multi-tenant checks in agent prompt
- Look at past PRs with multi-tenant issues — were they caught?
- Define what "multi-tenant audit" should specifically check

**Phase 2 — Design:**
Add dedicated section "Multi-Tenant Audit" with explicit checks:
- Does every Rails endpoint scope by `current_user.company_id`?
- Does every Hasura permission filter contain access_groups chain?
- Do request specs verify "other company cannot see data"?
- Are there any direct ID lookups without ownership check?

Output as separate section in `code-review.md` even if no issues found.

**Phase 3 — Implementation:** Edit agent prompt + output template.

**Phase 4 — Testing:** Run on PR known to touch multi-tenant code.

**Phase 5 — Verification:** User confirms it catches issues he'd worry about.

---

## P3 — Polish

### #11. ✅ Configurable rules via `.rdk-review.json`

> **Status:** DONE in Session 3 part 4 (2026-04-07). New Step 0.5 in `code-reviewer.md` reads `.rdk-review.json` from project root. Schema: `checks`, `severity_overrides`, `custom_rules`, `ignore_files`. Graceful fallback on missing/malformed. Documented in README. See "Session 3 part 4 summary".

**Why P3:** Nice-to-have. Important for sharing with other developers.

**Phase 1 — Analysis tasks:**
- What's hard-coded today that should be configurable?
- What patterns vary across Acuity vs other projects?
- Format: JSON, YAML, Ruby DSL?

**Phase 2 — Design:**
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
    "any_type": "high"
  },
  "custom_rules": [
    { "pattern": "console\\.log", "severity": "high", "message": "Debug code" }
  ],
  "ignore_files": ["**/*.test.ts"]
}
```

**Phase 3 — Implementation:** Add config loader to agent prompt, document in README.

**Phase 4 — Testing:** Test with custom config.

**Phase 5 — Verification:** User creates own config and confirms it works.

---

## P4 — For sharing with other developers

### #13. ✅ Universal core vs Acuity-specific split

> **Status:** DONE in Session 3 part 4 (2026-04-07) as **soft version**. No full skill split — instead: (1) auto-detect tech stack in Step 0.5, (2) `.rdk-review.json` overrides, (3) README section "Using with non-Acuity projects". Full skill split deferred until there's a real non-Acuity user. See "Session 3 part 4 summary".

**Why P4:** Required before sharing publicly. Last because it's a big restructure.

**Phase 1 — Analysis tasks:**
- Map every Acuity-specific reference in the plugin
- Identify what's universal Rails / universal React / universal Hasura
- Decide split strategy

**Phase 2 — Design:**
```
skills/
├── code-review-core/        ← universal: git diff parsing, severity, output format
├── code-review-rails/       ← Rails-generic checklist
├── code-review-react/       ← React-generic checklist
├── code-review-hasura/      ← Hasura-generic checklist
└── code-review-acuity/      ← Acuity-specific: ApiController, access_groups
```

**Phase 3 — Implementation:** Big refactor. Done in sub-steps.

**Phase 4 — Testing:** Test on Acuity project (full stack). Test on a non-Acuity Rails project (if available).

**Phase 5 — Verification:** Another developer installs plugin and confirms it works for them.

---

### #14. ✅ Auto-detect tech stack

> **Status:** DONE in Session 3 part 4 (2026-04-07). Part of the combined Step 0.5 with `#11`. Checks for `Gemfile` (Rails), `package.json` (JS/TS), `hasura/` (Hasura). Skips stack-specific quality checks and review steps for absent stacks. See "Session 3 part 4 summary".

**Why P4:** Pairs with #13. Plugin should detect what stack the user has and only enable relevant checks.

**Phase 1 — Analysis tasks:**
- Detection markers: `Gemfile` → Rails, `package.json` → JS, `hasura/` → Hasura
- How to make detection part of agent startup

**Phase 2 — Design:** Detection logic at start of `code-reviewer` execution. Activates only relevant sub-checklists.

**Phase 3 — Implementation:** Add detection logic.

**Phase 4 — Testing:** Test on multiple project types.

**Phase 5 — Verification:** User confirms detection is correct.

---

### #15. ✅ README with output examples

> **Status:** DONE in Session 3 part 4 (2026-04-07). Major README expansion with 6 new sections: Installation, Configuration, What you get, Team workflow (dev→QA→lead), Using with non-Acuity projects, Review modes. Plus updated Commands table with `/rdk:review [PR number]`. See "Session 3 part 4 summary".

**Why P4:** Adoption barrier — other devs need to see what they get.

**Phase 1 — Analysis tasks:**
- Current README explains architecture but no output examples
- Other plugins' READMEs — what makes them appealing?

**Phase 2 — Design:**
Add sections to README:
- "What you get" — example `code-review.md` output
- "Workflow" — Dev → QA → Lead diagram
- "Installation" — step-by-step
- "Configuration" — how to override defaults

**Phase 3 — Implementation:** Edit README.

**Phase 4 — Testing:** N/A.

**Phase 5 — Verification:** User and one other developer read it and confirm it's clear.

---

## Removed points (from original 15)

These were in the original list but removed after user's three rules:

- ❌ **#5. Severity calibration with 🔴/🟡/🟢 rubric** → Replaced by #C (only Critical/High up top, Medium/Low at bottom). Severity definitions still needed but inside #C.
- ❌ **#9. Auto-fix mode** → Conflicts with #C (auto-fix is mostly cosmetic issues which user explicitly de-prioritized).
- ❌ **#10. GitHub PR integration via `gh pr review`** → Directly conflicts with #A (no PR posting).
- ❌ **#12. "Quick wins" section** → Conflicts with #C (quick wins are usually small/cosmetic).

---

## Execution order summary

```
P0 (do first, in order):
  #B → #A → #C
  (#B is fastest and removes daily friction; #A is fast cleanup; #C is the big UX change)

P1 (high-impact core improvements):
  #2 → #3 → #1
  (#2 anti-hallucination is cheapest; #3 diff-first is also cheap; #1 splitting agents is the big senior judgment call)

P2 (medium):
  #8 → #4 → #7 → #6

P3 (polish):
  #11

P4 (sharing-readiness):
  #13 → #14 → #15
```

Total: **14 points** (3 new + 11 from original 15)

---

## Working agreement

1. **One point at a time.** Never start point N+1 until point N is verified.
2. **Five phases per point.** Analysis → Design → Implementation → Testing → Verification.
3. **No code changes without approval.** Show design first, get user nod, then implement.
4. **Honest senior judgment.** If a point shouldn't be done, say so. Don't sunk-cost reasoning.
5. **Communication language follows the user** (agents inherit language from task description). Code, docs, plans, commits, and file names are always in English.
6. **No git push, no commits, no migrations** without explicit user approval (per user's stop-list).
7. **Plan file is the source of truth.** Update statuses as we go. This file survives compact.

---

## Next action when we resume

**Current status (as of end of Session 3, 2026-04-07):**
- ✅ **#B is 100% DONE.** Plugin published to GitHub `main` at v1.0.2,
  installed via marketplace, root-level duplicates deleted. Verified
  clean state of `~/.claude/skills/` and `~/.claude/agents/`.
- ✅ **#A is DONE.** Session 3 closed it with Soft minimum: one
  blockquote paragraph in `README.md` preamble declaring the plugin
  read-only. Strict whitelist and Forbidden-block options were rejected
  after senior re-assessment. See "Session 3 resolution" block under #A
  for full reasoning. README change is committed-pending.
- ✅ **#C is DONE.** Session 3 part 2 closed it with the full new
  output format: dual-audience (For Dev English / For QA Ukrainian),
  Verdict + Summary table at the top, Critical/High blocks with manual
  test steps and verdict checkbox, Medium/Low as one-liners at the
  bottom. Output saved to `docs/code-review/[YYYY-MM-DD]-[branch-slug].md`
  in each project. See "Session 3 part 2 summary" at the end for details.
  **Awaiting Phase 4 testing** via `claude --plugin-dir`.
- ✅ **#2, #3, #4 are DONE.** Session 3 part 3 closed all three together
  as the "PR-aware code review" package: PR mode (`/rdk:review 5190`),
  diff-first context loading (4-tier hierarchy), and anti-hallucination
  guardrails (5 new Rules). See "Session 3 part 3 summary" at the end.
  **Awaiting Phase 4 testing** — user can now run `/rdk:review 5190` on a
  real Acuity PR to verify all four (#C + #4 + #3 + #2) end-to-end.
- ✅ **#8, #7, #6, #11, #14, #13, #15 are DONE.** Session 3 part 4 closed
  the entire P2/P3/P4 roadmap at once (on user request — "зроби все, потім
  я протестую це все разом"). See "Session 3 part 4 summary" at the end
  for the full list of files changed, design decisions, and rejected
  alternatives. **Awaiting Phase 4 testing for everything at once.**
- ❌ **#1 is REJECTED (formal closure).** Session 3 part 5 (2026-04-07)
  closed it as NOT TO DO after senior judgment Analysis. Splitting into
  5 sub-agents would be net negative for this plugin: Step 0.5 auto-detect
  already skips irrelevant layers, Step 7 Multi-Tenant Audit needs holistic
  view across layers, real Acuity PRs touch 1-2 layers max (0 PRs in last
  2 weeks touched all 4 layers). See "Session 3 part 5 summary" for full
  reasoning. **The plan anticipated this outcome** — line 87 explicitly
  says "I will be honest in Phase 1 if I think we should NOT do this.
  Senior judgment > sunk cost."
- ✅ **All 14/14 points formally closed.** Plan = 13 implemented + 1
  explicitly rejected with documented reasoning. Roadmap complete.
  **Awaiting Phase 4 testing** for the 13 implemented points.

### How to resume

**Step 1** — Start a fresh Claude Code session in any project, **WITHOUT**
`--plugin-dir`. The plugin now loads from marketplace install:

```bash
cd ~/Work/acuity_org/acuity
claude
```

**Step 2** — In the new session, paste this exact prompt:

```
Прочитай ~/Work/rdk-claude-plugin/docs/plans/2026-04-07-code-review-improvements/plan.md.
#B повністю завершений (Sessions 1+2). Переходь до #A — Block all GitHub
PR writes from the plugin.

Контекст для #A: rdk плагін НЕ робить gh pr comment (Sessions 1+2 це
підтвердили — zero matches). Реальний винуватий — Anthropic
code-review@claude-plugins-official плагін. Тому #A для rdk плагіна — це
defensive measure: документально зафіксувати "цей плагін НІКОЛИ не пише в
PR" у README, у agent prompts (особливо code-reviewer та architect), і
можливо обмежити Bash whitelist у frontmatter code-reviewer агента щоб
заблокувати gh pr comment / gh pr review / gh issue create / gh pr edit
на рівні tool permissions.

Працюй за п'ятьма фазами: Analysis → Design → Implementation → Testing →
Verification. Питай мене перед кожною зміною коду. Один пункт за раз. Не
комічуй і не пушай без явного дозволу.
```

**Step 3** — Sanity-перевірка перед початком #A (агент має зробити):
- `claude plugin list` → переконатись що `rdk@rdk-marketplace ✔ enabled` v1.0.2
- `ls ~/.claude/skills/` → має бути тільки `ai-chatbot/`
- `ls ~/.claude/agents/` → має бути тільки `workflow-companion.md`
- Якщо все ок — починати #A Phase 1 (Analysis)

### Session 1 summary (for quick reference)

Files changed in the plugin (committed in `6460efd`):
- `agents/code-reviewer.md`, `agents/architect.md`, `agents/rails-researcher.md`,
  `agents/hasura-researcher.md`, `agents/typescript-deriver.md`,
  `agents/react-planner.md` — "inherit language" instruction
- `skills/code-review/` — **deleted** (was wrapper around code-reviewer agent)
- `README.md`, `commands/help.md` — removed code-review skill row from tables
- `DEV.md` — **new file** documenting `--plugin-dir` workflow

### Session 2 summary (for quick reference)

In working-dir plugin (committed in `6460efd` on `main`):
- `commands/execute.md`, `help.md`, `next.md`, `plan.md`, `review.md` —
  removed `name:` frontmatter field (matches Anthropic plugin style)
- `.gitignore` — new, excludes `.claude/` personal dev settings
- `docs/plans/2026-04-07-code-review-improvements/plan.md` — appended
  Session 1 + Session 2 discoveries, updated #B status to ✅ DONE

Git workflow done in Session 2:
- Branch `feature/english-refactor-session-1` → fast-forward merged into `main`
- Pushed `main` to `origin/main` (commit `6460efd`)
- `claude plugin marketplace update rdk-marketplace` — refreshed cache to v1.0.2
- `claude plugin install rdk@rdk-marketplace` — installed, `enabledPlugins`
  now contains `rdk@rdk-marketplace: true`

### Session 3 summary (for quick reference)

Files changed in the plugin (commit pending):
- `README.md` — 3-line blockquote added in preamble:
  "Read-only by design. All review output ... never posts to GitHub
  PRs, issues, or any external system."

Decisions made in Session 3:
- `#A` resolved as **Soft minimum** (README policy only)
- Strict tool whitelist for agents — **rejected** (would harm analysis)
- Forbidden-block in 6 agent prompts — **rejected** (prompt bloat for
  zero benefit, README policy is sufficient documentation layer)

Plan file changes in Session 3:
- `#A` status: `📋` → `✅`
- "Session 3 resolution" block added under #A with full senior reasoning
- "Current status" updated to show #A done
- This Session 3 summary added

What's next: **#C** — DONE in Session 3 part 2 (see below).

### Session 3 part 2 summary (for quick reference)

**Files changed in this session (commit pending):**

- `agents/code-reviewer.md` — major rewrite:
  - **Added Step 0** to "Review Process" — determines output file path
    via `git rev-parse --abbrev-ref HEAD`, builds slugified path
    `docs/code-review/[YYYY-MM-DD]-[branch-slug].md`, handles edge cases
    (detached HEAD → `detached`, missing dir → `mkdir -p`, repeat run →
    overwrite)
  - **Replaced old single-audience Output Format** (lines 159-232 in old
    file) with new dual-audience format including: Where to save section,
    Audience description, Severity rules table, Verdict logic, Language
    policy, full Template with `### 👨‍💻 For Dev` and `### 🧪 For QA`
    subsections, Verdict checkbox, QA test instruction guidelines per
    issue type
  - **Expanded Rules** with 5 new QA-specific requirements (dual-audience
    mandatory on Critical/High, Ukrainian for QA section, no shell
    commands in QA, verdict checkbox mandatory, Medium/Low as one-liners)
- `~/Work/acuity_org/acuity/.gitignore` — added `docs/code-review/` line
  next to existing `docs/plans/` (consistent with existing AI workflow
  scratchpad pattern). **This is in the acuity repo, not the plugin.**
- `plan.md` — this Session 3 part 2 update + #C status flip + current
  status update

**Key design decisions made in Session 3 part 2:**

| Aspect | Decision |
|---|---|
| Output path | `docs/code-review/[YYYY-MM-DD]-[branch-slug].md` |
| Slug rule | `/` → `-`, otherwise as-is |
| Repeat behavior | Overwrite without prompting |
| Branch detection | `git rev-parse --abbrev-ref HEAD`, fallback `detached` |
| Date format | ISO 8601 (`YYYY-MM-DD`) — sort-friendly |
| Persistence | `.gitignore`d — personal/local artifact, not committed |
| Audience structure | Dual: For Dev (English, technical) + For QA (Ukrainian, manual steps) |
| Verdict checkbox | 4 options on every Critical/High issue |
| Medium/Low format | One-liner bullets at the bottom, no dual-audience |
| Language mix | English for tech/headings, Ukrainian for QA section content |
| Verdict logic | Any Critical → Blocked; Only High → Changes Needed; Only Med/Low → Approved; Any quality check fail → auto-Blocked |

**Rejected (and why):**

- **Adding "How the reviewer worked" / timeline / version footer to the
  output** — feature creep. User explicitly said "це все" (no additions).
  Mininalism principle.
- **`/rdk:review --branch foo` argument** — not needed. Default branch
  detection via `git rev-parse` is enough. Can be added later in #4 (PR
  mode) if there's demand.
- **Persistence with timestamp suffix for same-day reruns** — overcomplicated.
  Overwrite is cleaner; latest state is always the relevant one.
- **Slack/email mentions in README policy (from #A)** — narrowing the
  trust statement. "any external system" is broader and clearer.

**Next: Phase 4 — Testing.**

Start a new Claude Code session with the working-dir plugin loaded
explicitly:

```bash
cd ~/Work/acuity_org/acuity   # or any project with real changes
claude --plugin-dir ~/Work/rdk-claude-plugin
```

In the new session:
1. Verify `/rdk:review` command exists and uses the new agent
2. Run `/rdk:review` on the current branch (e.g. `ro-resources-subcategories`)
3. Check that:
   - File `docs/code-review/2026-04-07-ro-resources-subcategories.md` is created
   - File contains Verdict + Summary + Quality Checks at the top
   - Critical/High issues (if any) have BOTH For Dev (English) and For QA (Ukrainian) subsections
   - Verdict checkbox is present on Critical/High issues
   - Medium/Low (if any) are one-liner bullets at the bottom
4. If the format is broken or unexpected — return here, fix, re-test

After live test passes:
- Commit both repos (rdk-plugin + acuity .gitignore line)
- Bump `plugin.json` version to 1.0.3
- Push to GitHub
- `claude plugin marketplace update rdk-marketplace` to refresh cache
- Future sessions will use the new version without `--plugin-dir`

**What's next after #C verification:** #2, #3, #4 — DONE in Session 3
part 3 (see below).

### Session 3 part 3 summary (for quick reference)

**Files changed in this session (commit pending):**

- `agents/code-reviewer.md` — 4 major edits:
  - **Step 0 expanded** — added review mode awareness (default vs PR mode),
    PR mode slug rule (`pr-<num>`), examples for both modes
  - **Step 1 expanded** — conditional scope detection: default uses
    `git diff`, PR mode uses `gh pr view` + `gh pr diff`. Explicit warning
    not to `Read` local files in PR mode (wrong version)
  - **Step 2 expanded** — Quality Checks now mode-aware: default runs
    local toolchain (rspec/tsc/lint/jest/hasura), PR mode uses
    `gh pr checks <num>` as primary with explicit fallback policy
    (skip + document, never run local for PR mode)
  - **Step 2.5 added** — new section "Context loading strategy (diff-first)"
    with 4-tier hierarchy: diff only → diff + targeted Read → diff + full
    Read → `gh api` fallback. Explicit "When NOT to read full files" list
  - **Rules expanded** — reorganized into "Reporting issues
    (anti-hallucination)" and "Output format" subsections. Added 5 new
    anti-hallucination rules: never manufacture issues, exact quotes only,
    state assumptions explicitly, ❓ Question for unverifiable cases,
    "empty review > fake review" promoted to rule #1
- `commands/review.md` — major rewrite from 15 lines to ~50:
  - Added `argument-hint: "[PR number, optional]"` frontmatter for autocomplete
  - Added "Determine review mode" section with explicit parsing rules
  - Documented how to call `code-reviewer` subagent with mode-specific
    task descriptions
  - Added Examples section
  - Plan discovery is now optional in PR mode
- `plan.md` — this Session 3 part 3 update + #2/#3/#4 status flips

**Key design decisions made in Session 3 part 3:**

| Aspect | Decision |
|---|---|
| Argument syntax | Positional integer only: `/rdk:review` (default) or `/rdk:review 5190` (PR). No flags, no branch mode, no commits mode. |
| PR mode slug | `pr-<number>` (e.g. `pr-5190`) |
| PR mode quality checks | Hybrid: `gh pr checks <num>` primary, skip+document as fallback. **Never run local toolchain in PR mode.** |
| PR mode file context | Diff-only by default. `gh api` at PR head SHA as advanced fallback. |
| Diff-first hierarchy | 4 tiers, cheapest first: diff only → diff+targeted Read → diff+full Read → `gh api` |
| Anti-hallucination rule #1 | Empty review > fake review. NEVER manufacture issues. |
| Branch mode | NOT implemented. User explicitly opted for the simplest UX. |
| Commits mode | NOT implemented. Same reasoning. |
| `--pr <num>` flag | NOT implemented. Positional integer is enough. |

**Rejected (and why):**

- **Branch comparison mode (`/rdk:review --branch foo`)** — user said
  "нема branch mode, мене це влаштовує". Two modes are enough.
- **Commits range mode (`/rdk:review --commits 3`)** — same reasoning.
  Can be added later if there's actual demand.
- **`--pr <num>` flag in addition to positional** — overengineering. One
  way to do PR mode is enough.
- **Splitting #2/#3/#4 into separate releases** — they tightly couple
  (PR mode naturally enforces diff-first; anti-hallucination Rules apply
  to both modes). One release is cleaner and saves a testing cycle.
- **Running local quality checks in PR mode with a warning** — false
  signal harms QA more than missing data does. Skip is the honest answer.
- **Adding `gh pr comment` integration** — directly conflicts with #A
  (no PR writes). Dead idea.

**Next: Phase 4 — Testing.**

Both #C and the #4+#3+#2 package can now be tested in one session:

```bash
cd ~/Work/acuity_org/acuity
claude --plugin-dir ~/Work/rdk-claude-plugin
```

In the new session:

1. **Test default mode:**
   - `/rdk:review` on a branch with real local changes
   - Verify file `docs/code-review/2026-04-07-<branch>.md` is created
   - Verify dual-audience output, severity buckets, verdict checkbox

2. **Test PR mode:**
   - `/rdk:review 5190` (or any open Acuity PR)
   - Verify file `docs/code-review/2026-04-07-pr-5190.md` is created
   - Verify scope comes from `gh pr diff`, not local working tree
   - Verify Quality Checks come from `gh pr checks` (or skipped with warning)
   - Verify the agent did NOT try to read local files for PR review

3. **Test edge cases:**
   - `/rdk:review abc` (invalid argument) → should ask user what they meant
   - `/rdk:review` on a clean working tree → should fall back to last commit
   - `/rdk:review 99999` (non-existent PR) → should fail gracefully

4. **Check anti-hallucination behavior:**
   - On a clean PR (no real bugs), the review should return "🟢 Approved"
     with no fabricated issues
   - Any reported issue must include an exact code quote

After live test passes:
- Commit both repos (rdk-plugin + acuity .gitignore)
- Bump `plugin.json` version to 1.0.3
- Push to GitHub `main`
- `claude plugin marketplace update rdk-marketplace` to refresh cache
- Future sessions will use the new version without `--plugin-dir`

**What's next after this verification:** Per execution order summary,
remaining points are **#1 (split agents — senior judgment call, may NOT
be done)**, then P2 pack (**#8 multi-tenant audit**, **#7 parallel quality
checks**, **#6 incremental review**), then P3 (**#11 configurable rules**),
then P4 (**#13 universal core split**, **#14 auto-detect stack**, **#15
README with examples**).

---

### Session 3 part 4 summary (for quick reference)

**Scope:** User asked to close the remaining roadmap in one go — #8, #7, #6, #11, #13, #14, #15 all done in a single session for later testing as a bundle. #1 (split agents) explicitly excluded per plan's senior judgment note.

**Files changed in this session (commit pending):**

- `agents/code-reviewer.md` — three blocks of changes:
  - **#8 Multi-Tenant Audit** — new **Step 7** (mandatory final pass with per-layer checklist: Rails/Hasura/Frontend). New "Multi-Tenant Audit" section in the Output Format template, placed between Quality Checks and Critical Issues. Always present in output, even when clean — marked N/A for untouched layers.
  - **#7 Parallel quality checks** — Step 2 default mode rewritten. Explicit instruction: "Launch all checks in PARALLEL via multiple Bash tool calls in one message. Do NOT run them sequentially." Rationale embedded: ~3x faster reviews (~2-3 min → ~30-60 sec).
  - **#6 Incremental review detection** — new subsection in Step 1 (default mode only). Detects previous review file via filename lookup (`ls docs/code-review/*-<slug>.md`). If found, `git log --since` to count new commits. Optionally Read the old review file to track fixed vs still-present issues. New "Changes since last review" optional section in Output Format template (included only when previous file exists).
  - **#11 Configurable rules + #14 Auto-detect tech stack (combined)** — new **Step 0.5** "Configuration and tech stack detection" handles both. Reads `.rdk-review.json` from project root (schema: `checks` / `severity_overrides` / `custom_rules` / `ignore_files`). Detects `Gemfile`, `package.json`, `hasura/` to skip stack-specific review steps. Graceful fallback to defaults on missing/malformed config. Config can narrow, not widen (absent stack cannot be force-enabled).

- `README.md` — major expansion with 6 new sections and an updated Commands table:
  - **Updated Commands table** — `/rdk:review [PR number]` entry with default vs PR mode explanation
  - **Installation** — marketplace install + `--plugin-dir` dev workflow + per-project `.gitignore` setup
  - **Configuration (`.rdk-review.json`)** — full schema documentation, field semantics, fallback behavior
  - **What you get** — high-level structure of the output file, key features (dual-audience, severity focus, verdict checkbox, multi-tenant audit, anti-hallucination, persistence)
  - **Team workflow (dev → QA → lead)** — 7-step ASCII workflow diagram explaining the real-world use case
  - **Using with non-Acuity projects** — auto-detect + `.rdk-review.json` + what's still Acuity-specific + future work pointer
  - **Review modes** — table comparing default mode vs PR mode
  - **Net additions:** ~200 lines of user-facing documentation

- `plan.md` — this Session 3 part 4 update + 7 status flips (#8, #7, #6, #11, #13, #14, #15 → ✅) + current status update

**Key design decisions made in Session 3 part 4:**

| Aspect | Decision |
|---|---|
| `#6` Incremental review | **Soft version.** No timestamp suffix, no backup files. Agent detects previous review by filename lookup and adds optional "Changes since last review" section. Preserves `#C` overwrite simplicity. |
| `#7` Parallel quality checks | Agent prompt instruction: "launch all checks in PARALLEL via multiple Bash tool calls in one message". No tool/infra change — relies on Claude Code's existing parallel tool call support. |
| `#8` Multi-tenant audit | **Separate mandatory Step 7** before Output Format. Dedicated section in output even when clean. Cross-references to Critical/High issue numbers. Per-layer checklist. |
| `#11` Configurable rules | `.rdk-review.json` in project root. Schema: `checks`, `severity_overrides`, `custom_rules`, `ignore_files`. Graceful fallback on missing/malformed. |
| `#13` Universal vs Acuity split | **Soft version.** README "Non-Acuity projects" section + reliance on auto-detect + `.rdk-review.json`. No skill file split (`rails-specialist-core` vs `rails-specialist-acuity`). 80% value, 20% effort. |
| `#14` Auto-detect tech stack | Check for `Gemfile`, `package.json`, `hasura/` in Step 0.5. Skip stack-specific checks and review steps for absent stacks. Config can narrow, not widen. |
| `#15` README with examples | 6 new sections, updated Commands table, ~200 lines of user-facing documentation. Focus on the team workflow and adoption path. |
| Combining `#11 + #14` | One Step 0.5 ("Configuration and tech stack detection") instead of two separate steps. Logically coupled — detection provides what **can** work, config decides what **should** work. |

**Rejected (and why):**

- **Full `#13` split** (creating separate `rails-specialist-core/` + `rails-specialist-acuity/` skill files) — overengineering for a plugin with no known non-Acuity user. Soft version captures the adaptability intent without restructure. Revisit when a real non-Acuity user appears.
- **`#6` timestamp suffix for same-day reruns** (e.g. `2026-04-07-1430-branch.md`) — directly conflicts with `#C` overwrite decision. Soft incremental via filename+git log achieves the same goal without fragmentation.
- **`#11` severity override via 1-5 numeric scale** — string levels (`high`/`medium`/`low`) match existing severity labels, more readable.
- **`#14` deeper stack detection** (Python, Go, Rust, etc.) — out of scope. Plugin is tuned for Ruby/JS/Hasura ecosystem. More stacks = more maintenance.
- **Updating skill files** (`rails-specialist`, `hasura-specialist`, `typescript-react`) with "Acuity-specific" headers — cosmetic, unnecessary. README section covers the same information for external users without polluting the skill files themselves.
- **`--skip-quality-checks` flag** for quick reviews — not requested, feature creep. Config `checks: { ... : false }` achieves the same.
- **Separate `#1` (split agents) implementation** — explicitly excluded by user from this session. Plan says "may NOT be done". Revisit only if the monolithic agent fails in Phase 4 testing.

**Plan status after Session 3 part 4:**

| Tier | Done | Remaining |
|---|---|---|
| **P0** | ✅ #A, #B, #C | — |
| **P1** | ✅ #2, #3, #4 | 📋 #1 (split agents — senior judgment, may NOT do) |
| **P2** | ✅ #8, #7, #6 | — |
| **P3** | ✅ #11 | — |
| **P4** | ✅ #13 (soft), #14, #15 | — |

**13 of 14 points done. Only #1 remains — and per plan, it's explicitly marked "may NOT be done" as a senior judgment call. Revisit only if testing shows the monolithic code-reviewer struggles.**

**Next: Phase 4 — Testing EVERYTHING at once.**

The user will run a new Claude Code session with the local plugin loaded:

```bash
cd ~/Work/acuity_org/acuity   # or any project
claude --plugin-dir ~/Work/rdk-claude-plugin
```

And run these tests sequentially:

1. **`#C + #4 + #3 + #2` (PR-aware review):**
   - `/rdk:review 5190` on a real Acuity PR (or any open PR)
   - Verify dual-audience output, PR-mode scope, `gh pr checks` integration, anti-hallucination behavior

2. **`#8 Multi-tenant audit`:**
   - Verify "Multi-Tenant Audit" section appears in output even on clean PRs

3. **`#7 Parallel checks`:**
   - Verify quality checks run in parallel (agent should issue multiple Bash tool calls in one message)

4. **`#6 Incremental`:**
   - Run `/rdk:review` twice on the same branch
   - Verify "Changes since last review" appears on the second run (if the branch has new commits between runs)

5. **`#11 Configurable`:**
   - Drop a `.rdk-review.json` with a `custom_rules` entry (e.g. `{"pattern": "TODO", "severity": "high", "message": "TODO found"}`)
   - Run `/rdk:review` and verify the custom rule is enforced
   - Drop a malformed `.rdk-review.json` and verify graceful fallback

6. **`#14 Auto-detect`:**
   - Temporarily hide `hasura/` directory and see if Hasura checks skip
   - Or test in a non-Acuity project (e.g. a simple Rails-only app)

7. **`#13` + `#15` Documentation:**
   - Read the new README sections, verify they make sense and are accurate

After all tests pass:
- Commit both repos (rdk-plugin + acuity `.gitignore`)
- Bump `plugin.json` version to 1.0.3
- Push to GitHub `main`
- `claude plugin marketplace update rdk-marketplace` to refresh cache
- `claude plugin install rdk@rdk-marketplace` to verify reinstall works
- Future sessions will use the new version without `--plugin-dir`

**What's next after Phase 4:** Revisit `#1` (split agents) only if the monolithic agent fails in testing. If it performs well, `#1` stays permanently rejected and the plan is effectively closed.

---

### Session 3 part 5 summary (for quick reference)

**Scope:** User asked to formally close all remaining points in the plan, including `#1` (split agents). `#1` is the last open point. Plan explicitly marks it as a senior judgment call: "may NOT be done. Senior judgment > sunk cost."

**Phase 1 Analysis findings:**

| Metric | Value |
|---|---|
| `code-reviewer.md` size after Session 3 | 686 lines |
| Recent acuity PRs sampled (last 2 weeks) | 6 PRs |
| Typical PR layer distribution | 1-2 layers (mostly Rails, sometimes Rails + frontend) |
| PRs touching all 4 layers in last 2 weeks | **0** |
| Real PRs in sample | wannonwater email policy (Rails-only), creator_id permissions (Rails-only), resource-team-import (Rails + frontend), portfolio-benefits (Rails + frontend), report-about-visit-pages (Rails + frontend) |

**Senior judgment: Splitting would be net negative.**

**Arguments AGAINST splitting (post-Session 3):**

1. **Step 0.5 auto-detect (#14) already skips irrelevant layers.** A PR with no Hasura changes auto-skips Step 4 entirely. Natural focus achieved without splitting.
2. **Steps 3, 4, 5 already have per-layer focus** inside the monolithic agent — splitting them into separate files just changes the file boundary, not the cognitive boundary.
3. **Step 7 Multi-Tenant Audit (#8) needs holistic view across layers.** Splitting fundamentally breaks this — sub-agents see only their slice and miss cross-layer leaks (e.g. Rails endpoint exposes data that Hasura permission was supposed to filter — visible only when both layers are reviewed together).
4. **Token cost: 5x.** 5 parallel Opus calls instead of 1 means 5x the project context loading per review. Not worth it for marginal focus gain.
5. **Maintenance: 5 files instead of 1.** Every future improvement (like the Session 3 changes — anti-hallucination rules, dual-audience output, diff-first context, etc.) would have to be replicated across 5 agent files.
6. **Cross-references between issues** (e.g. "C1 multi-tenant leak in Rails causes the failing spec mentioned in C2") become almost impossible with split outputs.
7. **Aggregation overhead.** Splitting requires a new orchestrator/aggregator step to combine 5 outputs into 1 dual-audience file. Adds complexity for no quality gain.
8. **Real acuity PRs do not justify it.** 0 PRs in the last 2 weeks touched all 4 layers. Splitting optimizes for a case that does not exist in this codebase.

**Arguments FOR splitting (per original plan):**

1. ✓ Focused context per layer — but Step 0.5 already provides this via auto-detect
2. ✓ Parallel execution — but `#7` already runs quality checks in parallel inside monolithic agent
3. ✓ Easier to extend per layer — but the monolithic agent has clear per-layer Steps that are easy to edit

**Decision: Close as ❌ NOT TO DO.**

The plan explicitly anticipated this outcome (line 87): _"I will be honest in Phase 1 if I think we should NOT do this. Senior judgment > sunk cost."_ Closing `#1` with formal reasoning is consistent with the plan's working agreement.

**Files changed in this session:**

- `plan.md` only — `#1` status flip (📋 → ❌), current status update, this Session 3 part 5 summary

**No code files changed.** Closing `#1` is a documentation-only operation: marking the decision with full reasoning so future readers (including future Claude) understand why splitting was rejected.

**Plan status after Session 3 part 5:**

| Tier | Done | Rejected | Total |
|---|---|---|---|
| **P0** | ✅ #A, #B, #C | — | 3/3 closed |
| **P1** | ✅ #2, #3, #4 | ❌ #1 | 4/4 closed |
| **P2** | ✅ #8, #7, #6 | — | 3/3 closed |
| **P3** | ✅ #11 | — | 1/1 closed |
| **P4** | ✅ #13 (soft), #14, #15 | — | 3/3 closed |

**14 of 14 points formally closed: 13 implemented + 1 explicitly rejected. Roadmap complete.**

**Reversibility:** If future testing or experience reveals that the monolithic agent struggles on a specific class of PRs (e.g. very large multi-layer PRs > 50 files), `#1` can be revisited. Soft rejection is reversible — a future session would just need to create the 5 sub-agent files and update the orchestrator. Current rejection is documented with full reasoning, not forgotten.

**Next: Phase 4 — Testing the 13 implemented points** as described in the Session 3 part 4 summary above. After successful testing → user-approved release flow (commit + push + version bump + marketplace update) → plan permanently archived.

---

Root-level cleanup done in Session 2:
- DELETED: `~/.claude/skills/code-review.backup-2026-04-07/`
- DELETED: `~/.claude/skills/task-workflow/`
- DELETED: `~/.claude/skills/rails-specialist/`
- DELETED: `~/.claude/skills/typescript-react/`
- DELETED: `~/.claude/agents/code-reviewer.md`
- DELETED: `~/.claude/agents/architect.md`
- KEPT (unique to root, NOT in plugin): `~/.claude/skills/ai-chatbot/`,
  `~/.claude/agents/workflow-companion.md`

Verified after deletion: `ls ~/.claude/skills/` → `ai-chatbot` only.
`ls ~/.claude/agents/` → `workflow-companion.md` only. Plugin loads via
marketplace install, no collisions.

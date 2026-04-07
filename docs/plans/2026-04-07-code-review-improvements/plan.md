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

### #A. 📋 Block all GitHub PR writes from the plugin

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

### #B. 🔧 Eliminate naming conflict with native `/review`

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

### #C. 📋 New output format: Critical + High focus, QA test instructions

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

### #1. 📋 Split monolithic `code-reviewer` into specialized sub-agents

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

### #2. 📋 Anti-hallucination guardrails in agent prompt

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

### #3. 📋 Diff-first context loading

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

### #4. 📋 PR mode (review by PR number, branch, or commit range)

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

### #6. 📋 Incremental review (focus on changes since last review)

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

### #7. 📋 Run quality checks in parallel

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

### #8. 📋 Multi-tenant audit as separate dedicated section

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

### #11. 📋 Configurable rules via `.rdk-review.json`

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

### #13. 📋 Universal core vs Acuity-specific split

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

### #14. 📋 Auto-detect tech stack

**Why P4:** Pairs with #13. Plugin should detect what stack the user has and only enable relevant checks.

**Phase 1 — Analysis tasks:**
- Detection markers: `Gemfile` → Rails, `package.json` → JS, `hasura/` → Hasura
- How to make detection part of agent startup

**Phase 2 — Design:** Detection logic at start of `code-reviewer` execution. Activates only relevant sub-checklists.

**Phase 3 — Implementation:** Add detection logic.

**Phase 4 — Testing:** Test on multiple project types.

**Phase 5 — Verification:** User confirms detection is correct.

---

### #15. 📋 README with output examples

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

**Current status:** #B is **mostly complete** in working-dir. Session 1
did the plugin-side cleanup (Phases 1–3). Session 2 diagnosed the real
source of the collision (root-level skill, not plugin), disabled that
skill, and removed `name:` fields from plugin commands. The remaining
work is publication (commit + push + marketplace install) and
root-level cleanup.

### How to resume

**Step 1** — You can resume in any Claude Code session. If the plugin
repo is not yet pushed to GitHub, start with `--plugin-dir` so the
working-dir changes are active:

```bash
cd ~/Work/acuity_org/acuity
claude --plugin-dir ~/Work/rdk-claude-plugin
```

If the plugin is already published and reinstalled from marketplace,
you no longer need `--plugin-dir`.

**Step 2** — In the new session, say:
> "Read ~/Work/rdk-claude-plugin/docs/plans/2026-04-07-code-review-improvements/plan.md. Continue from #B Step 5b (commit + push)."

### Session 1 summary (for quick reference)

Files changed in the plugin (all in working dir, none committed yet):
- `agents/code-reviewer.md`, `agents/architect.md`, `agents/rails-researcher.md`,
  `agents/hasura-researcher.md`, `agents/typescript-deriver.md`,
  `agents/react-planner.md` — "inherit language" instruction
- `skills/code-review/` — **deleted** (was wrapper around code-reviewer agent)
- `README.md`, `commands/help.md` — removed code-review skill row from tables
- `docs/plans/2026-04-07-code-review-improvements/plan.md` — translated
  Ukrainian quotes to English, updated #B section with Session 1 discoveries,
  updated Next action section
- `DEV.md` — **new file** documenting `--plugin-dir` workflow

### Session 2 summary (for quick reference)

In working-dir plugin:
- `commands/execute.md`, `help.md`, `next.md`, `plan.md`, `review.md` —
  removed `name:` frontmatter field (cosmetic, matches Anthropic plugin
  style)
- `docs/plans/2026-04-07-code-review-improvements/plan.md` — appended
  Session 2 discoveries and updated remaining-steps section

Outside the plugin (in `~/.claude/`, reversible):
- `~/.claude/skills/code-review/` renamed to
  `code-review.backup-2026-04-07/`
- Inside that backup folder, `SKILL.md` renamed to `SKILL.md.disabled`
  so Claude Code no longer auto-discovers it

Nothing in `~/.claude/agents/` was deleted. Marketplace cache untouched.
Nothing committed to git yet — Session 1 + Session 2 changes sit as
uncommitted working tree in the plugin repo.

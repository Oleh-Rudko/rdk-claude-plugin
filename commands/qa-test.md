---
description: Generate a manual QA test plan in Ukrainian from git diff or a PR
argument-hint: "[PR number, optional]"
---

Generate a manual test plan for a QA tester from the current changes.

Unlike `/rdk:review` (which finds bugs in code), this command assumes the code is correct
and produces a **proactive test plan**: what QA should click, in what order, to verify the
feature works and catch integration bugs.

## Determine review mode

Parse `$ARGUMENTS`:

- **Empty** → **default mode** (analyze current local working tree)
- **Positive integer** (e.g. `5190`) → **PR mode** (analyze GitHub PR #5190)
- **Otherwise** → ask: "I see `$ARGUMENTS` — did you mean a PR number?"

## Steps

1. **Find the active plan (optional, default mode only):**
   ```bash
   find docs/plans -maxdepth 2 -name "plan.md" -mtime -14 | sort | tail -1
   ```
   If found, the agent will read `epic.md` for feature context. If not, it works from the
   diff alone.

2. **Call the `qa-test-planner` subagent** with the mode-specific task description:
   - Default: "Analyze the local working tree diff. Slug for output file = current branch name."
   - PR: "Analyze GitHub PR #<num>. Slug = `pr-<num>`. Do not read local files — use `gh pr diff`."

3. **The agent writes to `docs/qa-tests/[YYYY-MM-DD]-[slug].md`** with the full plan.

4. **If the agent determines there are no user-visible changes** (pure refactor / tests-only /
   docs-only), it will say so and not generate a full plan. Report this to the user verbatim.

5. **Show the final summary** in the chat:

   ```
   ✅ QA test plan saved: docs/qa-tests/YYYY-MM-DD-<slug>.md

   Feature: [short feature name in Ukrainian]
   Cases: N golden, M edge, K permission, L multi-tenant, P regression

   ▶ Next step: передай файл QA тестувальнику — всі кроки українською,
     checkboxes для позначення Pass/Fail.
   ```

   If no user-visible changes:
   ```
   ℹ️ No user-visible changes detected — QA plan not needed for this PR.
   ```

## Examples

- `/rdk:qa-test` — generate plan for current branch's working tree
- `/rdk:qa-test 5190` — generate plan for GitHub PR #5190

## Notes

- The test plan is written ENTIRELY in Ukrainian (body), because the QA tester reads Ukrainian.
- Metadata, file paths, role names (Reader / Writer / Admin) stay in English.
- Multi-tenant isolation is ALWAYS included — even for tiny changes.
- Output goes to `docs/qa-tests/` (separate from `docs/code-review/`). Add to `.gitignore`.

$ARGUMENTS

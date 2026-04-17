---
description: Run code review (Phase 6) and final check (Phase 7) — local working tree or a GitHub PR
argument-hint: "[PR number, optional]"
---

Run code review and final verification.

## Determine review mode

Parse `$ARGUMENTS`:

- **If `$ARGUMENTS` is empty** → **default mode** (review current local working tree)
- **If `$ARGUMENTS` is a positive integer** (e.g. `5190`) → **PR mode** (review GitHub pull request with that number)
- **Otherwise** → ask the user what they meant. Example: "I see arguments `$ARGUMENTS` — did you mean a PR number? Try `/rdk:review` or `/rdk:review 5190`."

When calling the `code-reviewer` subagent, **explicitly state the mode** in the task description so the agent knows which Step 0 / Step 1 / Step 2 branch to use:

- Default mode: "Review the current local working tree using `git diff` against HEAD. Slug for the output file = current branch name."
- PR mode: "Review GitHub pull request #<number>. Use `gh pr view <number>`, `gh pr diff <number>`, and `gh pr checks <number>` for scope, content, and CI status. Slug for the output file = `pr-<number>`. Do NOT read local files — they are the wrong version."

## Steps

1. **Find the active plan** (optional — only relevant in default mode for the full task workflow):
   `find docs/plans -name "plan.md" -mtime -7`
   In PR mode, plan discovery is not required; the PR itself defines the scope.

2. **Phase 6: Code review.** Call the `code-reviewer` subagent with the mode-specific task description from above. The agent will:
   - Determine the output file path (`docs/code-review/[YYYY-MM-DD]-[slug].md`)
   - Run scope detection (`git diff` or `gh pr diff` depending on mode)
   - Run quality checks (local toolchain or `gh pr checks`)
   - Produce a dual-audience review with Critical/High blocks at the top and Medium/Low one-liners at the bottom

3. **If there are 🔴 Critical issues** — show them inline in the chat and offer to help the user fix them.

4. **Phase 7: Final review.** Call the `architect` subagent for a senior-level final pass. The agent will write to `final-review.md` (or PR-mode equivalent) and verify the code review is complete and reasonable.

5. **Show the final summary** in the chat in this exact shape:

   ```
   ✅ Review saved: docs/code-review/YYYY-MM-DD-<slug>.md

   Verdict: <🔴/🟡/🟢> (<N> Critical, <N> High, <N> Medium, <N> Low)

   🔴 Critical:
   - C1. <title> — `<file>:<line>` → QA: open review file, section "C1 → 🧪 For QA"

   🟠 High:
   - H1. <title> — `<file>:<line>` → QA: open review file, section "H1 → 🧪 For QA"
   - H2. <title> — `<file>:<line>` → QA: open review file, section "H2 → 🧪 For QA"

   ▶ Next step: open the review file and hand it to QA. Critical/High each
     have full manual test steps in Ukrainian under their "🧪 For QA" block.
   ```

   If 0 Critical + 0 High → just print the verdict and file path. No issue list.

## Examples

- `/rdk:review` — review the current branch's local changes
- `/rdk:review 5190` — review GitHub PR #5190

## PR mode — pre-review sanity checks (before calling code-reviewer)

In PR mode ONLY, run these lightweight checks **before** delegating to the subagent, so the
reviewer has clean context:

```bash
gh pr view <num> --json mergeable,mergeStateStatus,isDraft,state
```

- If `state != OPEN` → tell the user the PR is closed/merged and ask whether to proceed.
- If `isDraft == true` → warn user this is a draft; proceed if they confirm.
- If `mergeable == "CONFLICTING"` or `mergeStateStatus == "DIRTY"` → inform user there are
  merge conflicts; review still runs, but note it at the top of the output.
- If `mergeStateStatus == "BEHIND"` → inform user the PR base is behind main; not blocking,
  but note it for the reviewer to account for stale context.

No pre-checks in default (local) mode — the working tree speaks for itself.

---
name: code-review
description: >
  Code review process. Use when you need to check code quality after changes,
  before commit, or when asked "/review", "check code", "do a review".
  ALWAYS delegates to code-reviewer agent — never does self-check.
---

# Code Review

**ALWAYS use the `code-reviewer` agent** for code review, regardless of mode.

## Process

1. Determine scope: `git diff --name-only`
2. Find active plan (if exists): `ls docs/plans/`
3. Call `code-reviewer` agent with:
   - `plan.md` + `execution-log.md` (if there's an active plan)
   - `git diff` (always)
4. Show results to the human
5. If there are 🔴 Critical issues — help fix them

## Reference

The `code-reviewer` agent uses `quality-checklists/SKILL.md` for review criteria per layer.

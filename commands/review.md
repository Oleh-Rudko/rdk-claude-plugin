---
name: review
description: Run code review (Phase 6) and final check (Phase 7)
---

Run code review and final verification:

1. Find the active plan: `find docs/plans -name "plan.md" -mtime -7`
2. **Phase 6:** Call `code-reviewer` subagent — it will check git diff,
   run quality checks, and write results to code-review.md
3. If there are 🔴 Critical issues — show them and help fix
4. **Phase 7:** Call `architect` subagent for final review —
   it will verify everything is complete and write to final-review.md
5. Show the final summary

$ARGUMENTS

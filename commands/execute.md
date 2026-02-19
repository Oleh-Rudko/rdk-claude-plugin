---
name: execute
description: Start executing an approved plan (Phase 5)
---

Start executing the approved plan:

1. Find the active plan: `find docs/plans -name "plan.md" -mtime -7`
2. Read plan.md — find the first incomplete task
3. Create execution-log.md if it doesn't exist
4. Execute tasks one by one (Phase 5 from task-workflow skill):
   - Execute task
   - Mark [x] in plan.md
   - Log what was done in execution-log.md
   - Run quality checks for the changed layer
5. After all tasks — notify that Phase 5 is complete

If a specific story is specified: $ARGUMENTS

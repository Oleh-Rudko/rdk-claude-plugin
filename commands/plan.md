---
name: plan
description: Start full planning cycle for a task (Phase 1-4)
---

Start the full planning cycle for a new task. Follow the task-workflow skill:

1. **Phase 1:** Understand the task from the user, create `docs/plans/[date]-[slug]/epic.md`
2. **Phase 2a:** Call `rails-researcher` subagent (if Rails is involved)
3. **Phase 2b:** Call `hasura-researcher` subagent (if Hasura is involved)
4. **Phase 2c:** Call `typescript-deriver` subagent (if Frontend is involved)
5. **Phase 2d:** Call `react-planner` subagent (if Frontend is involved)
6. **Phase 2.5:** Ask technical questions based on research findings (if any)
7. **Phase 3:** Assemble plan.md with Epic → Stories → Tasks
8. **Phase 4:** Call `architect` subagent for senior review of the plan

Show the final plan and wait for human approval.

Task context: $ARGUMENTS

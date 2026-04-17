---
description: Start full planning cycle for a task (Phase 1-4)
---

Start the full planning cycle for a new task. Follow the task-workflow skill:

1. **Phase 1:** Understand the task from the user, create `docs/plans/[date]-[slug]/epic.md`
2. **Phase 2a+2b (PARALLEL):** If both Rails and Hasura are involved for a task that **modifies existing code**, you MUST call `rails-researcher` and `hasura-researcher` in a **single message with two Agent tool calls** so they execute concurrently. For a **new feature from scratch**, call them sequentially (hasura-researcher can leverage rails findings).
3. **Phase 2c:** After 2a+2b complete, call `typescript-deriver` subagent (if Frontend is involved). Requires research-rails.md + research-hasura.md.
4. **Phase 2d:** After 2c completes, call `react-planner` subagent (if Frontend is involved). Requires research-types.md.
5. **Phase 2.5:** Ask technical questions based on research findings (if any). Skip if none.
6. **Phase 3:** Assemble plan.md with Epic → Stories → Tasks.
7. **Phase 4:** Call `architect` subagent for senior review of the plan.

Show the final plan and wait for human approval.

**Parallelism rule:** Researchers that don't depend on each other MUST be launched concurrently via a single message with multiple Agent tool calls. Sequential launch of independent agents wastes wall-clock time and doubles cache-miss cost. Only serialize when there's a real dependency (2c depends on 2a+2b; 2d depends on 2c).

Task context: $ARGUMENTS

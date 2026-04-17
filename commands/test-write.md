---
description: Generate missing RSpec + Jest tests for recent changes
argument-hint: "[story number or scope, optional]"
---

Generate the tests that should exist for recent changes but don't.

## When to use

- You finished a Story in `/rdk:execute` but didn't write tests yet.
- You're about to run `/rdk:review` and realize coverage is thin.
- You merged a fix and want to lock behavior before moving on.

## Steps

1. **Determine scope:**
   - If `$ARGUMENTS` names a Story (e.g. `1.2`) → test the files from that Story in
     `execution-log.md`.
   - Otherwise → test everything in `git diff --name-only` (current working tree).

2. **Call the `test-writer` subagent** with:
   - Story scope or list of changed files
   - Instruction to find similar existing tests and match their style
   - Explicit reminder that multi-tenant isolation test is MANDATORY for Rails write endpoints

3. **Let the agent write test files directly** (it has Write + Edit tools). It then runs the
   suite to confirm tests pass.

4. **If tests fail because of production bugs**, the agent reports without fixing — show the
   user and ask whether to fix the code or adjust the tests.

5. **Report back:**
   ```
   Tests written:
   - rails_api/spec/requests/foo_spec.rb (4 examples, all passing)
   - client/src/components/Foo/__tests__/Foo.test.tsx (5 examples, all passing)

   Coverage notes: [what was covered, what was skipped with reason]
   ```

## Examples

- `/rdk:test-write` — write tests for all current working-tree changes
- `/rdk:test-write 1.2` — write tests for files touched in Story 1.2

$ARGUMENTS

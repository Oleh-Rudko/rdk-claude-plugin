---
description: Run UI smoke tests in a real browser via Playwright MCP
argument-hint: "[feature description] — what to test"
---

Run UI smoke tests for a feature using Playwright MCP.

## Preconditions

1. **Dev server must be running** on `http://localhost:3000` (or the project's dev URL).
   The agent will verify this and exit gracefully if not.

2. **Test credentials** are needed for authenticated features. If the user hasn't provided
   them in the message, ask:
   > "What test account should I use? Need email + password, or a pre-authenticated session
   > cookie."

3. **Playwright MCP** must be installed and enabled. If the agent can't invoke
   `mcp__plugin_playwright_playwright__browser_navigate`, it will report and exit.

## Steps

1. **Parse `$ARGUMENTS`** to understand what feature to test. If empty, ask the user.

2. **Call the `ui-tester` subagent** with:
   - The feature description (from `$ARGUMENTS`)
   - Golden path (ask user if unclear)
   - Known edge cases (ask user; common ones: empty state, permission denied, invalid input)
   - Test credentials (from prior message or ask)

3. **The agent writes to `docs/plans/[slug]/ui-test-report.md`** (or `docs/ui-tests/[date].md`
   if there's no active plan).

4. **Show a short summary in the chat:**
   ```
   ✅ UI test complete: docs/plans/.../ui-test-report.md

   Golden path: ✅
   Edge cases: 3/4 passed

   Issues found:
   - 🔴 U1. [title] — see report
   - 🟡 U2. [title] — see report
   ```

## Examples

- `/rdk:ui-test new resource subcategories page at /settings/resources/subcategories`
- `/rdk:ui-test proposal approval flow`

$ARGUMENTS

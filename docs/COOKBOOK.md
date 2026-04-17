# rdk-claude-plugin — Cookbook

How to extend, debug, and publish the plugin.

---

## Add a new agent

1. **Pick a tier.** Research / planning / mechanical → Sonnet 4.6. Critical reasoning,
   multi-tenant audit, architectural review → Opus 4.7.

2. **Create `agents/<name>.md`** with this frontmatter:
   ```yaml
   ---
   name: <name>                   # must match filename
   description: >
     One-paragraph description used by the orchestrator to decide when to call this agent.
     Be specific about inputs, outputs, and when NOT to use it.
   tools: Read, Grep, Glob, Bash  # restrict to what's needed
   model: claude-sonnet-4-6       # or claude-opus-4-7
   permissionMode: plan           # read-only agents → plan; write agents → omit this line
   ---
   ```

3. **Write the agent body** with these sections:
   - `⚠️ BEFORE YOU START` — which skill files to Glob + Read
   - `## Your Task` — what the agent does
   - `## Process` — step-by-step
   - `## Output Format` — exactly what to produce (file path, template, shape)
   - `## Rules` — anti-hallucination rules, language policy, when to exit

4. **Run `./scripts/validate.sh`** — confirms frontmatter is well-formed.

5. **Wire it in** — if the agent is called from a command, update `commands/*.md`. If it's
   called from the orchestrator, update `skills/task-workflow/SKILL.md`.

6. **Update `README.md` and `commands/help.md`** agent tables.

---

## Add a new skill

Skills are **knowledge bases** — they don't execute anything. They are auto-loaded by Claude
when the description matches the user's current task.

1. **Decide: core or overlay?** If the knowledge is universal (applies outside Acuity), put
   it in a `*-core` skill. If it's Acuity-specific, put it in an overlay skill that points
   to its core companion.

2. **Create `skills/<name>/SKILL.md`** with frontmatter:
   ```yaml
   ---
   name: <name>                     # kebab-case
   description: >
     One paragraph describing when Claude should auto-load this skill.
     Include concrete triggers ("Use when working with …") and scope limits.
   ---
   ```

3. **Body structure** — no fixed template. Headings, code blocks, tables. Keep under
   ~400 lines; large skills are slow to load and waste cache. If it grows past 400 lines,
   split into core + overlay.

4. **Run `./scripts/validate.sh`**.

5. **Reference the skill from agents** via `Glob: **/rdk-claude-plugin/skills/<name>/SKILL.md`.
   Do NOT hardcode `.claude/rdk-plugin/...` paths — they break under `--plugin-dir`.

---

## Add a new slash command

1. **Create `commands/<name>.md`**:
   ```yaml
   ---
   description: One-line description shown in the command palette.
   argument-hint: "[optional argument shape]"
   ---

   Prose describing what the command does.

   ## Steps
   1. ...
   2. ...

   $ARGUMENTS
   ```

2. **Don't add `$ARGUMENTS` in prose** unless you need the user's arguments passed through
   verbatim at the end. The common pattern is one trailing `$ARGUMENTS` so Claude can see
   them, but it's optional.

3. **Run `./scripts/validate.sh`**.

4. **Update `README.md`** and `commands/help.md` command tables.

---

## Debugging `permissionMode`

| Value | Effect |
|---|---|
| `plan` | Agent can read / run analysis but will NOT make file edits. Use for researchers, reviewers. |
| `acceptEdits` | Agent can edit files without per-edit confirmation. Use carefully. |
| `bypassPermissions` | No gates. Don't use unless you explicitly need it. |
| (omitted) | Inherits session default — usually prompts for every write. |

Common symptoms:
- Agent writes files despite `permissionMode: plan` → check for a local
  `.claude/settings.json` overriding permissions.
- Agent blocked when trying to `Bash` a read-only command → the tool permission is usually
  fine; `plan` mode gates writes, not reads. If blocked, check `tools:` list.

---

## Debug "my plugin edits aren't showing up"

1. Did you start Claude with `--plugin-dir`? Running plain `claude` loads the marketplace
   version, not your local copy.
2. Did you run `/reload-plugins` after editing?
3. Is the marketplace version overriding? Disable it in `~/.claude/settings.json`:
   ```json
   { "enabledPlugins": { "rdk@rdk-marketplace": false } }
   ```
4. Still broken? Run `./scripts/validate.sh` — if validation fails, the plugin won't load.

See also `DEV.md` for the full local dev loop.

---

## Publish a new version

1. **Bump `version` in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`**.
   These MUST match — the validator enforces this.
2. **Add a new section at the top of `CHANGELOG.md`** describing changes (Added / Changed /
   Fixed).
3. **Run `./scripts/validate.sh`** — must pass.
4. **Commit and push to `main`.** Users pick up the new version by running
   `/plugin marketplace update rdk-marketplace`.

---

## Gotchas

- **Skill paths:** always resolve via Glob, not hardcoded `.claude/rdk-plugin/…`. The install
  location differs between marketplace and `--plugin-dir`.
- **Frontmatter parsing:** YAML is picky about indentation and quoting. Multi-line descriptions
  need the `>` folding indicator or the skill description ends at the first newline.
- **Subagent context isolation:** subagents do NOT see prior conversation. Pass everything they
  need in the prompt text. A prompt like "based on our discussion, do X" will fail silently.
- **Glob returns nothing:** means the path doesn't exist in any accessible location. Check
  whether the plugin is actually loaded (`/plugin list`) before debugging the agent logic.

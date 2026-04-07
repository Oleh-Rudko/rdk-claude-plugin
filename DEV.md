# Plugin Development Guide

How to work on this plugin locally before publishing changes.

## The Problem

When you install this plugin via a marketplace (GitHub source), Claude Code
loads the **published** version from `~/.claude/plugins/marketplaces/...`.
Your local edits in a working directory are invisible to Claude until you
push to GitHub and update the marketplace.

For active development that's too slow. You need a way to point Claude Code
directly at your local working copy.

## The Solution: `--plugin-dir`

Claude Code supports a `--plugin-dir` flag that loads a plugin from a local
path. When present, the local version **takes precedence** over any marketplace
version of the same plugin for that session.

**Official docs:** https://code.claude.com/docs/en/plugins.md#test-your-plugins-locally

## Daily Dev Workflow

### 1. Start Claude with the local plugin loaded

From any project directory (e.g. the repo you use the plugin on):

```bash
claude --plugin-dir /absolute/path/to/rdk-claude-plugin
```

Example:

```bash
cd ~/Work/acuity_org/acuity
claude --plugin-dir ~/Work/rdk-claude-plugin
```

You can load multiple plugins at once:

```bash
claude --plugin-dir ~/Work/rdk-claude-plugin --plugin-dir ~/Work/other-plugin
```

### 2. Edit files in the working directory

Open your editor on `~/Work/rdk-claude-plugin/`. Make changes to agents,
commands, skills, or anything else.

### 3. Reload the plugin without restarting the session

Inside Claude Code, run:

```
/reload-plugins
```

This picks up your edits immediately. No need to quit and relaunch.

### 4. Test your changes

Run a command or trigger a skill:

```
/rdk:review
```

Verify behavior matches expectations.

### 5. Iterate

Repeat edit → `/reload-plugins` → test until you're happy.

### 6. Commit and publish

```bash
git checkout -b feature/my-change
git add .
git commit -m "feat(plugin): ..."
git push -u origin feature/my-change
# Open a PR. When merged into main:
# - Users run `/plugin marketplace update rdk-marketplace` to get the new version.
```

## Repository Layout

```
rdk-claude-plugin/
├── .claude-plugin/
│   └── plugin.json          ← plugin manifest (name, version, author)
├── agents/                  ← sub-agents callable from orchestrator
│   ├── code-reviewer.md
│   ├── architect.md
│   ├── rails-researcher.md
│   ├── hasura-researcher.md
│   ├── typescript-deriver.md
│   └── react-planner.md
├── commands/                ← slash commands (/rdk:plan, /rdk:execute, etc.)
│   ├── plan.md
│   ├── execute.md
│   ├── review.md
│   ├── next.md
│   └── help.md
├── skills/                  ← knowledge bases auto-loaded when relevant
│   ├── task-workflow/
│   ├── quality-checklists/
│   ├── rails-specialist/
│   ├── hasura-specialist/
│   └── typescript-react/
├── docs/
│   └── plans/               ← working plans for plugin improvements
├── README.md                ← user-facing overview
└── DEV.md                   ← this file
```

## Language Policy

- **Agent communication**: agents inherit the language from the task
  description they receive. If you invoke `/rdk:review` in English, agents
  respond in English. If you invoke it in Ukrainian, they respond in Ukrainian.
- **Code, file paths, identifiers, commit messages, docs, plans**: always English.
- No hardcoded language in agent prompts — the "inherit language" instruction
  is the only rule.

## Common Pitfalls

### "My edits don't show up in Claude"

- Did you start Claude with `--plugin-dir`? Run `claude --plugin-dir ~/Work/rdk-claude-plugin` — not just `claude`.
- Did you run `/reload-plugins` after editing?
- Is the plugin also installed from a marketplace? The local version should override it, but worth confirming via `/plugin list`.

### "Changes to skill descriptions don't trigger differently"

Skill descriptions are read by Claude when deciding which skill to activate.
`/reload-plugins` refreshes these. If behavior is unchanged, try quitting
the Claude session and restarting with `--plugin-dir`.

### "I want to test without the marketplace version interfering"

Disable the marketplace version in `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "rdk@rdk-marketplace": false
  }
}
```

Then run Claude with `--plugin-dir`. The local version loads cleanly.

## Contributing

This plugin started as a personal workflow and is transitioning to a shared
product. When adding features:

- Keep the plugin **stack-agnostic** where possible. Acuity-specific details
  belong in the `skills/` files that are clearly marked as such.
- **Follow the inherit-language pattern** — don't hardcode Ukrainian or
  English in agent prompts.
- **Update `README.md` and `DEV.md`** if you change structure or workflow.
- **Test with `--plugin-dir` before opening a PR.**

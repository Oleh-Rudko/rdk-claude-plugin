---
description: Show plugin overview, commands, and usage guide
---

# RDK Plugin — Acuity PPM Development Workflow

## Commands

| Command | What it does |
|---------|-------------|
| `/rdk:plan [task]` | Start planning cycle: understand → research → plan → architect review |
| `/rdk:execute` | Execute approved plan: story by story with quality checks |
| `/rdk:review` | Code review + final senior check before commit |
| `/rdk:next` | Restore context after compact or new session |
| `/rdk:help` | This help page |

## Best Workflow

```
1. /rdk:plan add notifications to projects page
   → Claude asks questions, runs researchers, builds plan
   → You review and approve

2. /rdk:execute
   → Claude executes story by story
   → Quality checks after each layer

3. /rdk:review
   → Automated code review (N+1, permissions, types, tests)
   → Final architect check
   → Ready to commit
```

## Work Modes

| Mode | When | What happens |
|------|------|-------------|
| 🟢 Quick | < 15 min, 1 layer | No subagents, just do it |
| 🟡 Medium | 15 min - 2h, 1-2 layers | Research + plan for affected layers |
| 🔴 Full | 2+ hours, 3+ layers | All researchers, checkpoint review, full docs |

Claude proposes mode automatically. You can override.

## Skills (auto-activated)

| Skill | When activated |
|-------|--------------|
| `task-workflow` | Any task — orchestrates the whole process |
| `rails-specialist` | Working in rails_api/ |
| `hasura-specialist` | Working in hasura/ |
| `typescript-react` | Working in client/ |
| `quality-checklists` | After changes — review criteria per layer |

## Agents (called by orchestrator)

| Agent | Phase | Output |
|-------|-------|--------|
| `rails-researcher` | 2a | research-rails.md |
| `hasura-researcher` | 2b | research-hasura.md |
| `typescript-deriver` | 2c | research-types.md |
| `react-planner` | 2d | research-react.md |
| `architect` | 4, 7 | senior-review.md, final-review.md |
| `code-reviewer` | 6 | code-review.md |

## Tips

- **Quick question?** Just ask — no need for /rdk:plan for small things
- **Bug fix?** `/rdk:plan fix X` — Claude will propose 🟢 Quick or 🟡 Medium
- **New feature?** `/rdk:plan add Y` — full research cycle
- **After compact?** `/rdk:next` — restores where you left off
- **Before commit?** `/rdk:review` — catches N+1, permissions, types issues

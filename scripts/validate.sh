#!/usr/bin/env bash
# validate.sh — sanity-check the rdk-claude-plugin structure.
#
# Checks:
#   1. Every agent in agents/*.md has YAML frontmatter with name, description, model, tools.
#   2. Every command in commands/*.md has YAML frontmatter with a description.
#   3. Every skill in skills/*/SKILL.md has YAML frontmatter with name + description.
#   4. plugin.json version matches marketplace.json version for the rdk plugin entry.
#   5. Each agent's declared name matches its filename (name: foo → agents/foo.md).
#   6. No hardcoded skill paths of the form ".claude/rdk-plugin/skills/..." — they should be
#      resolved via Glob in modern agents.
#
# Usage: ./scripts/validate.sh
# Exit codes: 0 = clean, 1 = warnings only, 2 = errors found.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
errors=0; warnings=0

err()  { echo "${RED}✗ ERROR${RST}: $*"; errors=$((errors+1)); }
warn() { echo "${YEL}⚠ WARN${RST}:  $*"; warnings=$((warnings+1)); }
ok()   { echo "${GRN}✓${RST} $*"; }

echo "== Validating rdk-claude-plugin =="
echo "Root: $ROOT"
echo

# --- 1. Agents ---
echo "[1/6] Checking agents/*.md frontmatter..."
for f in agents/*.md; do
  [ -e "$f" ] || { warn "no agent files found"; break; }
  base="$(basename "$f" .md)"

  # Extract frontmatter block (between first two '---' lines).
  fm="$(awk '/^---$/{c++; next} c==1' "$f")"

  for key in name description model tools; do
    if ! grep -qE "^${key}:" <<<"$fm"; then
      err "$f missing frontmatter key: $key"
    fi
  done

  declared_name="$(grep -E '^name:' <<<"$fm" | head -1 | sed -E 's/^name:[[:space:]]*//' | tr -d '"')"
  if [ -n "$declared_name" ] && [ "$declared_name" != "$base" ]; then
    err "$f declares name: '$declared_name' but filename is '$base.md' — they must match"
  fi
done
ok "agents checked"

# --- 2. Commands ---
echo "[2/6] Checking commands/*.md frontmatter..."
for f in commands/*.md; do
  [ -e "$f" ] || { warn "no command files found"; break; }
  fm="$(awk '/^---$/{c++; next} c==1' "$f")"
  if ! grep -qE "^description:" <<<"$fm"; then
    err "$f missing frontmatter key: description"
  fi
done
ok "commands checked"

# --- 3. Skills ---
echo "[3/6] Checking skills/*/SKILL.md frontmatter..."
for d in skills/*/; do
  f="$d/SKILL.md"
  if [ ! -f "$f" ]; then
    err "$d has no SKILL.md"
    continue
  fi
  fm="$(awk '/^---$/{c++; next} c==1' "$f")"
  for key in name description; do
    if ! grep -qE "^${key}:" <<<"$fm"; then
      err "$f missing frontmatter key: $key"
    fi
  done
done
ok "skills checked"

# --- 4. Version sync ---
echo "[4/6] Checking plugin.json <-> marketplace.json version sync..."
plugin_ver="$(grep -E '"version"' .claude-plugin/plugin.json | head -1 | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')"
marketplace_ver="$(grep -E '"version"' .claude-plugin/marketplace.json | head -1 | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')"

if [ -z "$plugin_ver" ]; then err "plugin.json has no version"; fi
if [ -z "$marketplace_ver" ]; then err "marketplace.json has no version"; fi

if [ "$plugin_ver" != "$marketplace_ver" ]; then
  err "version mismatch: plugin.json=$plugin_ver, marketplace.json=$marketplace_ver"
else
  ok "versions match ($plugin_ver)"
fi

# --- 5. Hardcoded skill paths (legacy pattern, should use Glob now) ---
echo "[5/6] Checking for hardcoded skill paths..."
bad_paths="$(grep -rEn "\.claude/rdk-plugin/skills" agents/ 2>/dev/null || true)"
if [ -n "$bad_paths" ]; then
  warn "Found hardcoded skill paths (should use Glob for portability):"
  echo "$bad_paths" | sed 's/^/    /'
else
  ok "no hardcoded skill paths"
fi

# --- 6. CHANGELOG mentions current version ---
echo "[6/6] Checking CHANGELOG mentions plugin version..."
if [ ! -f CHANGELOG.md ]; then
  warn "no CHANGELOG.md"
elif ! grep -qE "^## \[?${plugin_ver}" CHANGELOG.md; then
  warn "CHANGELOG.md does not mention version $plugin_ver"
else
  ok "CHANGELOG mentions $plugin_ver"
fi

echo
if [ "$errors" -gt 0 ]; then
  echo "${RED}Validation FAILED${RST}: $errors errors, $warnings warnings"
  exit 2
elif [ "$warnings" -gt 0 ]; then
  echo "${YEL}Validation passed with warnings${RST}: 0 errors, $warnings warnings"
  exit 1
else
  echo "${GRN}Validation PASSED${RST}: no issues"
  exit 0
fi

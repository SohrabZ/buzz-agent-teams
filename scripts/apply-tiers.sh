#!/usr/bin/env bash
# Apply QuickBee / WorkerBee / SmartBee model + effort tiers to imported Buzz agents.
#
# Why this exists: Buzz's `claude` runtime is declared with `model_env_var: None`
# and `provider_locked: true`, so `runtime_metadata_env_vars()` injects NOTHING
# for it — the `model` field on a Claude-runtime agent is metadata only and does
# not change which model actually runs. The knob that works is the agent's own
# `env_vars` map, which is merged last at spawn time (readiness.rs: baked
# defaults -> runtime metadata -> merged user env, last-wins).
#
# `env_vars` is deliberately excluded from team snapshots (it can hold secrets),
# which is why this is a separate post-import step.
#
# Usage:  ./apply-tiers.sh          # apply
#         ./apply-tiers.sh --dry    # show what would change

set -euo pipefail

STORE="$HOME/Library/Application Support/xyz.block.buzz.app/agents/managed-agents.json"
DRY=false
[[ "${1:-}" == "--dry" ]] && DRY=true

[[ -f "$STORE" ]] || { echo "No managed-agents.json at: $STORE" >&2; exit 1; }

if pgrep -x Buzz >/dev/null 2>&1; then
  echo "Buzz Desktop is running. Quit it first — it rewrites this file on exit and will clobber the patch." >&2
  exit 1
fi

# name -> "MODEL EFFORT".  Article tiers: cheaper model, higher effort.
#
# Includes every name in the WorkerBee `namePool`s, so clones spun up later
# (Comet asking for a second worker, say) get patched by a re-run of this
# script without editing it.
read -r -d '' TIERS <<'EOF' || true
Mason    claude-opus-5                medium
Comet    claude-opus-5                medium
Thistle  claude-sonnet-5              high
Pollen   claude-haiku-4-5-20251001    high
Clover   claude-sonnet-5              high
Nectar   claude-sonnet-5              high
Amber    claude-sonnet-5              high
Daisy    claude-sonnet-5              high
Orchard  claude-sonnet-5              high
Meadow   claude-sonnet-5              high
Waxwing  claude-sonnet-5              high
Juniper  claude-sonnet-5              high
Sage     claude-sonnet-5              high
Willow   claude-haiku-4-5-20251001    high
EOF

# Build a jq object: {"Mason": {"ANTHROPIC_MODEL": "...", "CLAUDE_CODE_EFFORT_LEVEL": "..."}, ...}
MAP=$(awk 'NF {printf "{\"name\":\"%s\",\"model\":\"%s\",\"effort\":\"%s\"}\n", $1, $2, $3}' <<<"$TIERS" \
  | jq -s 'map({key: .name, value: {ANTHROPIC_MODEL: .model, CLAUDE_CODE_EFFORT_LEVEL: .effort}}) | from_entries')

PATCHED=$(jq --argjson map "$MAP" '
  map(
    if (.is_builtin | not) and ($map[.name] != null)
    then .env_vars = ((.env_vars // {}) + $map[.name])
    else .
    end
  )
' "$STORE")

CHANGED=$(jq --argjson map "$MAP" '[.[] | select((.is_builtin | not) and ($map[.name] != null)) | .name]' "$STORE")

if [[ "$(jq -r 'length' <<<"$CHANGED")" == "0" ]]; then
  echo "No imported Hive/Swarm agents found in the store. Import the .team.json files first." >&2
  exit 1
fi

echo "Agents to patch: $(jq -r 'join(", ")' <<<"$CHANGED")"

if $DRY; then
  jq --argjson map "$MAP" '.[] | select((.is_builtin|not) and ($map[.name] != null)) | {name, env_vars: ((.env_vars // {}) + $map[.name])}' "$STORE"
  exit 0
fi

BACKUP="$STORE.bak.$(date +%Y%m%d-%H%M%S)"
cp "$STORE" "$BACKUP"
printf '%s\n' "$PATCHED" > "$STORE"
echo "Patched. Backup: $BACKUP"
echo "Start Buzz and restart each agent for the new env to take effect."

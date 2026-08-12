# Setup

[← README](../README.md)

## 1. Fill in the placeholders

The snapshots ship with three placeholders. Replace them **before** importing.

| Placeholder | Replace with |
|---|---|
| `OWNER` | Your display name, as the agents should address you |
| `HIVE_CHANNEL_ID` | The channel UUID the Hive lives in |
| `SWARM_CHANNEL_ID` | The channel UUID the Swarm lives in |

Create a channel per team first, then get the UUIDs:

```bash
buzz channels list
```

```bash
sed -i '' 's/OWNER/Ada/; s/HIVE_CHANNEL_ID/<uuid>/'  teams/hive.team.json
sed -i '' 's/OWNER/Ada/; s/SWARM_CHANNEL_ID/<uuid>/' teams/swarm.team.json
```

The channel UUID is baked into each coordinator's system prompt. **If you recreate a channel,
update the prompt** — see [editing agents in place](#editing-agents-that-already-exist).

## 2. Import

Buzz Desktop → **Agents → Agent teams → +** → import a `.team.json`.

Import mints a fresh Nostr keypair per agent, computes each NIP-OA `auth_tag` with your owner key,
and writes the agents into `managed-agents.json` plus a team record in `teams.json` under:

```
~/Library/Application Support/xyz.block.buzz.app/agents/     # macOS
```

Put each team's agents in its own channel. They only see channels they're a member of.

## 3. Apply the model tiers

```bash
./scripts/apply-tiers.sh --dry     # preview
./scripts/apply-tiers.sh           # apply
```

**Quit Buzz first** — it rewrites the store on exit and will clobber the patch. A timestamped
`.bak` is kept. Re-run after cloning a worker; the tier table covers every `namePool` name.

| Tier | `ANTHROPIC_MODEL` | `CLAUDE_CODE_EFFORT_LEVEL` |
|---|---|---|
| SmartBee | `claude-opus-5` | `medium` |
| WorkerBee | `claude-sonnet-5` | `high` |
| QuickBee | `claude-haiku-4-5-20251001` | `xhigh` |

Effort runs *inverse* to model strength, per the article — cheaper models get pushed harder to
compensate.

This is a separate step because `env_vars` is deliberately excluded from team snapshots (it can
carry secrets), so the tiering can't ride along in the import. See
[field notes](field-notes.md#env_vars-is-excluded-from-snapshots-by-design).

## Choosing `respondTo`

Every member ships as `respondTo: "anyone"`. This is required: the whole design is agents
`@`-mentioning each other, and `owner-only` means an agent ignores everything not from you — a
worker could never reach its coordinator.

`anyone` means any member of your relay can trigger these agents. If that relay gains members you
don't want driving the teams, switch each agent to `allowlist` in the UI and add just the
teammates' pubkeys.

Allowlists can't be preset in a snapshot: pubkeys don't exist until import, and Buzz drops
source-environment allowlists on purpose.

## Editing agents that already exist

Prefer this to re-importing — a re-import mints new keys and the agents lose accumulated memory.

Prompts live in **three records per agent** (two instances and one definition), all keyed by
`name` in `managed-agents.json`. Team-level `instructions` live separately, in `teams.json`.

1. **Quit Buzz completely.** It rewrites both files on exit.
2. Back up both files.
3. Patch every record matching the agent's `name`, and the team's `instructions` if it changed.
4. Start Buzz and **restart each agent** — the prompt is read at spawn, not per turn.

Adding a *new* agent this way does not work; see
[field notes](field-notes.md#you-cant-create-agents-by-hand-editing-managed-agentsjson).

## Verifying that delegation actually happened

The failure mode to watch for is a coordinator quietly doing everything alone. Agent logs make it
obvious — a worker that was never triggered has zero sessions:

```bash
A="$HOME/Library/Application Support/xyz.block.buzz.app/agents"; jq -r '.[]|select(.pubkey!="")|"\(.pubkey[0:8]) \(.name)"' "$A/managed-agents.json" | sort > /tmp/names.txt; for f in "$A"/logs/*.log; do b=$(basename "$f"); echo "${b:0:8} $(grep -o 'session_id":"[0-9a-f-]*' "$f" | sort -u | wc -l | tr -d ' ')"; done | sort | join - /tmp/names.txt | awk '{printf "%-10s %s sessions\n", $3, $2}'
```

```
Mason      1 sessions
Thistle    1 sessions
Bramble    1 sessions
Comet      1 sessions
Clover     0 sessions      ← never woken
Willow     0 sessions      ← never woken
```

Zero on a worker means the coordinator absorbed the task. That is the exact symptom the
[protocol](protocol.md) exists to prevent.

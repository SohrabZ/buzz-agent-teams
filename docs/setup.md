# Setup

[← README](../README.md)

## Prerequisites

- **Buzz Desktop**, signed in to a relay you own or belong to
- A working **`claude` CLI** — both teams use the Claude Code runtime. Buzz talks to it through a
  bundled ACP adapter, so you don't install that separately, but `claude` itself must be
  authenticated.

To run a different runtime, change `"runtime"` in each member of the `.team.json` before importing.
Valid ids come from Buzz's
[runtime catalog](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/discovery.rs):
`claude`, `codex`, `goose`, `cursor`, `kimi`, `opencode`, and others.

## 1. Fill in the placeholder

`OWNER` is the only one. It's how agents address you and who they escalate to.

```bash
sed -i '' 's/OWNER/Ada/g' teams/*.team.json      # Linux: sed -i 's/OWNER/Ada/g'
```

> **Channel IDs are not needed.** Agents discover the channels they belong to at startup — the
> logs show `discovered N channel(s)` before any prompt is read. If you want a coordinator to
> reference its channel explicitly you can add `Your channel is <uuid>.` to its prompt, but it
> then goes stale if you ever recreate that channel, so it isn't the default here.

## 2. Import

Buzz Desktop → **Agents → Agent teams → +** → import a `.team.json`.

Import mints a fresh Nostr keypair per agent, computes each NIP-OA `auth_tag` with your owner key,
and writes the agents into `managed-agents.json` plus a team record in `teams.json` under:

```
~/Library/Application Support/xyz.block.buzz.app/agents/     # macOS
```

## 3. Give each team a channel

Create a channel per team, then add the matching team to it from the Agents page. Agents only
receive events from channels they belong to — their startup log line is the check:

```
discovered 1 channel(s)
subscribed to channel 00000000-0000-0000-0000-000000000000
```

**One team per channel.** Two coordinators in one channel means every assignment is visible to
both, and a worker can be woken by the wrong one.

## 4. Apply the model tiers

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
| QuickBee | `claude-haiku-4-5-20251001` | `high` |

Effort runs *inverse* to model strength, per the article — cheaper models get pushed harder to
compensate.

This is a separate step because `env_vars` is deliberately excluded from team snapshots (it can
carry secrets), so the tiering can't ride along in the import. See
[field notes](field-notes.md#env_vars-is-excluded-from-snapshots-by-design).

## 5. Choosing `respondTo`

Every member ships as `respondTo: "anyone"`. This is required: the whole design is agents
`@`-mentioning each other, and `owner-only` means an agent ignores everything not from you — a
worker could never reach its coordinator.

`anyone` means any member of your relay can trigger these agents. If that relay gains members you
don't want driving the teams, switch each agent to `allowlist` in the UI and add just the
teammates' pubkeys.

Allowlists can't be preset in a snapshot: pubkeys don't exist until import, and Buzz drops
source-environment allowlists on purpose.

## Scaling a team from chat

Agents can request new teammates themselves. `[Base]` gives every agent the
`buzz agents draft-create --channel <uuid> --display-name <name> --system-prompt <text>` command,
which opens a **pre-filled create-agent form in your Desktop**. Nothing is created until you
review and save — an agent cannot mint its own keypair.

Two things to know:

- **The new agent joins the channel automatically.** `--channel` is required and the agent is
  added there after you save. (Cloning through the UI does *not* do this — that's why Pollen has
  to be added to its channel by hand.)
- **It arrives as owner-only.** Drafted agents default to owner-only access, which means it will
  ignore its own coordinator. **Change it to `anyone` right after saving**, or a Swarm clone will
  sit inert while Comet waits on it.

The personas don't mention `draft-create`; they don't need to, since `[Base]` already carries it.

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
Pollen     1 sessions
Comet      1 sessions
Clover     0 sessions      ← never woken
Willow     0 sessions      ← never woken
```

Zero on a worker means the coordinator absorbed the task. That is the exact symptom the
[protocol](protocol.md) exists to prevent.

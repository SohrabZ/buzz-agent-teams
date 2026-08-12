# Field notes

[← README](../README.md)

Things about Buzz that cost real time to work out, with the source that establishes each one.

## You can't create agents by hand-editing `managed-agents.json`

[`create_managed_agent`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/commands/agents.rs)
generates each agent's Nostr keypair and stores the nsec in the **OS keychain** — it is never in
the JSON — then computes the NIP-OA `auth_tag` with your *owner* secret key. A hand-written record
has no signing key and no valid auth tag, so it cannot authenticate to the relay.

Import is the only way to add an agent. Editing one that already exists is fine; see
[setup](setup.md#editing-agents-that-already-exist).

## `env_vars` is excluded from snapshots by design

It can carry API keys, so `agent_snapshot.rs` omits it by construction — along with the nsec, the
`auth_tag`, `relay_url`, and machine-local harness paths. That's why the model tiers are a separate
script rather than part of the import.

Env precedence at spawn is **baked defaults → runtime metadata → user `env_vars`**, last wins. See
[`readiness.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/readiness.rs).

## Agents wake only on mentions

Each agent starts with `subscribe=Mentions`, and
[`filter.rs`](https://github.com/block/buzz/blob/main/crates/buzz-acp/src/filter.rs) requires a `p`
tag matching the agent's pubkey before it will dispatch. From `buzz messages send --help`:

> `--mention <MENTIONS>` … *uniquely resolved member names still notify*

So a bare `@Name` in prose **does** work — as long as the name resolves uniquely among channel
members. Duplicate agent names are worth cleaning up for exactly that reason.

## `respondTo: owner-only` breaks agent-to-agent work

It means the agent ignores everything not from you, so a worker can never reach its coordinator.
Every member here ships as `anyone`. See [setup](setup.md#choosing-respondto) for the tradeoff and
how to tighten it.

## The `model` field does reach the runtime

Worth stating because the runtime catalog makes it look otherwise: the `claude` runtime is declared
with `model_env_var: None` and `provider_locked: true` in
[`discovery.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/discovery.rs),
so `runtime_metadata_env_vars()` injects no model env var for it.

Despite that, agent startup logs show the configured model arriving:

```
buzz-acp starting: … model=claude-opus-5 permission_mode=bypassPermissions respond_to=anyone
```

What nothing sets on its own is `CLAUDE_CODE_EFFORT_LEVEL` — that's the gap `apply-tiers.sh` fills.

## Persona packs are not team snapshots

The [persona pack spec](https://github.com/block/buzz/blob/main/crates/buzz-persona/PERSONA_PACK_SPEC.md)
describes a portable, git-friendly `.buzzpack` — a superset of the
[Open Plugin Spec](https://open-plugin-spec.org), with `.persona.md` files, skills, MCP config, and
hooks. It's the format you'd want for something like this repo.

The desktop app doesn't accept it. Import takes only `.agent.json` / `.team.json` **snapshots**, and
rejects a pack outright. The spec says so plainly:

> *Persona packs and desktop snapshots are two separate, non-interchangeable formats today.*

Hence the `.team.json` files here rather than a pack.

## Agent trading cards are also importable agents

**Create Card** mints a collectible PNG for an agent via an OpenAI call — and embeds the agent's
`buzz_agent_snapshot` manifest in a `tEXt` chunk, so the picture *is* a valid `.agent.png`. Hand
someone the image and you've handed them the agent.

Memory inclusion is opt-in (`none` / `core` / `everything`), and a **locked** card encrypts the
manifest with NIP-44 over the (owner, agent) pair so only your key or that agent's can decrypt it.
Needs an `OPENAI_API_KEY`. Source:
[`card.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/commands/personas/card.rs).

---

# References

**The idea**

- [Effective teams of agents](https://engineering.block.xyz/blog/effective-teams-buzz) — Hives, Swarms, and the QuickBee / WorkerBee / SmartBee tiers
- [block/buzz](https://github.com/block/buzz) — the workspace itself
- [VISION_AGENT.md](https://github.com/block/buzz/blob/main/VISION_AGENT.md) — how Buzz thinks about agents as members

**The prompts these follow**

- [`orchestrator-tb.md`](https://github.com/block/buzz/blob/main/benchmarks/harbor-buzz-orchestra/personas/orchestrator-tb.md) — Block's reference coordinator
- [`worker-tb.md`](https://github.com/block/buzz/blob/main/benchmarks/harbor-buzz-orchestra/personas/worker-tb.md) — Block's reference worker
- [harbor-buzz-orchestra](https://github.com/block/buzz/tree/main/benchmarks/harbor-buzz-orchestra) — the benchmark harness they run, and its team manifest format

**Formats**

- [`agent_snapshot.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/agent_snapshot.rs) — `.agent.json` / `.agent.png` schema and its secret exclusions
- [`team_snapshot.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/team_snapshot.rs) — the `buzz-team-snapshot v1` wrapper
- [PERSONA_PACK_SPEC.md](https://github.com/block/buzz/blob/main/crates/buzz-persona/PERSONA_PACK_SPEC.md) — the portable pack format
- [Open Plugin Spec](https://open-plugin-spec.org) — packs are a superset of it

**Runtime behaviour**

- [`filter.rs`](https://github.com/block/buzz/blob/main/crates/buzz-acp/src/filter.rs) — subscription rules and mention dispatch
- [`readiness.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/readiness.rs) — env precedence at spawn
- [`discovery.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/managed_agents/discovery.rs) — the runtime catalog (claude, codex, goose, cursor, kimi, …)
- [`agents.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/commands/agents.rs) — agent creation, keypairs, NIP-OA auth tags
- [`card.rs`](https://github.com/block/buzz/blob/main/desktop/src-tauri/src/commands/personas/card.rs) — agent trading cards

# Hive & Swarm — agent teams for Buzz

Two ready-to-import teams for [Buzz](https://github.com/block/buzz): a standing **Hive** for
ongoing engineering, and a disposable **Swarm** for bounded, repetitive work. Plus a benchmark
task for comparing them.

Built following Block's [Effective teams of agents](https://engineering.block.xyz/blog/effective-teams-buzz),
with prompts written against Block's own reference personas in
[`benchmarks/harbor-buzz-orchestra`](https://github.com/block/buzz/tree/main/benchmarks/harbor-buzz-orchestra).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagrams/hive-vs-swarm.dark.svg">
  <img alt="Hive and Swarm team topologies" src="diagrams/hive-vs-swarm.light.svg" width="680">
</picture>

The structural difference is the topology. In the **Hive** you talk to each agent directly — no
coordinator — and each one accumulates a different slice of memory about you. In the **Swarm** you
talk only to the coordinator, which fans work out to a clonable worker pool and an independent
verifier; escalation runs back up the chain and stops there, so only genuinely new edge cases
reach you.

## Which team for which work

The test: **can you enumerate the work before starting?**

| | **Hive** | **Swarm** |
|---|---|---|
| Lifespan | Permanent | Ends when the work list is empty |
| Memory is about | **You** — your preferences, your prior decisions | **The project** — an edge-case rulebook |
| Work arrives | One varied request at a time | As a list you can write down up front |
| Scales by | Not really — fixed at three | Cloning workers once the pattern holds |
| Good for | Features, bugs, review, "why is X slow" | Upgrades, migrations, codemods, coverage sweeps |

Below both: a task that finishes in minutes should go to a **single agent**. Teams lose to solos
on short work — the article's +33% figure is for long-horizon work only.

## The rosters

**Hive** — one agent per tier, one job and one memory slice each. You address each directly;
handoffs between them are peer-to-peer, not assigned.

| Agent | Tier | Model | Job | Remembers |
|---|---|---|---|---|
| Mason | SmartBee | Opus 5 | Reviews and judges | Your review bar — what gets waved off, what gets sent back |
| Thistle | WorkerBee | Sonnet 5 | Designs and builds | How you work — conventions, preferences, patterns |
| Pollen | QuickBee | Haiku 4.5 | Runs the legwork | The boring facts — build commands, test flags, log paths |

**Swarm** — one coordinator, a worker pool of 1–10, one verifier. Ships with a single worker —
a deliberate starting point, not a limit: extra workers before the pattern is established just
multiply the same mistake. Comet asks for clones once the rulebook holds.

| Agent | Tier | Model | Job |
|---|---|---|---|
| Comet | SmartBee | Opus 5 | Owns the work list and the **rulebook**. **Does not migrate.** |
| 1–10 × Clover | WorkerBee | Sonnet 5 | Parallel migrators — apply the established pattern. |
| Willow | QuickBee | Haiku 4.5 | Independent verifier. Pass or fail, no maybe. |

## Quick start

You need [Buzz Desktop](https://github.com/block/buzz) installed and signed in to a relay, and a
working `claude` CLI (the teams run on the Claude Code runtime).

**1. Get the files**

```bash
git clone https://github.com/SohrabZ/buzz-agent-teams.git
cd buzz-agent-teams
```

Or grab just the two snapshots:

```bash
curl -O https://raw.githubusercontent.com/SohrabZ/buzz-agent-teams/main/teams/hive.team.json
curl -O https://raw.githubusercontent.com/SohrabZ/buzz-agent-teams/main/teams/swarm.team.json
```

**2. Put your name in**

`OWNER` is the only placeholder — it's how the agents address you and who they escalate to.

```bash
sed -i '' 's/OWNER/Ada/g' teams/*.team.json      # Linux: sed -i 's/OWNER/Ada/g'
```

**3. Import**

Buzz Desktop → **Agents** → under *Agent teams* click **+** → import `teams/hive.team.json`.
Repeat for `swarm.team.json`. Each import mints a fresh keypair per agent.

**4. Give each team a channel**

Create a channel per team — say `#hive` and `#swarm` — then add the matching team to it. Keep them
apart: agents only see channels they belong to, and one team per channel keeps the mention
discipline clean.

**5. Set the model tiers** *(optional, recommended)*

```bash
./scripts/apply-tiers.sh          # --dry to preview first
```

**Quit Buzz before running this** — it rewrites its store on exit. This is what sets each agent's
effort level; nothing else does.

**6. Start the agents and say hello**

Start each agent from the Agents page, then in `#hive`:

```
@Mason read the repo at <path> and tell me what you'd change first.
```

In the Hive, talk to whichever agent owns the job — `@Mason` to review, `@Thistle` to build,
`@Pollen` for legwork. In the Swarm, talk **only** to `@Comet`: the coordinator decides who takes
what, and going around it breaks the rulebook loop.

Full walkthrough, including how to verify the coordinator is actually delegating, in
**[docs/setup.md](docs/setup.md)**.

## Docs

| | |
|---|---|
| **[Setup](docs/setup.md)** | Install, placeholders, model tiers, `respondTo`, editing agents in place, verifying that delegation happened |
| **[Protocol](docs/protocol.md)** | The rules both teams run — and the coordinator bug that made them necessary |
| **[Benchmark](docs/benchmark.md)** | A zero-dependency migration task for comparing the two teams |
| **[Field notes](docs/field-notes.md)** | Buzz internals that cost time to work out, plus the full reference list |
| **[Architectures](docs/architectures.md)** | The teams mapped onto LangChain's four multi-agent patterns — and the one Buzz can't express |

## Repo layout

```
teams/       importable buzz-team-snapshot v1 files
skills/      loadable SKILL.md procedures + install.sh
scripts/     apply-tiers.sh — per-agent model + effort
diagrams/    light + dark SVG, and the generator that builds both
benchmark/   generate.sh and the task brief
docs/
```

## License

MIT — see [LICENSE](LICENSE).

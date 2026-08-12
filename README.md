# buzz-agent-teams

Two ready-to-import agent teams for [Buzz](https://github.com/block/buzz) — a standing **Hive**
and a disposable **Swarm** — plus a benchmark task for comparing them.

Built following Block's [Effective teams of agents](https://engineering.block.xyz/blog/effective-teams-buzz),
with prompts written against Block's own reference personas in
[`benchmarks/harbor-buzz-orchestra`](https://github.com/block/buzz/tree/main/benchmarks/harbor-buzz-orchestra).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagrams/hive-vs-swarm.dark.svg">
  <img alt="Hive and Swarm team shapes side by side" src="diagrams/hive-vs-swarm.light.svg" width="680">
</picture>

The structural difference is the dashed **verification path**. The Hive has two peers who check
each other. The Swarm is an assembly line with a dedicated verifier whose verdict loops back to
the coordinator, who folds it into the rulebook before assigning the next batch.

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

**Hive** — one SmartBee and two WorkerBees, the exact shape the article benchmarked. No dedicated
verifier; Mason routes each WorkerBee's output to the other, so nobody reviews their own work.

| Agent | Tier | Model | Job |
|---|---|---|---|
| Mason | SmartBee | Opus 5 | Coordinates. Decides, assigns, reviews. **Does not implement.** |
| Thistle | WorkerBee | Sonnet 5 | Implements subtasks end to end. |
| Bramble | WorkerBee | Sonnet 5 | Second lane — and verifies Thistle, and vice versa. |

**Swarm** — a coordinator who owns an edge-case rulebook, a clonable worker, and a verifier.
Starting with one worker is deliberate: extra workers before the pattern is established just
multiply the same mistake.

| Agent | Tier | Model | Job |
|---|---|---|---|
| Comet | SmartBee | Opus 5 | Owns the work list and the **rulebook**. **Does not migrate.** |
| Clover | WorkerBee | Sonnet 5 | Applies the established pattern, batch by batch. |
| Willow | QuickBee | Haiku 4.5 | Verifies every batch. Pass or fail, no maybe. |

## Quick start

```bash
# 1. Create a channel per team in Buzz, then fill in the placeholders
sed -i '' 's/OWNER/Ada/; s/HIVE_CHANNEL_ID/<uuid>/'  teams/hive.team.json
sed -i '' 's/OWNER/Ada/; s/SWARM_CHANNEL_ID/<uuid>/' teams/swarm.team.json

# 2. Buzz Desktop → Agents → Agent teams → + → import each .team.json

# 3. Quit Buzz, then apply the model tiers
./scripts/apply-tiers.sh
```

Full walkthrough in **[docs/setup.md](docs/setup.md)**.

## Docs

| | |
|---|---|
| **[Setup](docs/setup.md)** | Install, placeholders, model tiers, `respondTo`, editing agents in place, verifying that delegation happened |
| **[Protocol](docs/protocol.md)** | The rules both teams run — and the coordinator bug that made them necessary |
| **[Benchmark](docs/benchmark.md)** | A zero-dependency migration task for comparing the two teams |
| **[Field notes](docs/field-notes.md)** | Buzz internals that cost time to work out, plus the full reference list |

## Repo layout

```
teams/       importable buzz-team-snapshot v1 files
scripts/     apply-tiers.sh — per-agent model + effort
diagrams/    light + dark SVG, and the generator that builds both
benchmark/   generate.sh and the task brief
docs/
```

## License

MIT — see [LICENSE](LICENSE).

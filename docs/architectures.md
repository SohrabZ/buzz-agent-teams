# Architecture patterns

[← README](../README.md)

LangChain's [Choosing the right multi-agent architecture](https://www.langchain.com/blog/choosing-the-right-multi-agent-architecture)
names four patterns: **Subagents**, **Skills**, **Handoffs**, and **Router**. This page maps them
onto this repo and onto what Buzz can natively express — including the one pattern it can't.

| LangChain pattern | Here | Status |
|---|---|---|
| Subagents — central orchestration | [Swarm](../teams/swarm.team.json) | ✅ close match |
| Skills — progressive disclosure | [`skills/`](../skills) | ✅ shipped |
| Router — classify, dispatch, synthesize | [Hive](../teams/hive.team.json), with you as the router | ◐ half match, by choice |
| Handoffs — state-driven transitions | — | ✖ deliberately not built |

## Subagents → the Swarm

The pattern: a supervisor invokes specialized workers, keeps the conversation context itself, and
synthesizes their results. Its scorecard strengths — parallelization and multi-hop execution — are
exactly a migration's profile, and its noted weakness (direct user interaction) doesn't matter
because Comet's job is to *not* need you.

Two deliberate differences from the LangChain shape:

- **Workers are persistent agents, not stateless tool calls.** They hold their own keys and can
  escalate — which enables the rulebook loop, where the supervisor *learns* from worker questions.
  The stateless version has no equivalent.
- **The one extra hop the pattern costs** ("results must flow back through the main agent") is a
  feature here, not overhead: the hop through Comet is where verification is enforced and rulings
  get recorded.

## Skills → `skills/`

The pattern: one agent, many specializations, loaded as context on demand instead of standing up
an agent per specialty. Buzz supports this natively — the
[persona pack spec](https://github.com/block/buzz/blob/main/crates/buzz-persona/PERSONA_PACK_SPEC.md)
defines `SKILL.md` bundles, and every Buzz install ships the `buzz-cli` skill this way.

This repo ships three, installable with [`skills/install.sh`](../skills/install.sh):

| Skill | Carries | Primary user |
|---|---|---|
| `verify-batch` | The full verification recipe and verdict rules | Willow |
| `review-checklist` | The review procedure, verdict order, calibration loop | Mason |
| `migration-pattern` | Pattern-document, work-list, and rulebook templates | Comet |

They complement the personas rather than replace them: the persona says *who the agent is and what
it owns*; the skill carries the *expanded procedure*, loaded only when doing that work. That split
is the pattern's known tradeoff managed — the deep content doesn't bloat every turn, and the
procedures are versioned here in git instead of living inside prompts.

Skills aren't team-scoped: any Claude-runtime agent in the nest can load them, so Thistle can pull
`review-checklist` before self-reviewing a diff it's about to hand to Mason.

## Router → the Hive, with you as the router

The pattern: a routing step classifies input and dispatches to the right vertical. The Hive has the
verticals — review / build / legwork, one memory slice each — but the classification step is you
choosing whom to `@mention`.

That's deliberate, and it's the article's own economics: routing adds a hop, and with one human on
the relay, you classify faster and more accurately than a dispatcher agent would. The half we
built is the half that pays.

The missing half becomes worth building when other people join your relay and don't know who does
what: a cheap dispatcher agent that wakes on mention, classifies, and re-mentions the right
specialist. Nothing in Buzz prevents it — it's one more `.agent.json`. Until then it would be a
toll booth with no traffic.

## Handoffs → deliberately not built

The pattern: an agent completes its stage and *state* determines which agent activates next —
customer-support flows, staged intake, sequential pipelines. It scores highest exactly where the
others score lowest: enforced sequential constraints.

The key word is **enforced**. LangChain implements this with a state machine underneath — the
handoff updates state, and the framework activates the next agent. Buzz has no such layer: an
agent wakes when a message mentions it, and nothing else activates anything. A Buzz "pipeline"
would be prompt-enforced — *please mention the next stage when you finish* — and a single
forgotten mention silently kills the whole chain, with every stage waiting on a message that will
never come.

That's the same class of silent failure this repo spent its hardest debugging day on (see
[protocol](protocol.md)), so we document the limitation instead of shipping it. If you genuinely
need staged flows on Buzz today, the honest version is the Swarm with a work list whose items are
stages — the coordinator *is* your state machine, and it can notice a stalled stage because it
owns the list.

## The scorecard, applied

The article rates each pattern on four axes. Where this repo's choices land:

- **Parallelization** — Subagents ⭐⭐⭐⭐⭐. The Swarm's coordinator explicitly runs independent
  batches across workers in parallel (never overlapping files).
- **Multi-hop execution** — Subagents ⭐⭐⭐⭐⭐. The assign → work → verify → record loop is
  multi-hop by construction.
- **Direct user interaction** — Skills ⭐⭐⭐⭐⭐. The Hive agents you talk to directly are the ones
  that load skills.
- **Distributed development** — both ⭐⭐⭐⭐⭐ patterns. Personas, skills, and teams are separate
  files; each can evolve independently, which is why this repo can exist as a repo.

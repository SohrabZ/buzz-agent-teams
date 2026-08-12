# The protocol

[← README](../README.md)

The teams differ in topology — the Hive is a flat trio you address directly; the Swarm is a
coordinator hierarchy — but both run the same working rules, taken from Block's reference
orchestrator and worker personas in
[`benchmarks/harbor-buzz-orchestra`](https://github.com/block/buzz/tree/main/benchmarks/harbor-buzz-orchestra).

## The rules

- **Coordinators do not do the work.** They read to decide, then assign. (Swarm — the Hive has
  no coordinator; the parallel rule there is that each agent stays in its own job: Mason judges
  but never builds, Pollen runs but never fixes.)
- **One step per message, one agent, explicit `@mention`.** An agent only wakes for messages that
  mention it by name — a message that mentions nobody reaches nobody and the work stalls with
  everyone waiting on someone else.
- **The coordinator assigns file ownership.** (Swarm) Agents share a filesystem; they are never
  left to negotiate collisions themselves. The Hive avoids the problem structurally — only
  Thistle edits code.
- **Wait for a report before assigning anything that depends on it.**
- **Independent verification, never self-review.** In the Swarm that's Willow. In the Hive,
  Thistle asks Mason before calling anything done.
- **Do the work before reporting it.** Never describe output you haven't produced; never claim
  success without showing what proves it.
- **On a blocking failure, report verbatim and stop** rather than improvising a different approach.
- **Finish with a `DONE:` message** that mentions the owner — never conclude silently. (Swarm —
  in the Hive you're already in a direct conversation, so each agent simply answers you.)

## Why the first rule is the important one

An earlier version of these prompts told the Swarm coordinator:

> *Before Clover touches anything: understand the project, do one unit of the work yourself, and
> write down the pattern.*

That sounds reasonable — you can't rule on edge cases you've never met. But it has **no stopping
condition**. "One unit" doesn't end anywhere, so the coordinator worked until the task was done.

A second team run the same day — whose coordinator was told the opposite, *keep your own turns
for judgment, hand the doing to a WorkerBee* — delegated correctly, against the same relay, with
the same duplicate agent records. That's what isolated the cause. It wasn't the mention plumbing
and it wasn't Buzz; it was one line of prompt.

(That second team was an earlier, coordinator-shaped version of the Hive. The Hive has since been
reshaped to the article's flat topology — see the README — which is why its current prompts have
no coordinator at all. The lesson carries over to Comet unchanged.)

Session counts from the agent logs, before the fix:

| Agent | Team | Sessions |
|---|---|---|
| Mason | Hive | 1 |
| Thistle | Hive | 1 |
| Bramble | Hive (since removed) | 1 |
| Comet | Swarm | 1 |
| Clover | Swarm | **0** |
| Willow | Swarm | **0** |

Block's reference persona opens with the guard that was missing:

> *"You do not run commands yourself; your workers do."*

and repeats it a paragraph later:

> *"Do not use the shell for task work — that is your workers' job."*

It's stated twice, first, in a prompt that's otherwise terse. That's not accidental.

The article is unambiguous in the same direction — where it says the coordinator "resolves most of
them itself," that's about **escalations**, not about doing the work:

> *"agents can call each other!!! A SmartBee can hand a subtask to a WorkerBee, wait, review what
> came back, and send it around again — without a human relaying anything."*

## What the personas deliberately leave out

Block's reference personas spell out the publishing and mention mechanics — `buzz messages send`
every turn, `@mention` the delegator when you finish. Those rules are right, and they are already
in buzz-acp's **`[Base]` layer**, which is compiled into the harness and prepended to every
message every agent receives. `[Base]` covers:

- publishing (*"a result exists only if you published it… ending that kind of turn without a
  message is a silent failure"*)
- mention mechanics — exact display names, no formatting, `--mention` for pubkeys, and *"only
  `@mention` when you need their attention"*
- threading and the reply destination from `[Context]`
- conversational agent creation via `buzz agents draft-create`
- startup recovery and workspace layout

So the personas here say none of it. [PERSONA_PACK_SPEC §5](https://github.com/block/buzz/blob/main/crates/buzz-persona/PERSONA_PACK_SPEC.md)
is explicit: restating base content means the reader sees it twice per message. Personas carry
only what is unique to the agent — its role, its memory slice, its team protocol.

> **This was wrong here once.** An earlier version of these prompts ended with *"Your reply is
> published to the channel automatically."* It is not, and it contradicted `[Base]` outright —
> an agent believing it could end up silently producing nothing. Corrected by deleting the
> section rather than rewriting it.

## What gets escalated to you

Comet — and each Hive agent individually — is told to absorb everything it can and bring you only
what's genuinely new.

| Coordinator resolves | Owner decides |
|---|---|
| Anything the rulebook or prior decisions already cover | A product decision you haven't made |
| Architecture, scope cuts, what "done" means | A tradeoff with no right answer |
| Who takes what, who verifies whom | Anything irreversible, or that spends money |
| Ambiguity the codebase itself settles | Anything touching production data or credentials |

The measure of a working team is that this traffic **thins out over time**. If you're being asked
things the team already resolved, that's a bug in the team, not in you.

# Stale claims inside the tooling files

> **A shared method, not a skill.** See [`WSS.CHECKS.md`](WSS.CHECKS.md). `--wss-tools` runs it
> over whatever it just edited; `--wss-full-check` runs it over every file in
> `WSS.record.tooling.sources`. `--wss-tools`'s prune job finds a neighbouring class — prose that changes
> nothing — proposing its cuts first, then applying them under this method.

**The rule is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule),
which is the authority and is not restated here.** In one line, because it
overrides the instinct to be helpful: *delete the mutable claim rather than
correcting it.*

What counts as one:

- **The count.** "Eight skills", "three hooks", "117 references". Any figure that
  moves when the thing it counts is added to.
- **The inventory.** A list of what currently exists, where the list is not the
  file that defines it.
- **The "currently X" followed by a list**, which is an inventory wearing a
  hedge.
- **The negative claim** — "nothing does Y", "no skill reads Z". True when
  written, and the first counterexample is silent.
- **The incident citation** — a date, an "it has happened here", an audit-pass
  number, a what-this-file-used-to-say. The mechanism clause defending the rule
  stays; the event moves to the decision log —
  [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)'s
  pattern rule, policed mechanically by `wss-doctor.sh`'s prose-date check.

What to do with one:

- **Delete**, don't fix. A corrected count buys one session of accuracy and
  re-arms the same trap.
- **Keep** the convention or the pointer that surrounded it, if there is one.
  The claim is what rots; the rule it illustrated usually does not.
- **A dated measurement is history like any other incident.** Correct as
  written — and relocated to the decision log with a pointer. The file keeps
  the rule the measurement established and how to re-take it, never the
  figure and its date.

**Scope, disposition and authorization are the runner's** — see
[`WSS.CHECKS.md`](WSS.CHECKS.md). This file says only what counts as a finding.

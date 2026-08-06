# The checks

**Methods, not skills.** Each file here is one way of finding inconsistency in
something the project has written down. A skill that needs to run one **reads
the file and applies it** over a scope the skill itself resolves.

## Why they are not in the skills that own them

Every one of these is borrowed. `--ws-full-check` and `--ws-stocktake` run the same
record taxonomy `--ws-check` does; `--ws-full-check` runs `--ws-docs`' audit and `--ws-tools`'
claim rule. A method borrowed by **citing another skill's headings** breaks
silently on a rename — the borrower checks nothing while reporting success — so
each method is its own file, and `doctor.sh`'s section-citation check polices
the citations that remain.

A method in its own file also keeps every runner thin: the taxonomy lives here
once, instead of swelling whichever skill happened to write it first.

## Method and runner

**A method says what counts as a finding. A runner decides the scope, what to do
with a finding, and who fixes it.** Keep new material on the right side of that
line — a method that mentions dispatch, or a checkpoint, or a flag's
authorization, has started being a runner and will not survive being borrowed by
the next one.

| Method | What it finds | Run by |
|---|---|---|
| [`record-drift.md`](record-drift.md) | the classes of drift in a record, and the things that look like drift and are not | `--ws-check`, `--ws-full-check`, `--ws-stocktake` |
| [`docs-audit.md`](docs-audit.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--ws-docs`, `--ws-full-check` |
| [`tooling-claims.md`](tooling-claims.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--ws-tools`, `--ws-full-check` |

**Scope never comes from here.** Incremental narrowing is the runner's, out of
[`sweep-checkpoint.md`](../sweep-checkpoint.md), and a full-scope run is a runner
ignoring it. A method that resolved its own scope could not serve both.

**Nor does authorization.** These files write nothing and confer nothing. Who may
write what is [`ownership.md`](../ownership.md); the grant is always the flag the
user typed.

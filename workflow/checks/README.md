# The checks

**Methods, not skills.** Each file here is one way of finding inconsistency in
something the project has written down. A skill that needs to run one **reads
the file and applies it** over a scope the skill itself resolves.

## Why they are not in the skills that own them

Every one of these was borrowed. `--full-check` and `--stocktake` run the same
record taxonomy `--check` does; `--full-check` runs `--docs`' audit and `--tools`'
claim rule. Before 2026-08-02 they reached those by **citing another skill's
headings** — "hand the reader `--check`'s *What to look for* section". That works
until someone renames a heading, at which point it breaks silently and the
borrower checks nothing while reporting success. `doctor.sh` grew a whole
section-citation check to police exactly that class.

A method in its own file cannot break that way, and the runner that borrows it
no longer has to load the borrowing skill to get at it.

**It also made the runners honest about their size.** Before the extraction
`--check` was nearly the size of `--full-check`, which reads as absurd for the
*incremental* sweep — almost half of it was this taxonomy, sitting in the skill
that happened to have written it first. Extracting it roughly halved that file,
which is now what its name says: a thin runner.

## Method and runner

**A method says what counts as a finding. A runner decides the scope, what to do
with a finding, and who fixes it.** Keep new material on the right side of that
line — a method that mentions dispatch, or a checkpoint, or a flag's
authorization, has started being a runner and will not survive being borrowed by
the next one.

| Method | What it finds | Run by |
|---|---|---|
| [`record-drift.md`](record-drift.md) | six classes of drift in a record, and the things that look like drift and are not | `--check`, `--full-check`, `--stocktake` |
| [`docs-audit.md`](docs-audit.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--docs`, `--full-check` |
| [`tooling-claims.md`](tooling-claims.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--tools`, `--full-check` |

**Scope never comes from here.** Incremental narrowing is the runner's, out of
[`sweep-checkpoint.md`](../sweep-checkpoint.md), and a full-scope run is a runner
ignoring it. A method that resolved its own scope could not serve both.

**Nor does authorization.** These files write nothing and confer nothing. Who may
write what is [`ownership.md`](../ownership.md); the grant is always the flag the
user typed.

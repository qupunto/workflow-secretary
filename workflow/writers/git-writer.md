# Writing the git history

> **A procedure, not a skill** — see [`README.md`](README.md). Sole writer of commits and tags, per [`ownership.md`](../ownership.md).

**Sole writer of commits and tags.** Every skill in this workflow that needs
either calls this one; who owns what is
[`ownership.md`](../ownership.md).

**Project facts come from `.claude/workflow.json`**: `branch.integration` is
what ordinary work goes to, `branch.publish` is what `--release` tags, and
`commitTrailer` names the session trailer. Without a manifest, fall back to the
current branch and say so in one line.

**No flag of its own**, on the same reasoning as `handoff-writer` and
`sweep-tracker` — and one reason particular to this skill: a flag is how a user
confers authorization, and this skill must never confer any. The grant is always
the caller's.

## Why the history has an owner at all

The history is a record, and this workflow's invariant is that every record has
exactly one writer — [`ownership.md`](../ownership.md) is the
authority on that and on which flags grant what. The rules below live here rather
than in each caller's file so that a flag granting COMMIT grants it to one
disciplined writer instead of to whatever the moment suggested.

Every rule here exists because breaking it is **silent**. A trailer in the wrong
paragraph makes the liveness check find nothing. A `git add -A` publishes
whatever else was in the tree. A push carries another session's unreviewed
commits along with yours, and reports success.

## The grant is the caller's, always

**Read the grant out of the matrix in
[`ownership.md`](../ownership.md)**, "Authorization the flag grants".
This file used to restate it as a table of its own — a third hand-maintained copy
of a grant list, next to the matrix and the block `shorthand-flags.sh` injects.
`doctor.sh` compares exactly those two and would never have caught this one
drifting, which is the reason `README.md` gives for refusing a third copy there.
It was in sync when deleted; nothing kept it so.

Two grants the matrix's row does not spell out, because they belong to the step
rather than to the flag: under `--pullrequest` **the merge** needs a fresh OK of
its own, not just the push; under `--release` so does **the tag**. In both cases
the caller has already obtained it — you are not the one to ask.

**The matrix lists flags, not callers.** A skill reached by dispatch carries the
grant of the flag the *user* typed, however many hops away — a `--docs` invoked
by `--tools` arrives with `--tools`' commit-and-not-push, not with `--docs`'
nothing. Trace back to the flag; do not read an absent row as a refusal.

If you cannot tell which grant is in force, you are not authorized. Ask.

**Never push under an inherited commit-only grant**, however obvious the push
looks. That distinction is the whole reason three grants exist rather than one.

## Commits

**Coherent commits, not one dump.** Group the working tree the way the work
actually divided, with real messages saying *why*. A single "wrap up session"
commit destroys the only cheap explanation the next reader will ever get.

**Stage files by name. Never `git add -A`.** The tree may hold another session's
work, a scratch file, or a record this caller does not own.

**Stamp every commit with the session that made it**, using the trailer the
manifest names in `commitTrailer` and the first block of the session id, always
available in the scratchpad path. Without it, commits from concurrent sessions
are indistinguishable — same author, same branch, interleaved by time.

It must sit in the **same final block** as `Co-Authored-By`, with no blank line
between them:

```
Claude-Session: 9a933d25
Co-Authored-By: <the attribution line this session was given>
```

Do not copy a model name out of this file — take the `Co-Authored-By` line the
harness supplies for the running session. A name written down here is wrong the
moment the model changes, and wrong in a way nothing detects.

Git parses only the last paragraph of a message as trailers. A blank line above
`Co-Authored-By` demotes the session trailer to ordinary body text — a
`%(trailers:key=…)` query then returns empty and the liveness check below
silently finds nothing. Verify rather than assuming:

```bash
git log -1 --format='%(trailers:key=Claude-Session,valueonly)'
```

**Be honest about verification.** State whether `commands.test` and
`commands.typecheck` actually ran against what is being committed. If they did
not, say so rather than implying green.

**Interrupted work still gets committed** when the caller asks for it — but say
so in the commit message. Never describe unverified work as done.

## Pushes

**Check whose work you are about to publish.** `git push` publishes a *ref*, not
a selection of commits: if another session's commit is an ancestor of yours,
pushing yours publishes theirs too, and cherry-picking cannot avoid it.

```bash
git log origin/<branch>..<branch>
```

Say plainly if it contains commits this session did not make — they have not
been reviewed here. The real fix is one worktree per session, which removes the
shared branch entirely; on a shared checkout, honest reporting is all there is.

**Is the other session still running?** Two signals, in this order:

1. `pgrep -x claude | wc -l` — how many sessions exist at all. **`1` means you
   are alone and no further check is needed.**
2. If more than one, read each foreign commit's `Claude-Session` trailer and
   check that session's transcript:
   `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl`. A recent mtime means
   live; minutes stale means finished.

A PID cannot be mapped back to a session id — the process environment does not
carry it — which is exactly why the trailer exists.

**Never force-push, and never resolve a rejected push by force.** A rejection
usually means another session pushed first, and that is a merge decision for the
caller to take back to the user, not something to resolve here. No `--amend`, no
`--no-verify`, no `--no-gpg-sign`.

**Never rewrite a commit you did not make** unless the user said so explicitly,
naming the commit. Rewriting under a session that turns out to be live desyncs
it, and "finished" is an inference. A stale transcript is evidence, not proof.

## Tags

Only `--release` calls for one, and only after it has shown the user the commits,
the tag name and the branch and received an explicit OK **in that turn**.

```bash
git tag -a vX.Y.Z -m "<milestone name>"
git push origin <branch>
git push origin vX.Y.Z
```

**This skill never asks for that confirmation and never proceeds without it.** A
primitive has no channel to ask — the same reason `agents.release` prepares the
material and never publishes it. If the caller has not said the OK was given in
that turn, stop and hand back.

A tag is the one thing here that cannot be undone: once another checkout has
fetched it, deleting it locally changes nothing.

## What this skill does not do

- **It does not decide to commit or push.** No judgement about whether the work
  is ready, whether the milestone is done, or whether now is the moment.
- **It does not write any record file.** Not the changelog, not the roadmap,
  not the handoff — those have their own owners, and a commit is not a licence
  to adjust what is in it.
- **It does not rebase, revert or branch.** Those are decisions with a user in
  the loop, and none of them is history this workflow authors. **The one merge
  it does perform** is the one `--pullrequest` hands it, with the method from
  `branch.mergeMethod` and only once `pr-flow` has the user's OK in that turn —
  [`ownership.md`](../ownership.md)'s `merge` row is the authority,
  and it is the reason a merge commit has an owner at all.
- **It does not clean the tree.** No `git stash`, no `git checkout --` over
  someone's changes, no deleting untracked files.

# User-level context

Loaded in every session, in every project. Keep it short: anything belonging to
one project belongs in that project's own handoff or record files, not here.

## The workflow is global

Most skills live in `~/.claude/skills/` and are shared by every project. They
take project-specific facts from **`.claude/workflow.json`** in the working
directory.

**One suite, many projects — and a record holds only its own.** Another project
on this machine reaching a session, through a shared inbox or a question asked
mid-batch or a checkout in the next directory, confers no ownership. Say what
was noticed, then file it in *that* project's record and lane. Never here, and
`decisions` is not an exception. `record-contract.md` carries the rule and the
one case that does belong: a change to this project's own machinery, written
from this project's facts and naming no other.

Three files are the authority and settle any disagreement between skills:

- `~/.claude/workflow/ownership.md` — who may write what
- `~/.claude/workflow/record-contract.md` — what each record holds
- `~/.claude/workflow/manifest.md` — which keys a manifest may set

**What each one governs, what a project without a manifest falls back to, and
where these paths resolve under a plugin install rather than a clone, is the
`ws-contracts` skill.** It is canonical; the paths above are here so
routing itself costs no lookup. `~/.claude/README.md` covers the `--flag`
shorthands; what each one authorizes is `~/.claude/workflow/ownership.md`'s
matrix.

## Run the doctor rather than trusting an inventory

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/doctor.sh
```

Read-only, and it prints what it checks. Run it rather than believing any count
or list written in a markdown file, including this one.

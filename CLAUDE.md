# User-level context

Loaded in every session, in every project. Keep it short: anything belonging to
one project belongs in that project's own handoff or record files, not here.

## The workflow is global

Most skills live in `~/.claude/skills/` and are shared by every project. They
take project-specific facts from **`.claude/workflow.json`** in the working
directory.

Three files are the authority and settle any disagreement between skills:

- `~/.claude/workflow/ownership.md` — who may write what
- `~/.claude/workflow/record-contract.md` — what each record holds
- `~/.claude/workflow/manifest.md` — which keys a manifest may set

**What each one governs, what a project without a manifest falls back to, and
where these paths resolve under a plugin install rather than a clone, is the
`ws-contracts` skill.** It is canonical; the paths above are here so
routing itself costs no lookup. `~/.claude/README.md` covers the `--flag`
shorthands and what each one authorizes.

## Run the doctor rather than trusting an inventory

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/doctor.sh
```

Read-only, and it prints what it checks. Run it rather than believing any count
or list written in a markdown file, including this one.

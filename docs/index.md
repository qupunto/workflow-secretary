# workflow-secretary — Documentation

**workflow-secretary** is a suite of Claude Code skills that act as a *secretary to
coding rather than a coder*: they keep a project's backlog, decision log,
roadmap, documentation and tooling catalog matching what the code actually does.
Anything needing stack knowledge — architecture, correctness, security, the data
model — is deliberately absent, so judge it as a project secretary rather than a
programming assistant. There is no runtime and no build: the project is markdown
instruction files, a handful of shell scripts and a CI workflow.

The repository **is** `~/.claude`. It does not install into that directory; the
directory is the working tree.

---

## Contents

| File | Description |
|---|---|
| [overview.md](overview.md) | Repository layout, what a session loads and when, what can be switched off and what cannot, the scripts, and the verification commands |

## Annex

| File | Description |
|---|---|
| [annex/claude-tooling.md](annex/claude-tooling.md) | Every skill and script, what each is for, the tier diagram, and who invokes whom |

---
name: ws-docs
description: "Author and maintain a project's long-form documentation site, every claim anchored to an exact source path. Invoke on `--ws-docs`, `/ws-docs`, \"document this project / feature / module\", \"write docs for X\", \"update the docs after <change>\", \"set up docs\", or a request for an ADR, architecture write-up, runbook, glossary or onboarding guide."
---

# docs

Renders as a docsify site by default — plain markdown that also reads correctly on GitHub.

## Invocation

`/ws-docs` invokes this skill by name, and `--ws-docs` fires it through the hook — both are the same
request. Bare, either means *document what we just worked on*: infer the target from
the conversation — the files touched this session, the feature just built — and say what you
picked before writing. With an argument (`--ws-docs auth`, `--ws-docs the map module`) that's the
target.

**`--ws-adopt` also invokes this** when it finds a project with no documentation at all, wanting
Scaffold mode and the overview page — not a full site. It confers its own grant, which is
commit and not push, so what gets scaffolded there may be committed even though this flag
alone authorizes nothing.

**`--ws-tools` invokes this too**, handing over `record.tooling.catalog` for you to adapt into a
**Claude tooling** annex page (T11). The catalog is the source and stays that skill's; the page
is yours — its wording, its placement, and its index and sidebar rows. Re-render its
interaction diagram for this site's renderer under `references/style-guide.md`'s three
rules rather than reshaping it by hand. Adapt what you are given and **do not invent edges the catalog does not claim**.

## The two records this skill no longer writes

`record.behaviour` and `record.reference` each have their own primitive —
[`behaviour-writer`](../../workflow/writers/behaviour-writer.md) and
[`reference-writer`](../../workflow/writers/reference-writer.md). This skill owns **the site**,
and those two files are records, not pages.

**Dispatch findings about them straight to the owner** — `--ws-check`,
`--ws-full-check`, `--ws-start` and `--ws-stocktake` do this already; the split is
[`ownership.md`](../../workflow/ownership.md#when-to-split)'s.

What stays here is the judgement, not the write: **whether a subject belongs on
the site at all**, which tier it lands in (`references/taxonomy.md`, G17), and
whether a page is owed. Where a subject turns out to be a runtime rule or a piece
of reference material rather than a guide page, hand it to the owning primitive
and say so — do not write it into a page instead.

## Not this skill

This skill owns exactly one job: the
long-form docs site under `docs/`. Hand these back instead of firing:

| Request | Belongs to |
|---|---|
| Docstrings, JSDoc, TSDoc, inline comments | Ordinary code editing — just write them |
| OpenAPI/Swagger annotations in handlers | Ordinary code editing (the *guide* to the API is this skill) |
| `CLAUDE.md` — instructions for agents, not humans | `handoff-writer`, which owns it as the session handoff |
| Changelog entries | `changelog-writer`, which owns `record.changelog` |
| Commit messages | `git-writer`, which owns the history |
| PR descriptions | `ws-pr` (`--ws-pr`), which drafts the body from the branch range. It is not a record and is never written to a file here |
| A one-line README tweak | Just edit it; no site, no taxonomy — **unless** the manifest maps the README into `record.reference`, which makes it `reference-writer`'s |
| A runtime rule, or stack/architecture/data-model material | `behaviour-writer` and `reference-writer`, which own `record.behaviour` and `record.reference` |
| A project's *append-only* record — backlog, roadmap, decision log, audit log | The record primitives: `--ws-todo`/`--ws-log`, `--ws-plan`, `--ws-stocktake`. Appending a dated entry is not writing a page, and those files are never placed by tier |

**A project-scoped docs skill wins.** If `.claude/skills/` contains a skill that owns this
project's documentation, it encodes conventions this one cannot know — defer to it and say so.
Only step in for the part it explicitly does not cover.

## Modes

Determine the mode first; they don't overlap. Detect the existing setup before anything else:

```bash
ls docs/ doc/ documentation/ website/ 2>/dev/null
ls mkdocs.yml docusaurus.config.* mint.json .vitepress 2>/dev/null   # a different renderer?
ls .claude/skills/ 2>/dev/null                                       # a project docs skill?
cat docs/index.html docs/_sidebar.md 2>/dev/null                     # docsify?
```

| Condition | Mode | Go to |
|---|---|---|
| A project-scoped docs skill exists | **Defer** — hand off, don't duplicate | — |
| No docs directory anywhere | **Scaffold**, then write the first page | [Scaffold](#scaffold) |
| Target has no page or section yet | **New page** (or new `##` section) | [Write](#write) |
| Target is already documented, and code has changed | **Update** — rewrite the affected sections only | [Update](#update) |
| Asked to check/verify/audit docs, or a refactor just landed | **Audit** | [`workflow/checks/docs-audit.md`](../../workflow/checks/docs-audit.md) |
| Asked to add or refresh a language | **Translate** | `references/translations.md` |

**Audit mode is about this site's *internal correctness*** — do the paths exist, do links and
anchors resolve, do enumerations and `## Key files` still match source. It is not about whether
a project's record *owes* an update: "a diff touched the routes and `behaviour.md` never changed"
is `--ws-check`'s finding, not this skill's. Don't run both against the same request.

### Audit scope

Resolving it is this skill's job, not the method's — a method that picked its own scope
could not be borrowed by a caller that wants a different one.

Sections 1–7 are shell. They run over the whole site in seconds and there is nothing to
save by narrowing them — **always run them in full.** Section 8's second half is the
expensive one: re-reading source files page by page. That is what the checkpoint is for,
and `--ws-full-check` is what forces every page to be re-read.

Ask `sweep-tracker` to resolve the entry `docs`, with two scopes:

| Scope | Incremental? | `covered` |
|---|---|---|
| `mechanics` | No — the scripts are cheap and a whole-site run is the point | `[]` |
| `accuracy` | Yes | the pages whose claims were re-read against source this run |

**A page needs re-reading when the page changed, or when any source file it names
changed.** G3 is what makes that mechanical — every claim is attributed to a backticked
path at the point it is made, so a page's dependencies are already written down in it:

```bash
BASE=<baseline sha>
CHANGED=$(git diff --name-only "$BASE"..HEAD)
for f in $(find docs -name '*.md'); do
  git diff --quiet "$BASE"..HEAD -- "$f" || { echo "STALE (page edited): $f"; continue; }
  # every backticked path the page attributes a claim to
  deps=$(grep -ohE '`[A-Za-z0-9_.$/-]+/[A-Za-z0-9_.$/-]+`' "$f" | tr -d '`' | sort -u)
  for d in $deps; do
    printf '%s\n' "$CHANGED" | grep -qF "$d" && { echo "STALE (source moved): $f <- $d"; break; }
  done
done
```

Everything that prints is in scope. Everything else was verified at `$BASE` and neither it
nor anything it cites has moved since.

**Two things void the narrowing entirely**, because they change what a correct page even
looks like:

- **A page with no backticked source path at all.** It has no detectable dependencies, so
  the diff can never mark it stale. It is `not-covered` unless read — never silently clean.
- **A change to the docs' own conventions** — the taxonomy, the style guide, `_sidebar.md`
  structure. Those invalidate every page's *form*, not just its facts.

**When in doubt, widen.** A page wrongly skipped reports clean while asserting something
false.

Stamp at the end through `sweep-tracker`: the baseline, and per scope what was covered.
The rules constraining what may be claimed are
[`sweep-checkpoint.md`](../../workflow/sweep-checkpoint.md).


**An existing site is the authority on its own conventions** — read two or three of its pages
first and match them wherever they differ from this skill. When a project states those
conventions machine-readably — `record.*` in a `.claude/workflow.json` naming files at fixed
locations — that declaration is the authority: those files keep their paths, skip tier
placement (G17) and skip sidebar wiring (G12), and you update them in place.

That includes the renderer. Everything in this skill except `references/site-setup.md` and the
sidebar/link mechanics is renderer-agnostic: on MkDocs, Docusaurus, VitePress, Mintlify, or a
plain markdown folder, keep the guidelines, the taxonomy, and the audit checks, and swap only
the navigation file and link syntax for that tool's. Never migrate a project to docsify because
this skill prefers it.

## Plan

Before writing anything in Scaffold or New-page mode, decide the page set. `references/taxonomy.md`
defines the canonical tiers (T1–T11), the pages under each, an include-when rule per page,
and minimum viable sets per project profile (web, mobile, API, full-stack, library, data,
monorepo).

1. Identify the project's shape and pick the closest profile.
2. Walk the tiers in order, keeping a page **only if the thing it documents exists in the
   codebase today** — not if it should (G8).
3. Merge at small scale, split at large: below ~6 items keep a table on the guide page;
   past ~250 lines or two audiences, split (G14, G15).
4. **State the proposed page set before writing it**, in tier order, and say what you
   dropped and why. Then write pages one at a time, wiring each up as you go (G12).
5. **A page set larger than one session is state, and this skill stores none.** Hand the
   unwritten pages to `--ws-todo` so they outlive the session in the project's backlog, and
   `--ws-track` them within it. Never keep the plan only in the reply — on a large site that is
   how half a documented codebase silently becomes the whole record of what was intended.

Never emit the whole tier list as headings-with-a-sentence. Tier-shaped emptiness signals
coverage that isn't there and discredits the pages that are real.

## Guidelines

Numbered so they can be cited in review. **G1, G2, and G8 are what make these docs worth
having**; the rest are mechanics.

> Numbers are **append-only**. They are cited from every reference file in this skill, so
> renumbering silently invalidates those citations. A new guideline takes the next free number
> regardless of where it belongs thematically; a retired one keeps its number and is marked
> retired rather than removed.

**Content**

- **G1 — Read the source first.** Open every file you will name. Copy type definitions
  verbatim. Never document from inference; a plausible-but-wrong doc is worse than none.
- **G2 — Every paragraph carries a *why*.** State the mechanism, then why it is that way:
  `because`, `so that`, `instead of`, `otherwise`. A sentence with no *why* usually restates
  the code — cut it.
- **G3 — Name the file, inline, in backticks.** Every function, type, and behavior is
  attributed to `src/where/it/lives.ts` at the point it is described.
- **G4 — Record the rejected alternative.** When a choice looks arbitrary, document what the
  obvious approach would have broken.
- **G5 — Elide code.** Show the shape that matters; cut the rest with `/* ... */` or `# ...`.
  Never paste a whole file.
- **G6 — Cross-link instead of restating.** Say a thing once, on the page that owns it; link
  to it from everywhere else, anchor-deep where useful.
- **G7 — Mark what isn't live.** Unused or aspirational code gets flagged as such; generated
  files get a loud **Do not edit it by hand.**
- **G8 — Never invent rationale.** Can't find why? Write "reason unclear" or leave it out.

**Mechanics**

- **G9 — Verify before declaring done.** Every path exists, every link and `#anchor` resolves,
  every fence is tagged — and every asserted symbol and value is confirmed against source
  (`workflow/checks/docs-audit.md` §8). Mechanics can be checked by script; accuracy needs re-reading the source.
  Don't eyeball either.
- **G10 — Tables for anything enumerable.** Routes, endpoints, props, tokens, env vars,
  dependencies, key files.
- **G11 — Close file-mapped pages with `## Key files`**, naming the actual exports.
- **G12 — A page enters `_sidebar.md` and `index.md` in the same change that creates it.**
  Never scaffold an empty page; never add content without its index entries.
- **G13 — Every translation mirror updates in the same change.** One stale language is worse
  than one language.

**Scope**

- **G14 — Extend before adding.** A new top-level page is justified only when a reader would
  look for that concern by name in the sidebar. Otherwise it's a `##` on the nearest page.
- **G15 — Push per-item detail to `annex/`** once it crowds out the concept the page teaches.
  Guide pages explain how a layer works; annex pages enumerate its members exhaustively.
- **G16 — Code wins.** Where docs and source disagree, the source is right. Fix the doc and
  report the drift you found.
- **G17 — Place by tier, not by convenience.** `references/taxonomy.md` fixes which tier a
  subject belongs to, so the same concern lands in the same place in every project. Sidebar
  depth is negotiable; tier ownership is not.

## Scaffold

Only when no docs directory exists. The script creates the shell — never content:

```bash
# Resolve the suite root: a checkout wins, otherwise the plugin's versioned
# cache. Why it is done this way rather than from a variable is measured, and
# recorded in the `ws-contracts` skill.
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)

bash "$S"/skills/ws-docs/assets/scaffold.sh docs "<Project Name>" [root-lang [translation-lang ...]]
```

```bash
bash "$S"/skills/ws-docs/assets/scaffold.sh docs "Acme UI"        # monolingual
bash "$S"/skills/ws-docs/assets/scaffold.sh docs "SIME UI" en ca  # root English, docs/ca/ Català
```

It refuses to touch an existing directory, skips `_navbar.md` unless multilingual, and
prints the remaining steps it deliberately does not do: the `docs:dev` script and
`docsify-cli` dependency, the README pointer, and the `{{INTRO}}` placeholder. Do those,
then continue into [Write](#write) — starting with `overview.md`, which inventories the
stack, scripts, env vars, and directory tree that every later page links back to.

Config rationale and the manual equivalent: `references/site-setup.md`.

## Write

1. **Read the source** (G1). Collect: exact paths, verbatim type definitions, the reason
   behind each odd-looking choice (check comments, git log, blame), and the gotchas —
   library bugs worked around, ordering constraints, things that look wrong but are
   load-bearing.
2. **Place it** (G17, then G14/G15). Find the subject's tier in `references/taxonomy.md`.
   Then: guide page → `docs/<concern>.md`; exhaustive item-by-item reference →
   `docs/annex/<topic>.md`; too small for either → a `##` on the closest existing page.
3. **Draft** from the skeletons in `references/page-anatomy.md`, following
   `references/style-guide.md` for prose and formatting.
4. **Wire it up** (G12): `_sidebar.md`, `index.md` table, `README.md` if it has one, and
   every translation mirror (G13).
5. **Verify** (G9) with [`workflow/checks/docs-audit.md`](../../workflow/checks/docs-audit.md) — mechanics *and* §8 accuracy — then render it
   with the project's docs script and load the page.

## Update

The most common mode, and the one most often done badly — resist rewriting the whole page.

1. **Diff what actually changed**: `git log --oneline -20`, `git diff main...HEAD --stat`.
2. **Find every page that mentions it** — one change is usually described in several places
   (a guide page, an annex entry, a `## Key files` row, a route table, the mirror):
   ```bash
   grep -rn "OldName\|old/path" docs --include='*.md'
   ```
3. **Rewrite only the affected sections**, re-reading the new source for each (G1).
   Enumerated tables are the usual casualty — a renamed prop or a new endpoint invalidates
   a row, not the page.
4. **Check the rest of the page for consequences**: does the intro still describe the
   current arrangement? Does every `## Key files` row still name real exports? Did a heading
   rename break inbound anchors? `grep -rn '#the-old-slug' docs`.
5. Mirrors (G13), then verify (G9).

If the code changed *because the old design was wrong*, the doc's *why* changes too — not
just its *what*.

## References

| File | Read it when |
|---|---|
| `references/taxonomy.md` | Deciding what pages a project needs, and which tier a subject belongs to |
| `references/tier-mobile.md` | The project has a mobile app (loaded from taxonomy, skip otherwise) |
| `references/tier-governance.md` | A compliance, legal, or regulatory obligation applies |
| `references/style-guide.md` | Writing or reviewing prose — voice, formatting, the full *why*-per-paragraph rules |
| `references/page-anatomy.md` | Starting a page — skeletons for guide pages, annex references, index, sidebar |
| `references/site-setup.md` | Scaffolding, or changing docsify config |
| `references/translations.md` | The site is or should be multilingual — mirror rules, the anchor trap |
| [`workflow/checks/docs-audit.md`](../../workflow/checks/docs-audit.md) | Verifying anything, or hunting drift after a refactor |
| `assets/scaffold.sh` | Creating the site shell |

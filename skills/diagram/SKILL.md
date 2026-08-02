---
name: diagram
description: "Draw the picture of a system — architecture, data flow, a state machine, a dependency or invocation graph — in whatever form the display can actually render. SHORTHAND: `--draw`. Also trigger on \"diagram this\", \"show me how these fit together\", \"visualize the flow\"."
---

# Drawing a system

**This skill writes nothing.** It reads the source, works out the shape, and
returns a rendered block for its caller to place. That is not modesty about
scope: a diagram belongs *inside* a file that already has an owner, so a skill
that wrote it directly would be a second writer on every page it touched. Who
owns what is [`~/.claude/workflow/ownership.md`](../../workflow/ownership.md).

It owns a **craft**, not a record — the one primitive in this workflow that
does. Everything below is the craft.

## The `--draw` shorthand

Invoking it is always safe: nothing is written and nothing is irreversible. Used
bare it means *draw what we were just discussing*; with an argument, that is the
subject. Where a flag counts, and what it authorizes, is in `shorthand-flags.sh`
and [`~/.claude/README.md`](../../README.md).

## 1. Find out what will render it, before choosing a form

The single most common failure is a diagram written in a syntax the display does
not support, which ships raw markup to every reader and looks broken rather than
missing. **Check first; do not assume.**

Three forms, in preference order:

1. **ASCII in a plain fence — the default.** It renders in every tool, on
   GitHub, in a terminal, and in a diff. It is greppable and reviewable: a
   reader sees the change in a pull request rather than a re-rendered image.
   It costs nothing and cannot break.
2. **Mermaid, only where the renderer is confirmed to support it.** GitHub
   renders it natively. MkDocs Material and Docusaurus support it with
   configuration. **docsify needs a plugin** that a default `index.html` does
   not load — so check the actual config rather than the tool's name. Prefer it
   only for graphs genuinely too tangled for ASCII: state machines with many
   transitions, dependency graphs that cross.
3. **Images — effectively never.** They break the text, diffable and greppable
   properties the rest of a documentation set depends on, they go stale
   invisibly, and they cannot be reviewed.

Where you cannot determine the renderer, use ASCII. It is the form that is never
wrong.

## 2. Read the source. Never draw from inference

Every box and every arrow is a claim about the system. Open the files. A
plausible-but-wrong diagram is worse than none, because a picture is trusted
more readily than a paragraph and checked less often.

**When a caller hands you material** — a catalog, a page, a set of findings —
you are rendering *its* facts. Do not add edges it does not claim, however
obvious the missing arrow looks. If the material seems incomplete, say so and
hand it back rather than filling the gap yourself.

Where a relationship exists but you cannot establish its direction, leave it out
and note the omission. An arrow pointing the wrong way is read as fact.

## 3. Show the shape, not every edge

A complete graph of a mature system is a hairball, and a hairball is not read.
Decide what question the picture answers, then draw only what answers it.

- **Layers and direction** carry more than an arrow per call.
- **Group before you connect.** Three boxes with one arrow between the groups
  beats nine boxes with twelve arrows.
- **Label the flows, not the boxes.** What travels along the arrow is the part a
  reader cannot guess; what the box is called is usually already in the prose.

**A table often beats a diagram.** Three storage layers with a "why not one of
the others" column carries more than three boxes would, and stays true longer.
Say so when it is the better answer — returning "this wants a table, here it is"
is a complete and correct outcome.

## 4. Mechanics

- **Keep ASCII under about 80 columns** so it never wraps. A wrapped diagram is
  unreadable in exactly the places ASCII was chosen for.
- **Put the *why* in prose underneath.** A diagram shows structure; it cannot
  explain a decision, and trying to make it do so produces a cluttered picture
  and an unexplained decision.
- **Say what the picture leaves out**, in one line, where the omission is
  material. A reader who knows the diagram is partial can trust the part that
  is drawn.

## 5. Diagrams go stale differently

Prose that falls out of date usually reads oddly. **An arrow stays plausible
long after it stops being true**, and nothing about looking at it suggests
re-checking. So a diagram is only as current as whatever re-derives it.

That is the caller's job, not this skill's: the owner of the file holding the
diagram refreshes it on the same trigger that updates the rest of that file, by
invoking this skill again. A diagram nobody re-derives is the stale inventory
that this workflow deletes everywhere else.

## What this skill does not do

- **It does not write, edit or create any file.** It returns a block. The caller
  places it, under the caller's grant.
- **It does not invent edges**, and it does not complete a caller's material.
- **It does not add a renderer to a project.** If a project would need a plugin
  to display Mermaid, that is a change someone decides on, not a side effect of
  asking for a picture. Draw ASCII and say why.
- **It does not decide what a system should look like.** It draws what is there.
  A diagram that quietly depicts the intended design rather than the built one
  is the most expensive kind of wrong.

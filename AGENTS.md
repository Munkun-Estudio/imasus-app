# imasus-app — Agent Instructions

This project uses **Munkit** for durable project context. Read the workspace files before making architectural or product-shaping changes.

## Read First

- `.munkit/MEMORY.md` — concise project memory: patterns, gotchas, terminology, stack, and boundaries
- `.munkit/DECISIONS.md` — append-only architectural decisions and rationale
- `.munkit/context.md` — optional deep product or domain context; `## Design Context` is the source of truth for audience, tone, and design direction
- `.munkit/specs/` — feature specifications; check the active spec first if one exists

## Working With Munkit

- Use `munkit status` to inspect the workspace.
- Use `munkit design show` before substantial UI/design work, and `munkit design review [area]` when you need a structured critique brief.
- Use `munkit spec list`, `munkit spec show`, and `munkit spec search` to understand active and past work.
- Use `munkit spec new <name>` when the user wants a new feature or initiative scoped explicitly.
- Use `munkit remember gotcha|pattern|term ...` for short durable memory entries.
- Edit `.munkit/MEMORY.md` or `.munkit/context.md` directly when the change is substantial or structured.
- Use `munkit decide "<title>"` to record durable architectural choices once the title and reason are clear.

## Specs

Each spec contains:

- `brief.md` — requirements, context, and acceptance criteria
- `notes.md` — implementation notes, discoveries, and scratch space

When implementing a spec:

1. Read `brief.md` first.
2. Check `notes.md` for prior findings.
3. Update notes if you discover constraints worth preserving during the feature work.

## Commands

Prefer project-local execution in this order:

```bash
bin/munkit status
bundle exec munkit spec list
munkit spec show <slug>
```

If the repo uses `asdf`, prefer:

```bash
asdf exec bin/munkit status
```

For `munkit decide`, remember it prompts for a reason. In automation, pipe the reason:

```bash
printf '%s\n' "Reason for the decision." | bin/munkit decide "Decision title"
```

## Guardrails

- Do not treat `MEMORY.md` and `context.md` as interchangeable.
- Do not infer design direction from the UI alone when the project has already captured it in `## Design Context`.
- Do not invent decisions or specs the user has not actually made.
- Prefer updating the Munkit workspace when durable project knowledge changes, instead of leaving that context only in chat.

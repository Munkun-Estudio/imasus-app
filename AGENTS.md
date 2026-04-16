# imasus-app — Agent Instructions

This repository keeps durable project context under `.munkit/`. Read those files before making architectural or product-shaping changes.

## Read First

- `.munkit/MEMORY.md` — concise project memory: patterns, gotchas, terminology, stack, and boundaries
- `.munkit/DECISIONS.md` — append-only architectural decisions and rationale
- `.munkit/context.md` — optional deep product or domain context; `## Design Context` is the source of truth for audience, tone, and design direction
- `.munkit/specs/` — feature specifications; check the active spec first if one exists

## Working With Project Context

- Use the active spec under `.munkit/specs/` to understand the current slice of work before making non-trivial changes.
- Read `brief.md` before implementation and `notes.md` before repeating discovery work.
- Edit `.munkit/MEMORY.md` or `.munkit/context.md` directly when the change is substantial or structured.
- Record durable architectural choices in `.munkit/DECISIONS.md` once the title and reason are clear.

## Parallel Worktrees

- Use one branch per worktree and one discrete slice of work per branch.
- Do not have two agents edit the same file concurrently. If the scopes start to overlap, stop and re-split the work.
- Sync each worktree from `main` before starting a new slice.
- Keep commits and PRs small enough that another contributor can review them without reconstructing hidden chat context.
- Record durable findings in `.munkit/MEMORY.md`, `.munkit/DECISIONS.md`, or the relevant spec `notes.md`, not only in chat.
- When one worktree lands first, rebase or merge forward in the other worktree before continuing.

## Specs

Each spec contains:

- `brief.md` — requirements, context, and acceptance criteria
- `notes.md` — implementation notes, discoveries, and scratch space

When implementing a spec:

1. Read `brief.md` first.
2. Check `notes.md` for prior findings.
3. Update notes if you discover constraints worth preserving during the feature work.

## Guardrails

- Do not treat `MEMORY.md` and `context.md` as interchangeable.
- Do not infer design direction from the UI alone when the project has already captured it in `## Design Context`.
- Do not invent decisions or specs the user has not actually made.
- Prefer updating the `.munkit/` files when durable project knowledge changes, instead of leaving that context only in chat.

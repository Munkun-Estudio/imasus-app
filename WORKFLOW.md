---
tracker:
  kind: github
  endpoint: https://api.github.com/graphql
  api_key: $GITHUB_TOKEN
  project_owner: Munkun-Estudio
  project_number: 1 # Replace with the actual GitHub Project number before using Symphony.
  status_field_name: Status
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
  transitions:
    on_dispatch: In progress
    on_handoff: In review
polling:
  interval_ms: 30000
workspace:
  root: tmp/symphony_workspaces
  git:
    use_worktrees: false
    repo_root: .
    branch_prefix: symphony/
    # base_branch: main
hooks:
  timeout_ms: 60000
agent:
  max_concurrent_agents: 1
  max_turns: 10
  max_retry_backoff_ms: 300000
codex:
  command: codex app-server
  turn_timeout_ms: 3600000
  read_timeout_ms: 5000
  stall_timeout_ms: 300000
---
# Mission

Execute this tracker issue and hand it off in a review-ready state.

## Issue

- Identifier: {{ issue.identifier }}
- Title: {{ issue.title }}
- URL: {{ issue.url }}
- Attempt: {{ attempt }}

## State Conventions

- Keep active execution states in `tracker.active_states`.
- Keep completed/closed states in `tracker.terminal_states`.
- Keep `In review` out of both lists so execution stops for human handoff.
- Symphony is orchestration, not merge governance. Keep merge policy in repo settings.

## Required Workflow

1. Read project context before coding:
   - `AGENTS.md`
   - `.munkit/MEMORY.md`
   - `.munkit/DECISIONS.md`
   - `.munkit/context.md` (if present)
2. Align with Munkit spec workflow:
   - Use the active spec when relevant.
   - If no relevant spec exists, create one with `munkit spec new <name>`.
   - Update that spec's `notes.md` checklist while you work.
3. Implement the smallest correct change scoped to the issue.
4. Run relevant tests for changed behavior.
5. Record durable context updates when needed:
   - Add architectural choices with `munkit decide`.
   - Add recurring gotchas/patterns/terms with `munkit remember`.
6. Prepare handoff:
   - Summarize changes, tests run, risks, and follow-ups.
   - Move tracker state to `In review` for human validation.

## Safety Constraints

- Keep changes scoped to the issue.
- Do not assume permission to merge, deploy, or auto-close PRs.
- Avoid destructive git commands.
- Preserve unrelated local changes.
- Follow repository conventions from `AGENTS.md`.

## Optional Git Isolation Mode

- Default uses a shared repo checkout (`use_worktrees: false`) for simpler operations.
- To isolate issue workspaces, set `workspace.git.use_worktrees: true`.
- When enabling isolation, keep `repo_root` at the repository root and use `branch_prefix` such as `symphony/`.
- Enable this only after validating your git/worktree strategy locally.

## Retry Behavior

- On retries (`attempt` not empty), continue from the existing workspace state.
- Fix the last failure cause before making additional changes.

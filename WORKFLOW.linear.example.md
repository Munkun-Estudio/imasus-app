---
tracker:
  kind: linear
  endpoint: https://api.linear.app/graphql
  api_key: $LINEAR_API_KEY
  project_slug: your-linear-project-slug
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Canceled
    - Cancelled
polling:
  interval_ms: 30000
workspace:
  root: tmp/symphony_workspaces
  git:
    use_worktrees: false
    repo_root: .
    branch_prefix: symphony/
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

Work this Linear issue to the next human handoff state.

## Issue

- Identifier: {{ issue.identifier }}
- Title: {{ issue.title }}
- URL: {{ issue.url }}
- Attempt: {{ attempt }}

## Notes

- Keep `In review` out of `active_states` and `terminal_states` so execution halts for human review.
- Keep merge and approval policy outside Symphony (repository/branch protection + human review).

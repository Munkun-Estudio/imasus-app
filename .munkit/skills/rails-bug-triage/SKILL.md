---
name: rails-bug-triage
description: >
  Use when investigating a bug, error, or regression in a Ruby on Rails codebase.
  Creates a failing Minitest reproduction test, isolates the broken code path, and
  produces a minimal fix plan. Trigger words: debug, broken, error, regression,
  stack trace, failing test, bug report, Rails app.
---

# Rails Bug Triage

Use this skill when a bug report exists but the right reproduction path and fix sequence are not yet clear.

**Core principle:** Do not guess at fixes. Reproduce the bug, choose the right failing test, then plan the smallest safe repair.

## Process

1. **Capture the report:** restate the expected behaviour, actual behaviour, and reproduction steps.
2. **Bound the scope:** identify whether the issue appears in request handling, domain logic, jobs, or an external dependency.
3. **Gather current evidence:** logs, error messages, edge-case inputs, recent changes, or missing guards.
4. **Choose the first failing test:** pick the boundary where the bug is visible to users or operators.
5. **Define the smallest fix path:** name the likely files and the narrowest behaviour change that should make the test pass.
6. **Hand off:** run the test, confirm it fails for the right reason, implement the fix, then `rails-code-review` before PR.

## Triage Output

Return findings in this shape:

1. **Observed behaviour**
2. **Expected behaviour**
3. **Likely boundary**
4. **First failing test to add**
5. **Smallest safe fix path**
6. **Follow-up skills**

**Example (wrong status code bug):**

```
1. Observed:   GET /materials/unknown-slug returns 500
2. Expected:   Returns 404 with the "not found" template
3. Boundary:   Request layer — visible in HTTP contract
4. First test: test/integration/materials_show_test.rb
5. Fix path:   MaterialsController#show should find_by(slug:) and render 404 when nil,
               instead of find_by!(slug:) which raises.
6. Next:       rails-code-review after the fix lands.
```

**Skeleton failing test:**

```ruby
# test/integration/materials_show_test.rb
require "test_helper"

class MaterialsShowTest < ActionDispatch::IntegrationTest
  test "returns 404 when the slug does not match any material" do
    get material_path(slug: "does-not-exist")
    assert_response :not_found
  end
end
```

Run it before implementing the fix: `bin/rails test test/integration/materials_show_test.rb`

## Boundary Quick Reference

| Bug shape | Likely first test |
|-----------|-------------------|
| HTTP symptoms (status, HTML, redirect) | Integration test in `test/integration/` |
| Data symptoms (wrong value, validation) | Model test in `test/models/` |
| Timing symptoms (missing job, email) | Job test in `test/jobs/` |
| Browser-visible flow (Turbo / Stimulus) | System test in `test/system/` — only when browser interaction is the real risk |

## Pitfalls

| Pitfall | What to do |
|---------|------------|
| Unit test when the bug is visible at request level | Start where the failure is actually observed |
| Bundling reproduction, refactor, and new features | Fix the bug in the smallest safe slice only |
| Flaky evidence treated as green light to patch | Stabilise reproduction before touching code |
| The explanation relies on "probably" or "maybe" | Ambiguity means the reproduction step isn't done yet |

## Integration

| Skill | When to chain |
|-------|---------------|
| `refactor-safely` | When the bug sits inside a risky refactor area and behaviour must be preserved first |
| `rails-code-review` | To review the final bug fix for regressions and missing coverage |
| `rails-architecture-review` | When the bug points to a deeper boundary or orchestration problem |

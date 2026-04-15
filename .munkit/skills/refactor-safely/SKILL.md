---
name: refactor-safely
description: >
  Use when the goal is to change code structure without changing behavior — this
  includes extracting a service object or PORO from a fat controller or model,
  splitting a large class, renaming abstractions, reducing duplication, or
  reorganizing modules. Covers characterization tests (tests that document current
  behavior before touching the code), safe extraction in small steps, and
  verification after every step. Do NOT use for bug fixes or new features —
  those follow the tests-gate workflow. Do NOT mix structural changes with
  behavior changes in the same step.
---

# Refactor Safely

Use this skill when the task is to change structure without changing intended behaviour.

**Core principle:** Small, reversible steps over large rewrites. Separate design improvement from behaviour change.

## Quick Reference

| Step | Action | Verification |
|------|--------|--------------|
| 1 | Define stable behaviour | Written statement of what must not change |
| 2 | Add characterisation tests | Tests pass on current code |
| 3 | Choose smallest safe slice | One boundary at a time |
| 4 | Rename, move, or extract | Tests still pass |
| 5 | Remove compatibility shims | Tests still pass, new path proven |

## HARD-GATE

```
NO REFACTORING WITHOUT CHARACTERISATION TESTS FIRST.
NEVER mix behaviour changes with structural refactors in the same step.
ONE boundary per refactoring step — never extract two abstractions in the same step.
VERIFY tests pass after EVERY step — not just at the end.
If a public interface changes, document the compatibility shim and its removal condition.
```

## Core Rules

- When behaviour changes are also needed, complete the structural refactor first, then apply behaviour changes in a separate step with its own test.
- Keep public interfaces stable until callers are migrated.
- Extract boundaries one at a time; split any step that would touch two abstractions.
- Prefer adapters, facades, or wrappers for transitional states.
- Stop and simplify if the refactor introduces more indirection than clarity.

## Good First Moves

- Rename unclear methods or objects.
- Isolate duplicated logic behind a shared object.
- Extract query or service objects from repeated workflows.
- Wrap external integrations before moving call sites.
- Add narrow seams before deleting old code paths.

## Verification Protocol

**EXTREMELY-IMPORTANT:** run verification after every refactoring step.

```
AFTER each step:
1. Run the full test suite: bin/rails test
2. Read the output — check exit code, count failures
3. If tests fail: STOP, undo the step, investigate
4. If tests pass: proceed to next step
5. ONLY claim completion with evidence from the last test run —
   report the last line of output (e.g. "42 runs, 98 assertions, 0 failures, 0 errors, 0 skips")

Report test run output at EACH step — not only at the end. At least two
separate evidence entries at different sequence points are required.
```

**Forbidden claims:**
- "Should work now" (run the tests)
- "Looks correct" (run the tests)
- "I'm confident" (confidence is not evidence)

## Characterisation Test Template

**Write this before touching any production file.** This is not optional — no refactoring step begins until this test exists and passes on the current (un-refactored) code.

```ruby
# test/integration/materials_index_test.rb
require "test_helper"

class MaterialsIndexTest < ActionDispatch::IntegrationTest
  test "index renders the catalogue with the expected filter pills" do
    get materials_path
    assert_response :success
    assert_select "[data-controller='materials-filter']"
    assert_select ".filter-pill", minimum: 1
  end
end
```

Run it: `bin/rails test test/integration/materials_index_test.rb` — it must pass on the **current** code before any refactoring begins. If it fails, stop and fix the test or the existing code first.

## Minimal Inline Example

The default tiny slice when extracting controller orchestration:

**Before (controller does orchestration):**

```ruby
def create
  entry = LogEntryBuilder.new(params).call
  TagLogEntryJob.perform_later(entry.id)
  redirect_to log_entry_path(entry)
end
```

**After (same behaviour, extraction only):**

```ruby
def create
  entry = LogEntries::CreateEntry.call(params: params)
  redirect_to log_entry_path(entry)
end
```

## Output Style

When asked to refactor:

1. State the stable behaviour that must not change.
2. Propose the smallest safe sequence — each step extracts exactly ONE boundary (one class, one module, or one extracted delegation). A step that moves two abstractions is too large; split it.
3. Show the characterisation test code in your output — do not touch any production file until the test exists and passes.
4. **Compatibility shims (required when public interface changes):** for each shim, state: (a) what the shim is, (b) why it exists, (c) the specific condition under which it will be removed (e.g., "remove after all callers migrate to `LogEntries::CreateEntry.call`"). If no public interface changes, state "No compatibility shims needed — public interface unchanged."
5. Follow Verification Protocol after each step — report evidence mid-sequence AND at the end.

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-architecture-review` | When refactor reveals structural problems |
| `rails-code-review` | For reviewing the refactored code |

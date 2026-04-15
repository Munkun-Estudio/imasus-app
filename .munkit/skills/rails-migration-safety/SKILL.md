---
name: rails-migration-safety
description: >
  Use when planning or reviewing database migrations, adding columns, indexes,
  constraints, backfills, renames, table rewrites, or concurrent operations. Covers
  phased rollouts, lock behavior, rollback strategy, and deployment ordering for
  schema changes on PostgreSQL.
---

# Rails Migration Safety

Use this skill when schema changes must be safe in real environments.

**Core principle:** Prefer phased rollouts over one-shot migrations on large or busy tables. Build the habit while the project is small; by the time tables *are* large, the discipline is already there.

## Quick Reference

| Operation | Safe Pattern |
|-----------|--------------|
| Add column | Nullable first, backfill later, enforce `NOT NULL` last |
| Add index (large table) | `algorithm: :concurrent` (PostgreSQL) |
| Backfill data | Batch job, not inside the migration transaction |
| Rename column | Add new, copy data, migrate callers, drop old |
| Add `NOT NULL` | After backfill confirms all rows have values |
| Add foreign key | After cleaning orphaned records |
| Remove column | Remove code references first, then drop column |

## HARD-GATE

```
DO NOT combine schema change and data backfill in one migration.
DO NOT add NOT NULL on a column that hasn't been fully backfilled.
DO NOT drop columns before all code references are removed.
```

## Review Order

1. Identify the table and its current and projected size.
2. Separate schema changes from data backfills.
3. Check lock behaviour for indexes, constraints, defaults, and rewrites.
4. Plan deployment order between app code and migration code.
5. Plan rollback or forward-fix strategy.

## Safe Patterns

- Add nullable column first, backfill later, enforce `NOT NULL` last.
- Add indexes concurrently when supported.
- Backfill in batches outside a long transaction when volume is high.
- Deploy code that tolerates both old and new schemas during transitions.
- Use multi-step rollouts for renames, type changes, and unique constraints.

## Examples

**Risky (avoid):**

```ruby
add_column :materials, :status, :string, default: "draft", null: false
Material.update_all("status = 'draft'")
```

- **Risk:** Long lock; table rewrite if default is applied on a large table.

**Safe pattern:**

```ruby
# Step 1: add nullable column
add_column :materials, :status, :string

# Step 2 (separate deploy): backfill in batches outside the migration

# Step 3 (after backfill): add constraint and default
change_column_null :materials, :status, false
change_column_default :materials, :status, from: nil, to: "draft"
```

**Index on large tables (PostgreSQL):**

```ruby
disable_ddl_transaction!
add_index :materials, :category, algorithm: :concurrent
```

## Common Mistakes

| Mistake | Reality |
|---------|---------|
| "Table is small, no need for phased migration" | Tables grow. Build the habit for all migrations. |
| Schema change + backfill in one migration | Long transaction, long lock. Always separate them. |
| Column rename with immediate app cutover | App will crash during deploy. Use add-copy-migrate-drop. |
| `add_index` without `algorithm: :concurrent` | Exclusive lock on large PostgreSQL tables blocks writes. |
| Adding `NOT NULL` before backfill completes | Migration fails or locks table waiting for backfill. |
| Removing column before removing code references | App crashes when accessing the missing column. |

## Red Flags

- Schema change and data backfill combined in one long migration
- Column rename with app code assuming immediate cutover
- Large-table default, rewrite, or `NOT NULL` change without a phased plan
- Foreign key or unique constraint added before cleaning existing data
- Destructive remove or drop in the same deploy as the replacement path
- No rollback or forward-fix strategy documented

## Output Style

List risks first.

For each risk include:
- Migration step
- Likely failure mode or lock risk
- Safer rollout
- Rollback or forward-fix note

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-code-review` | When reviewing PRs that include migrations |
| `rails-security-review` | When migrations expose or move sensitive data |

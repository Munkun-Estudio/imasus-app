---
name: rails-stack-conventions
description: >
  Use when writing new Rails code for a project using the PostgreSQL + Hotwire +
  Tailwind CSS stack. Covers stack-specific patterns only: MVC structure,
  ActiveRecord query conventions, Turbo Frames/Streams wiring, Stimulus
  controllers, and Tailwind component patterns. Not for general Rails design
  principles — this skill is scoped to what changes based on this specific
  technology stack.
---

# Rails Stack Conventions

When **writing or generating** code for this project, follow these conventions. Stack: Rails 8 on Ruby 3.4, PostgreSQL, Hotwire (Turbo + Stimulus via Importmap), Tailwind CSS, Solid Queue / Solid Cache / Solid Cable.

**Style:** RuboCop (`.rubocop.yml`) is the source of truth for formatting. For cross-cutting design principles (DRY, YAGNI, structured logging, rules by directory), use `rails-code-conventions`.

## HARD-GATE: Tests Gate Implementation

```
ALL new code MUST have its test written and validated BEFORE implementation.
  1. Write the test: bin/rails test test/<path>/<thing>_test.rb
  2. Verify it FAILS — output must show the feature does not exist yet
  3. ONLY THEN write the implementation code
```

## Quick Reference

| Aspect | Convention |
|--------|-----------|
| Style | RuboCop config in `.rubocop.yml` |
| Models | MVC — POROs or service objects for complex logic, concerns for genuinely shared behaviour |
| Queries | Eager load with `includes`; never iterate over associations without preloading |
| Frontend | Hotwire (Turbo + Stimulus) on Importmap; Tailwind CSS |
| Testing | Minitest with fixtures; tests gate applies |
| Security | Strong params, guard XSS/CSRF/SQLi; use the project's chosen auth approach — do not invent custom auth |
| I18n | All user-facing strings through `t(...)`; four locales planned (en/es/it/gr) |

## Key Code Patterns

### Hotwire: Turbo Frames

```erb
<%# Wrap a section to be replaced without a full page reload %>
<turbo-frame id="material-<%= @material.id %>">
  <%= render "materials/details", material: @material %>
</turbo-frame>

<%# Link that targets only this frame %>
<%= link_to t(".edit"), edit_material_path(@material), data: { turbo_frame: "material-#{@material.id}" } %>
```

### Hotwire: Turbo Streams (from controller)

```ruby
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: turbo_stream.replace(
      "material_#{@material.id}",
      partial: "materials/material",
      locals: { material: @material }
    )
  end
  format.html { redirect_to @material }
end
```

### Stimulus

- One controller per UI concern. File name matches the controller identifier: `app/javascript/controllers/glossary_popover_controller.js` → `data-controller="glossary-popover"`.
- Use `data-*-target` and `data-*-value` attributes instead of reaching into the DOM by class.
- Prefer small, composable controllers over one mega-controller per page.

### Tailwind

- Utility classes in the view. Extract to a partial when the same cluster of classes appears 3+ times.
- For tokens that belong to the IMASUS brand palette (Dark Green `#1F3D3F`, Navy `#252645`, Red `#FA3449`, Mint `#AFE0C7`, Light Blue `#AFCEDE`), define them once in `tailwind.config.*` and reference by name — do not hard-code hex in templates.

### Avoiding N+1 — Eager Loading

```ruby
# BAD — triggers one query per material
@materials = Material.where(category: "textile")
@materials.each { |m| m.tags.pluck(:name) }

# GOOD — single JOIN via includes
@materials = Material.includes(:tags).where(category: "textile")
```

## Security

- **Strong params** on every controller action that writes data.
- Guard against XSS (escape by default, avoid `raw` / `html_safe` on user content), CSRF (Rails default on), SQLi (use AR query methods or `sanitize_sql` for raw SQL).
- Auth: use the project's chosen approach (Epic 8 deliberately leaves the library undecided — likely `has_secure_password` or a lightweight solution, not Devise unless needed).

## Common Mistakes

| Mistake | Correct approach |
|---------|------------------|
| Business logic in views | Use helpers, presenters, or Stimulus controllers |
| N+1 queries in loops | Eager load with `includes` before the loop |
| Raw SQL without parameterisation | Use AR query methods or `ActiveRecord::Base.sanitize_sql` |
| Hard-coded user-facing strings | Use I18n — this project ships in en/es/it/gr |
| Hard-coded brand palette hex in templates | Define palette tokens in `tailwind.config.*` and reference by name |

## Red Flags

- Controller action with more than ~15 lines of business logic
- Model with no validations on required fields
- View with embedded Ruby conditionals spanning 10+ lines
- No `includes` on associations used in loops
- User-facing string hard-coded in a template

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-code-conventions` | Design principles, structured logging, path-specific rules |
| `rails-code-review` | When reviewing existing code against these conventions |
| `rails-architecture-review` | For structural review beyond conventions |

---
name: yard-documentation
description: >
  Use when writing or reviewing inline documentation for Ruby code. Covers YARD tags
  for classes and public methods (param, option, return, raise, example tags).
  Trigger words: YARD, inline docs, method documentation, API docs, public interface, rdoc.
---

# YARD Documentation

Use this skill when documenting Ruby classes and public methods with YARD.

**Core principle:** Every public class and public method has YARD documentation so the contract is clear and tooling can generate API docs.

## HARD-GATE: After implementation

```
YARD is not optional polish. After any feature or fix that adds or changes
public Ruby API (classes, modules, public methods):

1. Add or update YARD on those surfaces before the work is considered done.
2. Do not skip YARD because "the PR is small" or "I'll do it later."
3. All YARD text (descriptions, examples, tags) must be in English unless
   the user explicitly requests another language.

If you only wrote tests + code, stop and document before PR.
```

## Quick Reference

| Scope | Rule |
|-------|------|
| Classes | One-line summary; optional `@since` if version matters |
| Public methods | `@param`, `@option` for hash params, `@return`, `@raise` when applicable; `@example` **required** on public entry points — show realistic usage AND the expected return value |
| Public `initialize` | Add `@param` for constructor inputs when initialisation is part of the public contract |
| Exceptions | One `@raise` tag per exception class — list each separately |
| Private methods | Document only if behaviour is non-obvious; same tag rules |

## Standard Tags

### Class-level

```ruby
# Reads training module content from disk and exposes sections per locale.
# @since 0.1.0
module TrainingModules
  class Loader
```

### Method-level: params and return

```ruby
# Loads a training module section.
# @param slug [String] Module slug (e.g. "zero-waste-design")
# @param section [String] Section key ("training-module", "case-study", "toolkit")
# @param locale [Symbol] One of :en, :es, :it, :gr
# @return [TrainingModules::Section, nil] The section, or nil when the locale is missing
def self.load(slug:, section:, locale:)
```

### Method-level: exceptions (list each raise)

Document `@raise` for every exception a method can raise — **even if the method rescues it internally**:

```ruby
# Imports materials from the seed CSV.
# @param path [String, Pathname] CSV path
# @raise [Errno::ENOENT] when the CSV is missing
# @raise [CSV::MalformedCSVError] when a row cannot be parsed
# @return [Integer] count of imported rows
def self.call(path:)
```

### Examples on public entry points

Prefer at least one `@example` on the main public entry point of the object.

```ruby
# @example Basic usage
#   section = TrainingModules::Loader.load(slug: "zero-waste-design", section: "toolkit", locale: :en)
#   section.nil? # => false
```

## Good vs Bad

**Good:**

```ruby
# Returns the first validation error for a seed row, or nil if valid.
# @param row [CSV::Row] Row from materials-db.csv
# @return [nil, String] nil when valid; error message otherwise
def self.validate_row(row)
```

**Bad:**

```ruby
# Validates stuff.  (Too vague; no @param/@return)
def self.validate_row(row)
```

**Bad (wrong language):**

```ruby
# Valida la fila del CSV.  (Must be in English)
def self.validate_row(row)
```

## Pitfalls

| Pitfall | What to do |
|---------|------------|
| Documenting only the class, not public methods | Callers need param types and return shape for every public method |
| Skipping `@option` for hash params | Without it, consumers don't know valid keys or types |
| Only one `@raise` for multiple exceptions | List EVERY exception type — one `@raise` per class, even if rescued internally |
| YARD text in a language other than English | Write in English unless the user explicitly requests otherwise |

## Verification

Run validation before considering documentation complete:

1. `bundle exec yard stats --list-undoc`
2. `bundle exec yard doc`
3. If output shows undocumented public surfaces you changed, update YARD and re-run.

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-code-review` | When reviewing that public interfaces are documented |

# Prompt and glossary catalogues

Each installation owns its Prompt and Glossary taxonomy and copy. The active
profile points to both YAML manifests:

```yaml
content:
  root: content
  prompts: content/prompts.yml
  glossary: content/glossary.yml
```

Paths are repository-relative, must stay inside `content.root`, and must exist.
The application validates the manifests at boot or when their records are
synchronized by `bin/rails db:seed`.

## Manifest shape

Both catalogues use this strict, non-executable structure:

```yaml
version: 1
resource: prompts # or glossary
categories:
  - id: reflection
    labels:
      en: Reflection
      es: Reflexión
entries:
  - id: first-question
    category: reflection
    tags:
      - workshop
    published: true
    asset: /catalogue/example.svg # or null
    translations:
      en:
        question: What would meaningful progress look like?
        description: Use this prompt to frame a conversation.
      es:
        question: ¿Cómo sería un avance significativo?
        description: Usa esta pregunta para encuadrar una conversación.
```

Ordering is the order of `categories` and `entries` in the file. `tags` is an
optional list of stable, lowercase identifiers available for
installation-specific classification. Category labels are required for every
locale enabled by the profile. Each entry must contain
the profile's fallback locale; other translations use the configured fallback
chain when they are absent.

Prompt translations contain `question` and `description`. Glossary translations
contain `term`, `definition`, and an optional `examples` list:

```yaml
translations:
  en:
    term: Reflection
    definition: A deliberate pause to interpret an experience.
    examples:
      - Reflect on one workshop decision.
```

Unknown fields, locales, category references, duplicate IDs, malformed YAML,
and missing required copy stop synchronization with a location-specific error.
An `asset`, when present, is an application-relative URL to an existing file
under `public/`; remote URLs and parent-directory traversal are rejected.

## Stable IDs

Category and entry IDs use letters, numbers, and hyphens. Entry IDs are public,
durable references used by URLs, projects, logs, and bookmarks. They must not be
translated or derived from display copy. Changing a label, question, or term
therefore does not change its URL. Treat changing an entry ID as a data migration,
not as an editorial edit.

The historical IMASUS Prompt route remains `/challenges/:id/preview`, and its
existing C1–C10 IDs remain valid. New installations may use descriptive IDs such
as `first-question`; reusable code does not assume the IMASUS numbering or
categories.

## Synchronization and editorial changes

Run `bin/rails db:seed` after changing either manifest. Synchronization creates
new records, updates taxonomy/order/publication/assets, and adds missing
translations. By default it preserves copy subsequently edited by a curator in
the application. Use `SEED_OVERWRITE_CONTENT=1 bin/rails db:seed` only when
manifest copy should intentionally replace those edits.

`published: false` removes an entry from public listings and filters while
keeping its direct historical URL available. If an entry previously managed by
a manifest disappears from the file, synchronization also marks it unpublished
rather than deleting it. Existing project, log, and bookmark references remain
resolvable. Reusing a retired ID for unrelated content is unsafe.

Glossary links embedded in Guide or other rendered text are created only for
published terms while the Glossary module is enabled. When it is disabled, or a
term is absent, the original text remains readable.

## Starting a new installation

Copy `content/example-prompts.yml` and `content/example-glossary.yml`, update the
profile paths, then replace the example categories, IDs, and translations. Keep
the files even when their modules are disabled: disabling a module controls its
routes and integration, while the manifests keep the installation contract
complete and allow the module to be enabled later.

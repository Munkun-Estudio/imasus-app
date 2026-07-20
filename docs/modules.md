# Resource modules

The application supports four installation-selectable resource modules. Their
stable internal keys are independent from the current IMASUS names:

| Key | IMASUS surface | Route helper | Content source | Bookmark type |
| --- | --- | --- | --- | --- |
| `library` | Materials | `materials_path` (`library_path` for generic presentation) | Manifest + database records | `LibraryItem` (`Material` compatible) |
| `guides` | Training | `training_index_path` | `content.guides` files | `TrainingModule` |
| `prompts` | Challenges | `challenges_path` | Database records | `Challenge` |
| `glossary` | Glossary | `glossary_terms_path` | Database records | `GlossaryTerm` |

The selected installation profile controls whether each module is enabled and
provides its display label in every configured locale:

```yaml
modules:
  library: false
  guides: true
  prompts: false
  glossary: false
  labels:
    library:
      en: Library
    guides:
      en: Guides
    prompts:
      en: Prompts
    glossary:
      en: Glossary
```

`ResourceModuleRegistry` combines those settings with stable route, controller,
content-source, navigation, colour, dependency, and bookmark metadata. Shared
navigation, home resource cards, bookmark grouping, and cross-module links read
the registry rather than maintaining their own module lists.

## Disabled-module behaviour

Supported routes and legacy helpers remain defined so shared code and IMASUS
URLs stay compatible. A disabled resource controller returns HTTP 404 before
loading its content. Its navigation, home cards, bookmark groups, bookmark
creation, glossary highlighting, and optional project prompt fields are hidden.
Core Workshops, Projects, memberships, process logs, and publication remain
available.

Existing database records and bookmarks are not deleted when a module is
disabled. Re-enabling the module makes them available again.

## Minimal profile

[`config/profiles/minimal.yml`](../config/profiles/minimal.yml) is the executable
reduced-module example. It enables only `guides`, supports only English, disables
analytics, and keeps the core workshop workflow. Validate or run it with:

```bash
APP_PROFILE=minimal bin/site-config
APP_PROFILE=minimal bin/dev
```

The automated minimal-profile smoke test boots a separate Rails process, checks
the enabled card and route, verifies 404 responses for the other three modules,
confirms core Workshops still respond, and rejects bookmark creation for a
disabled module.

## Adding another supported module

The registry is intentionally not a runtime plugin loader. Supporting a new
module implementation still requires a reviewed registry definition and
controller. Once supported, an installation can enable it, label it, and provide
its content without adding conditionals to navigation, home pages, or bookmarks.

# Adopt the application

This walkthrough starts with the deliberately neutral `minimal` profile and
ends with a checked-in installation profile of your own. The process changes
configuration and content, not shared Rails application code.

## Prerequisites

- Ruby 3.4.7
- PostgreSQL
- ImageMagick
- Git

## Run the neutral example

Clone the repository, install dependencies, validate the example, and prepare
its database:

```bash
git clone <repository-url> workshop-app
cd workshop-app
bundle install
APP_PROFILE=minimal bin/site-config
APP_PROFILE=minimal bin/setup --skip-server
APP_PROFILE=minimal bin/rails db:seed
APP_PROFILE=minimal bin/dev
```

The example uses the name Workshop Commons, supports English, enables Guides
only, has no analytics or brand assets, and starts without workshops. In
development the seed creates `admin@example.test` with password
`changeme-dev`; change these credentials before sharing the installation.

## Create an installation profile

Use a lowercase profile name containing letters, numbers, underscores, or
hyphens. Copy the neutral profile and its example content:

```bash
cp config/profiles/minimal.yml config/profiles/my_organisation.yml
cp content/example-workshops.yml content/my-workshops.yml
cp content/example-library.yml content/my-library.yml
cp content/example-prompts.yml content/my-prompts.yml
cp content/example-glossary.yml content/my-glossary.yml
cp -R content/example-guides content/my-guides
```

In `config/profiles/my_organisation.yml`:

1. Replace the public identity, organisation, URLs, email defaults, and theme.
2. Select the supported locales and provide every required locale and module
   label.
3. Enable only the modules the installation should expose.
4. Point every `content` entry at the copied files.
5. Add brand files under `app/assets/images` or `public` and reference them, or
   keep optional asset values `null` for accessible text fallbacks.
6. Enable analytics only after setting its public script URL and completing the
   installation's privacy review.

All content paths remain required even when their modules are disabled. Keeping
valid empty or example manifests makes future module activation predictable.

## Add content

- Workshops: edit `content/my-workshops.yml`, or leave `workshops: []` and
  create workshops after signing in as an administrator or facilitator.
- Guides: follow [Guide content](guides.md) and its localized Markdown folder
  convention.
- Library: follow [Library content](library.md), preview with
  `bin/rails library:sync`, then apply with `APPLY=1`.
- Prompts and Glossary: follow [Prompt and glossary catalogues](catalogs.md) and
  synchronize them with `bin/rails db:seed`.

Stable IDs are stored in URLs, bookmarks, and project references. Do not derive
them from translated titles or silently reuse retired IDs.

## Validate and seed the installation

Run every command with the selected profile:

```bash
APP_PROFILE=my_organisation bin/site-config
APP_PROFILE=my_organisation bin/rails db:prepare
APP_PROFILE=my_organisation bin/rails db:seed
APP_PROFILE=my_organisation bin/rails test
APP_PROFILE=my_organisation bin/rails assets:precompile
```

Set initial administrator credentials through the environment rather than the
profile:

```bash
ADMIN_EMAIL=admin@example.org \
ADMIN_NAME="Example administrator" \
ADMIN_PASSWORD="replace-with-a-secret" \
APP_PROFILE=my_organisation \
bin/rails db:seed
```

The older `IMASUS_ADMIN_EMAIL`, `IMASUS_ADMIN_NAME`, and
`IMASUS_ADMIN_PASSWORD` variables remain accepted for the existing IMASUS
deployment, but new installations should use the generic names.

## Before a public deployment

The example values are development fixtures, not production defaults. At a
minimum, review and replace:

- public URLs, sender identity, support contact, and administrator credentials;
- privacy policy and terms under `config/locales/legal.en.yml`;
- content, media, logo, trademark, and partner licences and attribution;
- database, storage, mail, analytics, host, CORS, backup, and rollback settings
  described in [Deployment](deployment.md).

The upstream deployment example uses Scaleway services in one European region.
Other providers remain possible when they satisfy the same OCI, PostgreSQL,
S3-compatible storage, secrets, migrations, health-check, backup, and rollback
boundaries.

The repository's MIT licence covers original software, not installation
content, uploaded or bundled media, names, logos, or trademarks unless those
works state a separate licence.

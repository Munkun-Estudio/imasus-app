# Deployment

Production runs on Fly.io in Paris (`cdg`) with PostgreSQL and Tigris object
storage. Tigris is S3-compatible, so Rails uses the standard Active Storage
`amazon` service without committing any secret values.

## Public repository rule

Keep this repository public-safe:

- Commit configuration files such as `fly.toml` and GitHub Actions workflows.
- Commit secret names, never secret values.
- Store runtime secrets in Fly.io secrets and GitHub Actions secrets.
- Do not commit `config/master.key`, `.env*`, database dumps, production logs, or
  user uploads.

## Tigris Object Storage

Create a private Tigris bucket for production uploads:

```sh
flyctl storage create --app imasus-app --name imasus-app-production
```

Do not pass `--public`; uploads should stay private and be served by Rails
through Active Storage URLs. The command provisions the bucket and sets the
Fly secrets that Active Storage needs: `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ENDPOINT_URL_S3`, and `BUCKET_NAME`.
The app also accepts `AWS_S3_BUCKET` for compatibility with AWS S3.

## Fly.io

Create the app and attach PostgreSQL:

```sh
flyctl apps create imasus-app --org personal
flyctl postgres create --name imasus-app-db --region cdg
flyctl postgres attach --app imasus-app imasus-app-db
flyctl storage create --app imasus-app --name imasus-app-production
```

Set production secrets:

```sh
flyctl secrets set --app imasus-app RAILS_MASTER_KEY=...
```

If `config/master.key` is unavailable, set `SECRET_KEY_BASE` as a temporary
runtime secret instead and recover the real Rails master key before relying on
encrypted credentials.

After Solid Queue tables are configured, remove the temporary
`ACTIVE_JOB_QUEUE_ADAPTER = "async"` setting and run a deploy with
`SOLID_QUEUE_IN_PUMA = "true"` or a separate worker process.

Deploy manually:

```sh
flyctl deploy --remote-only
```

Verify the release:

```sh
flyctl status --app imasus-app
flyctl releases --app imasus-app
flyctl logs --app imasus-app
```

The app should answer at:

```text
https://imasus-app.fly.dev
https://imasus-app.fly.dev/up
```

## GitHub Actions CD

Generate a deploy token and save the full token value as the GitHub repository
secret `FLY_API_TOKEN`:

```sh
flyctl tokens create deploy --app imasus-app
```

Pushes to `main` run the existing CI workflow and then deploy through
`.github/workflows/fly.yml`.

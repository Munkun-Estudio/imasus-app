# Deployment

The application is provider-portable: it ships as an OCI container, uses
PostgreSQL, stores uploads through an S3-compatible API, and reads configuration
from an installation profile plus runtime environment variables.

The reference deployment uses Scaleway services in one European region. This
keeps the example aligned with data-location and European cloud-sovereignty
goals without claiming that provider selection alone establishes legal
compliance. Each operator remains responsible for its region, contracts,
subprocessors, retention, access controls, and privacy documentation.

Scaleway currently offers regions in Paris, Amsterdam, and Warsaw. Confirm
product availability in the chosen region before provisioning:
[Scaleway product availability](https://www.scaleway.com/en/docs/account/reference-content/products-availability/).

## Reference architecture

Use the same region for all stateful services:

| Responsibility | Scaleway service | Application boundary |
| --- | --- | --- |
| Web application | Serverless Containers | OCI image; public HTTPS endpoint; `/up` health check |
| Release migrations | Serverless Jobs | Same immutable image, command `bin/rails db:prepare` |
| Image registry | Container Registry | Private, versioned images built for `linux/amd64` |
| Relational data | Managed Database for PostgreSQL | `DATABASE_URL`; automatic and pre-release backups |
| Uploads | Object Storage | S3-compatible `amazon` Active Storage service |
| Private connectivity | VPC Private Network | Container-to-database traffic within one region |
| Transactional mail | Transactional Email | SMTP invitations and password resets |

Serverless Containers have ephemeral local storage. Do not use the container
filesystem for uploads or durable application state. They support HTTP,
WebSockets, custom domains, secret environment variables, health checks, and
Private Network egress. See the official
[container compatibility notes](https://www.scaleway.com/en/docs/serverless-containers/faq/)
and [Private Network integration](https://www.scaleway.com/en/docs/serverless-containers/reference-content/containers-private-networks/).

## Public repository rule

Commit:

- installation profiles and non-secret deployment examples;
- image names, region identifiers, and secret **names**;
- migration, backup, verification, and rollback procedures.

Never commit API keys, Rails keys, database URLs, SMTP passwords, database
dumps, production logs, or user uploads. Store sensitive values as Scaleway
secret environment variables and limit the IAM application used by CI to the
required project and services.

## Build and publish the image

Scaleway Serverless Containers require `linux/amd64`. Apple silicon developers
must not push the default local `arm64` image.

```sh
export IMAGE="rg.fr-par.scw.cloud/<namespace>/workshop-app:<git-sha>"

docker buildx build \
  --platform linux/amd64 \
  --tag "$IMAGE" \
  --push \
  .
```

Use an immutable commit SHA or release tag for deployments; do not use `latest`
as the only rollback reference. Follow Scaleway's
[Container Registry quickstart](https://www.scaleway.com/en/docs/container-registry/quickstart/)
for namespace creation and Docker authentication.

## PostgreSQL and private networking

Create a Managed PostgreSQL database and a VPC Private Network in the same
region as the container. Attach both resources to that network and use the
database's private endpoint in `DATABASE_URL`. Remove the initial
`0.0.0.0/0` public database ACL after private connectivity is verified.

Managed PostgreSQL supports high availability and automatic backups. Configure
retention explicitly, test restoration, and create a manual backup immediately
before a release containing migrations. See
[database connectivity](https://www.scaleway.com/en/docs/managed-databases-for-postgresql-and-mysql/how-to/connect-database-instance/)
and [backup management](https://www.scaleway.com/en/docs/managed-databases-for-postgresql-and-mysql/how-to/manage-backups/).

## Object Storage

Create a bucket in the selected region and a restricted IAM application for
that bucket. Configure the container and migration/CORS jobs with:

```text
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=<secret>
AWS_SECRET_ACCESS_KEY=<secret>
AWS_REGION=<object-storage-region>
AWS_ENDPOINT_URL_S3=https://s3.<object-storage-region>.scw.cloud
AWS_S3_BUCKET=<bucket-name>
AWS_PUBLIC_BUCKET=false
ACTIVE_STORAGE_CORS_ORIGINS=https://workshops.example.org
```

`AWS_PUBLIC_BUCKET=false` keeps new installations on signed Active Storage
URLs. The default remains public temporarily for compatibility with the
existing IMASUS/Tigris deployment; that downstream must set its intended value
explicitly before the compatibility default is removed.

Apply the browser direct-upload CORS policy using the same image and secrets as
a one-off Serverless Job:

```sh
bin/rails active_storage:configure_cors
```

The task restricts origins to `ACTIVE_STORAGE_CORS_ORIGINS`. Do not use `*` for
an authenticated production application. Scaleway documents its S3-compatible
[bucket CORS configuration](https://www.scaleway.com/en/docs/object-storage/api-cli/setting-cors-rules/)
and [object lifecycle rules](https://www.scaleway.com/en/docs/object-storage/api-cli/lifecycle-rules-api/).

## Runtime configuration and secrets

Set these non-secret variables on the web container:

```text
APP_PROFILE=my_organisation
APP_HOST=workshops.example.org
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
ACTIVE_STORAGE_SERVICE=amazon
SOLID_QUEUE_IN_PUMA=true
```

Set these as secret variables:

```text
DATABASE_URL
RAILS_MASTER_KEY
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
SMTP_USERNAME
SMTP_PASSWORD
ADMIN_PASSWORD
```

Also configure `MAILER_FROM`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`,
`SMTP_AUTHENTICATION`, and `SMTP_ENABLE_STARTTLS_AUTO`. For Scaleway
Transactional Email, the official SMTP host is `smtp.tem.scaleway.com`, port
587 uses STARTTLS, the username is the Scaleway project ID, and the password is
an API secret with Transactional Email permission. Serverless Containers block
third-party SMTP ports, so choose another compute product if a different SMTP
provider is mandatory. See [Scaleway SMTP configuration](https://www.scaleway.com/en/docs/transactional-email/reference-content/smtp-configuration/).

`APP_HOST` is a bare hostname without `https://`; Rails uses it to create
invitation and password-reset links. Configure the container as public,
HTTPS-only, with container port `3000` and an HTTP health check on `/up`.
Scaleway injects its reserved `PORT` variable, so do not define `PORT` as a
custom environment variable. Add the custom domain only after its CNAME points
to the generated container endpoint; Scaleway then provisions TLS. See
[custom domains](https://www.scaleway.com/en/docs/serverless-containers/how-to/add-a-custom-domain-to-a-container).

## Database queues and minimum capacity

The application uses Solid Queue. Run all database schema preparation before
enabling it, set `SOLID_QUEUE_IN_PUMA=true`, and keep at least one container
instance available when queued mail must continue without incoming web traffic.
If an installation requires independent workers or stronger delivery
guarantees, deploy the same image on always-on compute with a separate Solid
Queue process rather than relying on scale-to-zero behavior.

## Release order

For every production release:

1. Build and push one immutable `linux/amd64` image.
2. Validate the selected profile and precompile assets in CI.
3. Create and identify a restorable PostgreSQL backup.
4. Run a Serverless Job from that image with `bin/rails db:prepare`.
5. Stop if the migration job fails; do not deploy the web revision.
6. Deploy the same image digest to the Serverless Container.
7. Verify `/up`, sign-in, one public resource, direct upload, and transactional
   email.
8. Retain the previous image digest and database backup until the observation
   window closes.

For application-only rollback, redeploy the previous image. If migrations are
not backward-compatible, stop writes, restore the pre-release backup to a new
database, point the previous image at it, verify, and only then switch traffic.
Never run a destructive down migration against the only production database.

## Continuous deployment

A generic upstream must not include a live, credential-bound deployment
workflow. An installation repository should implement this ordered pipeline:

1. run upstream CI for its selected profile;
2. authenticate a narrowly scoped Scaleway IAM application;
3. build and push the immutable image;
4. create/confirm the database backup;
5. run and await the migration job;
6. update the web container to the same image digest;
7. run smoke checks and record the deployed digest.

Scaleway supports console, CLI, Terraform/OpenTofu, and API deployment. Use IaC
for durable infrastructure and the CLI or API for image rollouts. See
[deployment methods](https://www.scaleway.com/en/docs/serverless-containers/reference-content/deploy-container/).

## Transitional IMASUS deployment

`fly.toml` and `.github/workflows/fly.yml` remain temporarily because this
repository still deploys `app.imasus.eu`. They are **not** the generic reference
and must not be copied by adopters. The planned replacement for that public URL
is the static `imasus-app-static` archive on Netlify, not another always-on Rails
deployment.

Before changing DNS, create verified database and object-store backups, complete
the static export and privacy review, and test a Netlify preview on a temporary
hostname. After the DNS change, disable the automatic Fly workflow and stop the
Rails compute/database for a rollback window. Delete each Fly resource only
after that window; retain or migrate Tigris separately because the static
archive currently references its public object URLs.

The private
[`Munkun-Estudio/imasus-workshop-app`](https://github.com/Munkun-Estudio/imasus-workshop-app)
Rails downstream remains deployment-ready but dormant for future workshops. Its
CI tests every change, while provisioning and deployment require an explicit
manual action. Future runtimes should normally use a workshop-specific hostname
so `app.imasus.eu` continues to identify the static archive.

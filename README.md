# PrintLyrics

PrintLyrics finds songs through LRCLIB and turns their lyrics into shareable,
print-optimized lyric sheets. Manual lyric entry is also supported. It is a
Rails 8.1 application built with Hotwire, Tailwind CSS, SQLite, and a small
amount of Stimulus for preview controls.

## Requirements

- Ruby 4.0.5
- SQLite 3

## Setup

```sh
bin/setup
bin/dev
```

The application runs at `http://localhost:3000`.

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/rails assets:precompile
```

## Song Search

Song search uses the public LRCLIB API. Selecting a result fills the editable
form without creating a database record. A record is persisted only after the
user generates the print page.

## Retention

Generated pages expire 180 days after their last visit. Visits renew the
retention window, and creating a new page purges expired records. The same
cleanup can be run explicitly:

```sh
bin/rails lyrics:purge_expired
```

## Deployment

The Dockerfile builds assets without Node.js. Kamal deploys one web container
to the existing Hetzner host, with SQLite stored on a persistent Docker volume.
Deployments require:

```sh
RAILS_MASTER_KEY=...
KAMAL_REGISTRY_PASSWORD=...
```

The `printlyrics-prod` GitHub environment also requires `KAMAL_SSH_KEY`.
CI runs for pull requests and pushes to `main`. Release Please maintains a
release pull request; merging that pull request publishes a release and
dispatches the production deployment.

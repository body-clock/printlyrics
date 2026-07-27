# PrintLyrics

PrintLyrics turns pasted lyrics or a supported song URL into a shareable,
print-optimized lyric sheet. It is a Rails 8.1 application built with Hotwire,
Tailwind CSS, SQLite, and a small amount of Stimulus for preview controls.

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

## Extraction

`LyricExtractor` supports `genius.com` and `azlyrics.com`. Fetching a URL fills
the editable form without creating a database record. A record is persisted
only after the user generates the print page.

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

For the first deployment, point the Cloudflare `A` record for
`printlyrics.app` to `46.225.21.111` as DNS-only so Kamal can obtain the origin
certificate. After deployment, proxy the record through Cloudflare and use
Full (strict) SSL mode.

The production database lives in the `printlyrics_storage` Docker volume.
Back up that volume before server replacement or destructive maintenance.

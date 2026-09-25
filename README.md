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

## Songbooks

A generated page can be extended into a songbook: an ordered, token-addressed set
of lyric sheets that prints as one job. A songbook keeps the generated-page
contract — unlisted link, no account, and excluded from indexing.

## Retention

Generated pages and songbooks expire 180 days after their last visit, and visits
renew the retention window. Visiting a songbook renews it and every song in it.
Nothing purges expired rows on its own: cleanup is the explicit task below, which
the `kamal purge` alias runs against production.

```sh
bin/rails lyrics:purge_expired
```

## User feedback

Visitors can describe what they were printing and what got in the way, from the
prompt under a search that found nothing or from the `/feedback` page.
Submissions are stored in the `feedbacks` table — nothing about them is sent to
analytics — and read with:

```sh
bin/rails feedback:list   # newest first, 50 by default
LIMIT=200 bin/rails feedback:list
```

The form is gated by Cloudflare Turnstile, whose keys come from the deployment
environment. The site key is public because it is in the page source:

```sh
TURNSTILE_SITE_KEY=...      # config/deploy.yml
TURNSTILE_SECRET_KEY=...    # .kamal/secrets
```

Until both are set, the widget is not rendered and submissions are stored with
`verified: false` rather than rejected, so a half-configured host never blocks a
visitor; `feedback:list` marks those rows `UNVERIFIED`.

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
release pull request and updates `version.txt`; merging that pull request
publishes a release and dispatches the production deployment. The application
shows that version in its footer.

## Operations

Use the [organic search operations runbook](docs/organic-search-operations.md)
to configure Search Console, Plausible, and the Google Analytics dual run,
record launch baselines, and run the 30- and 90-day reviews.

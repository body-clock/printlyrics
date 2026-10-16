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

A generated page can be extended into an ordered songbook that prints as one job.
A songbook that no premium account owns holds up to ten songs. Guests can make one
songbook per calendar day, limited by the browser session. Optional email/password
accounts keep up to five stored songbooks, claim guest songbooks from that browser
when they sign in, and provide a cross-device library for reopening account-owned
sets. Premium access lifts both ceilings. Free-owned and guest songbooks retain a
180-day sliding window, so a book that lapses frees the place it held. Owner-only
songbooks require authentication; guest token links remain unlisted and are not an
authentication mechanism.

Paid access is $3/month, $25/year, or $1/24 hours, bought through Stripe Checkout.
It removes the songbook and song ceilings, adds durable reprints, revocable
read-only share links that work only while premium access is active, and printed
sheets that carry no code. Guest songbook links remain separate and retain their
existing behavior. `/save-songbooks` explains the account options and is indexed as
a distinct practical page.

Access is granted by the Stripe webhook, never by returning from the checkout
page: `checkout.session.completed` writes the ledger row that grants it, a day
pass runs 24 hours from that moment, and a subscription runs to the billing period
Stripe reports for it — monthly or yearly. `PremiumGrant` is the append-only
ledger and its unique `(provider, provider_ref)` index is the idempotency key, so
a delivery Stripe retries extends nothing twice. The entitlement itself stays
`users.premium_until`, read by `User#premium?`, and it only ever moves forward:
`User#activate_premium_until!` keeps the later expiry, so a day pass bought
during an active month cannot shorten it and a renewal that arrives early cannot
either. Grant access by hand for an experiment in a Rails console:

```ruby
User.find_by!(email_address: "person@example.test").activate_premium_until!(24.hours.from_now)
```

A sheet printed from an account with active premium access carries no
`SheetMark` code — the paper channel's return path is what the paid tier removes.
The set owner's entitlement decides, so a read-only link to a premium account's
set prints without one too; see the
[measurement contract](docs/measurement-contract.md).

Premium account songbooks and their member lyrics have no expiry. Account pages,
saved lyrics, and songbooks remain excluded from indexing.

### Selling plans

The whole feature is off unless all five values are set, and nothing raises when
they are absent: a host without them renders `/save-songbooks` with today's
proposal wording, no purchase control, and a checkout action that refuses.

```sh
STRIPE_SECRET_KEY=sk_live_...       # credential
STRIPE_WEBHOOK_SECRET=whsec_...     # credential, from the endpoint below
STRIPE_PRICE_MONTHLY=price_...      # public identifier for the $3/month price
STRIPE_PRICE_ANNUAL=price_...       # public identifier for the $25/year price
STRIPE_PRICE_DAY_PASS=price_...     # public identifier for the $1/24-hour price
```

The webhook endpoint to create in Stripe is `https://printlyrics.app/stripe/webhook`,
subscribed to `checkout.session.completed`, `invoice.paid`, and
`customer.subscription.deleted`; its signing secret is `STRIPE_WEBHOOK_SECRET`.
Stripe moves the account between plans through its own Billing Portal, which the
library links to once the account has a customer. Deployments pass the two
credentials through Kamal secrets and the three price identifiers through
`config/deploy.yml`, beside the analytics and Turnstile values.


## Signing in

Accounts use an email address and a password, and optionally Google. No deploy
wiring is needed for it: the client lives in `config/credentials.yml.enc` under
`google`, unlocked by `RAILS_MASTER_KEY`, which the container already receives.

```sh
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
google:
  client_id: <id>.apps.googleusercontent.com
  client_secret: GOCSPX-...
```

The OAuth client's authorized redirect URI must be
`https://printlyrics.app/auth/google_oauth2/callback`, plus
`http://127.0.0.1:3000/auth/google_oauth2/callback` (and the same on
`localhost`) for `bin/dev`: Google compares that string exactly. Leave its
authorized JavaScript origins empty — the whole flow is server-side, so no Google
script runs in the browser.

A sign-in resolves to an `identities` row keyed by Google's own `uid`, so a
returning visitor is found by what Google keeps sending rather than by an address
either side could have changed. The first link uses the address Google verified:
it claims the account that already uses it, which is how a password account adds
Google later, and it creates the account when there is none. An address Google
will not verify is refused. Without both values the sign-in pages render no
Google control, the request phase is refused outright, and the callback links
nothing.

## Retention

Generated guest and free-account pages expire 180 days after their last visit,
and visits renew the retention window. Premium-created songbooks and their
member lyrics have no expiry. Nothing purges expired rows on its own: cleanup is
the explicit task below, which the `kamal purge` alias runs against production.

```sh
bin/rails lyrics:purge_expired
```

## User feedback

Visitors can describe what they were printing and what got in the way, from the
prompt under a search that found nothing, from the line under a sheet they just
generated, or from the `/feedback` page. Submissions are stored in the
`feedbacks` table and read with:

```sh
bin/rails feedback:demand   # the songs asked for, most requested first
bin/rails feedback:list     # newest first, 50 by default
LIMIT=200 bin/rails feedback:list
```

`feedback:demand` is where a review starts: the same title typed twice counts as
one request, and each row carries its surface, whether it came with a note, and
when it was last asked for. Every row also carries the answer the visitor chose
(`reason`, from `Feedback::REASONS`) and how many sheets the visit had already
made (`visit_sheet_count`) — a request with no sheet behind it is a visitor who
left empty-handed. The `kamal feedback` and `kamal feedback-demand` aliases run
those two tasks against the deployed container, which is where production
submissions are read.

A stored submission is also reported to the site's own analytics service as
`Feedback Submitted`, carrying the song query, the note, the surface it came
from, and the answer, so the demand can be read beside the counts around it.
That report is Umami's alone — never Plausible's — and the reply address is not
part of it. The [measurement contract](docs/measurement-contract.md) owns the
rule and the event's properties.

The form is gated by Cloudflare Turnstile. The site key and the accepted
hostnames are public and live in `config/deploy.yml`; the widget secret is a
credential, with the rest of this project's secrets:

```sh
TURNSTILE_SITE_KEY=...      # config/deploy.yml, public
TURNSTILE_HOSTNAMES=...     # config/deploy.yml, public; never localhost in production
bin/rails credentials:edit  # turnstile.secret_key, unlocked by RAILS_MASTER_KEY
```

A submission is stored only when Cloudflare confirms the token for the
`feedback` action on one of `TURNSTILE_HOSTNAMES`. A declined token, a token
minted for another surface or host, an unreachable siteverify, or a host missing
any of these values is refused: an unjudged challenge is not a pass, so the form
stays closed until the deployment is configured.

Cloudflare's test keys cannot satisfy those checks: their reply carries no
`action` and reports `hostname: "example.com"`, so a test-key submission is
refused. To exercise the happy path locally, add `localhost` and `127.0.0.1` to
the widget's domains in the Cloudflare dashboard and run with the real sitekey
and `TURNSTILE_HOSTNAMES=localhost,127.0.0.1`.

## Deployment

The Dockerfile builds assets without Node.js. Kamal deploys one web container
to the existing Hetzner host, with SQLite stored on a persistent Docker volume.
Deployments require:

```sh
RAILS_MASTER_KEY=...
KAMAL_REGISTRY_PASSWORD=...
```

Analytics runs beside that container as two Kamal accessories — Umami and its
PostgreSQL database. A deploy neither starts, stops, nor updates them; booting
them for the first time needs two more secrets:

```sh
UMAMI_DB_PASSWORD=...   # openssl rand -hex 24
UMAMI_APP_SECRET=...    # openssl rand -hex 32
```

An ordinary deploy does not need those two, and the runbook linked under
Operations owns the setup.

Selling the paid plans needs two more secrets, plus the three public price
identifiers in `config/deploy.yml`. They are read at deploy time from Proton
Pass, so a missing item leaves the feature off rather than failing the deploy:

```sh
STRIPE_SECRET_KEY=...       # credential, the Stripe account's secret key
STRIPE_WEBHOOK_SECRET=...   # credential, the endpoint's signing secret
```

Stripe reaches the webhook at `https://printlyrics.app/stripe/webhook`, so the
endpoint is created against the production host and its signing secret is the
one above.

The `printlyrics-prod` GitHub environment also requires `KAMAL_SSH_KEY`.
CI runs for pull requests and pushes to `main`. Release Please maintains a
release pull request and updates `version.txt`; merging that pull request
publishes a release and dispatches the production deployment. The application
shows that version in its footer.

## Operations

Use the [organic search operations runbook](docs/organic-search-operations.md)
to configure Search Console, boot the self-hosted Umami analytics service and its
MCP endpoint, run the two-week parallel measurement beside Plausible, record
launch baselines, and run the 30- and 90-day reviews. The
[measurement contract](docs/measurement-contract.md) holds the event vocabulary,
how a surface reports an event, and what must never reach analytics.

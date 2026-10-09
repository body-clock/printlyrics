# Organic Search Operations

This runbook starts and operates PrintLyrics' organic-search measurement window.
It does not promise a search ranking. The site owner owns every external-console
step and the 30- and 90-day reviews.

Do not start the 90-day window until the launch checklist is complete.

## Launch record

Copy this table into the launch issue and fill every field.

| Evidence | Owner | Expected result | Recorded value |
| --- | --- | --- | --- |
| Production release and smoke-test time | Site owner | Current release is healthy | |
| Search Console Domain property | Site owner | `printlyrics.app` is verified | |
| Sitemap fetch | Site owner | `https://printlyrics.app/sitemap.xml` is `Success` | |
| Plausible goals | Site owner | All ten exact event names exist, automatic goals off in settings and disabled in the snippet | |
| Umami parallel run | Site owner | The Umami site exists, the tracker renders on production, the ten shared events plus every property arrive beside Plausible's, and the three names that are Umami's alone (`Feedback Submitted`, `Songbook Offer Shown`, `Songbook Offer Dismissed`) arrive there | |
| Organic Search segment | Site owner | Plausible's saved site segment can be reopened, and the same split is saved in Umami as one referrer segment per search engine — the channels Umami reports are not filterable, so there is no single organic segment to save | |
| Umami readings saved | Site owner | The four funnels and the saved segments named in "Read the events in Umami" exist and reopen, and the five goals the Events row names are saved | |
| Launch baseline | Site owner | Search and conversion figures are recorded | |
| Measurement start | Site owner | Date is set only after all rows above pass | |

## 1. Verify Google Search Console

Google's [Domain property instructions](https://support.google.com/webmasters/answer/34592)
require DNS verification and cover protocols and subdomains.

1. In Search Console, add a **Domain** property named `printlyrics.app`. Do not
   include `https://` or a path.
2. Copy the TXT value Google supplies into the DNS zone for `printlyrics.app`.
   Do not remove an existing TXT record to make room for it.
3. Wait for DNS propagation, select the property, and choose **Verify**.
4. Leave the verification record in DNS. In **Settings > Ownership
   verification**, confirm that the site owner remains verified.
5. Open `https://printlyrics.app/sitemap.xml` in a signed-out browser. It must
   return XML without a redirect to authentication.
6. In **Sitemaps**, submit `https://printlyrics.app/sitemap.xml`. Search Console
   submits a URL; it does not receive an uploaded file. Record the submission
   time and wait for status `Success`.
7. In **Page indexing**, filter by the submitted sitemap. Record indexed and
   non-indexed counts. Inspect the homepage and both printing guides with URL
   Inspection.

Recovery:

- If verification fails, compare the exact TXT host and value, check it with
  the DNS provider's lookup, wait for its TTL, and retry. Do not create a
  URL-prefix property as a substitute.
- If the sitemap fetch fails, request the URL signed out, confirm a `200`
  response and XML content type, then inspect the row's reported error before
  resubmitting. Google's [Sitemaps report documentation](https://support.google.com/webmasters/answer/7451001)
  explains fetch and parsing errors.
- If a saved `/lyrics/<token>` URL is reported as indexed, confirm it renders a
  `noindex` directive, remove any route to it from the sitemap, and request
  recrawling. Never submit saved lyric URLs.

## 2. Configure the analytics destinations

Plausible is the destination of record until the cutover. Umami, this site's own
analytics service, runs beside it first, and the Google Analytics dual run is
over: the tag, the initializer, and its CSP origins are gone from the code.

### Plausible

In the Plausible site for `printlyrics.app`, open **Settings > Goals** and add a
custom-event goal for each exact, case-sensitive name:

1. `Song Search Submitted`
2. `Song Search Missed`
3. `Song Result Selected`
4. `Manual Entry Submitted`
5. `Print Page Generated`
6. `Print Dialog Opened`
7. `Second Print Page Generated`
8. `Songbook Created`
9. `Songbook Created From Offer`
10. `Songbook Printed`

A goal has to exist before the release that emits its event, because Plausible
does not backfill what arrived earlier: its counter starts at the first event
that follows the goal's creation.

Keep this list short deliberately. Each goal answers one question, and every
addition costs dashboard legibility and has to earn its place:

| Goal | Question it answers |
| --- | --- |
| `Song Search Submitted` | Did a visit look for a song by name? |
| `Song Search Missed` | Did that search find nothing? |
| `Song Result Selected` | Did the visit choose a match the search found? |
| `Manual Entry Submitted` | Did a visit paste its own lyrics instead? |
| `Print Page Generated` | Did the tool produce a sheet? |
| `Print Dialog Opened` | Did a sheet reach the printer? |
| `Second Print Page Generated` | Is a visit assembling more than one sheet? |
| `Songbook Created` | Did a set of sheets come into being? |
| `Songbook Created From Offer` | Did the suggestion produce that set? |
| `Songbook Printed` | Did a set reach the printer as one job? |

[The measurement contract](measurement-contract.md) holds the rule behind this
list: the naming, the slots every tool fills, and what must never travel.

### Why these are goals and not properties

This site's Plausible plan does not include custom properties, so an event's
name is the only dimension the dashboard can read. Every split that would
otherwise be a property is its own goal instead.

The application still sends `entry_method`, `songbook_size`, `songbook_origin`,
`campaign_source`, `campaign_name`, `page_count_in_session`, and
`songbook_offer_surface` with events.
**Plausible cannot read any of them on this plan, and no reading below depends on
them here.** Umami records all seven as event properties, which is why it runs
beside Plausible for the two weeks in "Umami beside Plausible" below: it is the
first destination this site has had that can report them next to the counts.

Four of the goals are subsets of another, which is how a total and a split are
read without properties:

- `Song Search Missed` is the subset of `Song Search Submitted` whose query
  found nothing. It counts the searches that failed to serve the visitor; what
  they were looking for sits in the feedback table, and submitting the miss
  prompt also reports it as `Feedback Submitted` in Umami alone.
- `Second Print Page Generated` is the subset of `Print Page Generated` at the
  second distinct sheet of a visit — the visit's own generation, not every route
  to a two-song packet. A set finished by adding a song to a draft an earlier
  visit started is `Songbook Created` with `songbook_origin` of `add_song` and
  no `Second Print Page Generated`, so the two names are independent rather
  than nested.
- `Songbook Printed` is the subset of `Print Dialog Opened` where the printed
  surface was a set. `Print Dialog Opened` still counts every print, so its
  series and its 90-day target stay continuous.
- `Songbook Created From Offer` is the subset of `Songbook Created` where the
  suggestion started the set. The offer's conversion rate is one over the other.

`Song Search Missed` and `Song Result Selected` split `Song Search Submitted`,
which is neither's subset: the first is the searches that found nothing, the
second the searches that found something the visitor chose. Searches that found
something and were abandoned are the remainder, and they are only visible as the
gap between the three.

A songbook counts as a set from its second song. `Songbook Created` is pinned to
that threshold rather than to the row being inserted, because the row is created
by a click: a one-song songbook is a draft, and a visitor who starts one and
leaves is not counted as having made a set.

Do not constrain these goals with song titles, artist names, source IDs, lyric
tokens, or URLs, and never send lyrics, titles, or real share tokens in an event
payload.

Turn off Plausible's automatic goals — **Form submissions**, **File downloads**,
**Outbound links**, and **404** — under **Settings > General > Default
tracking**. `Form: Submission` pools every form on the site into one number (the
search form, each result button, and the generate form all post), so it does not
describe any single product step, and it counts toward billable pageviews.
PrintLyrics sends none of these events from application code.

The dashboard setting is not the switch that holds. Plausible's automatic
capture sends the live `location.href` with the event, which bypasses the
redaction in `app/javascript/lib/analytics.js`, so any automatic event on a saved
page carries a real share token. The 2026-09-22 to 2026-09-28 export proved it:
the site's Default tracking settings still had form submissions, file downloads,
and outbound links enabled — the served
`https://plausible.io/js/pa-f0moCFg03qwW-u-pSexGt.js` carries all three as
`true` — and the export listed 36 real `/lyrics/<token>` and
`/songbooks/<token>` paths (22 sheets and 14 sets) with zero pageviews each, the
signature of a non-pageview event, carrying 75 events between them. A saved page
has no other event source than those automatic ones, and the counts match its
`button_to` forms — **Make a songbook** and **Add another song** on a sheet, and
each **Remove** on a set: the busiest set drew 11 events from one visitor, one
per removal.

`plausible.init()` in `app/views/layouts/application.html.erb` therefore passes
`formSubmissions: false`, `fileDownloads: false`, and `outboundLinks: false`
beside `autoCapturePageviews: false`, which the script documents under
[its configuration options](https://plausible.io/docs/script-extensions) and
applies over the site settings baked into the bundle.
`test/integration/analytics_test.rb` asserts the flags, so a snippet edit
cannot drop them silently. Re-check the Network tab after any Plausible release:
if a future script version ignores these options, automatic events return, and
smoke-test step 8 is what catches them.

Campaign performance is read from Plausible's own attribution, not from the
application. Plausible records `utm_source`, `utm_medium`, and `utm_campaign`
from the landing URL and attributes the visit to them, so a goal inherits that
attribution and can be filtered by source or channel with no application
support:

```text
https://printlyrics.app/?utm_source=outreach&utm_campaign=worship_handouts
```

The application additionally keeps an allowlisted copy of those values in
session storage and sends them as `campaign_source` and `campaign_name`
properties. Those properties cannot be read on this plan, and performance comes
from the native attribution above, so the machinery has no effect:
`AnalyticsCampaigns` holds the allowlists and is rendered into the page for
`app/javascript/lib/analytics.js`. Nothing in this document depends on it, and it
is a candidate for removal.

Plausible requires received events to be configured as goals before they appear
as conversions; see its [custom-event goal documentation](https://plausible.io/docs/custom-event-goals).
This plan has no funnel report, so every ordered question is read in Umami,
where the funnels are named and built in the section below. Plausible
reads the goals as their own rows, which is what its counts and the reviews
compare; read `Print Page Generated` and `Print Dialog Opened` separately as
well as through the Umami funnel, because a manual-entry visitor can
legitimately enter at the first step.

`Second Print Page Generated` is deliberately outside that linear funnel. It
fires during the second generation, which precedes the second print dialog, so
folding it into the ordered funnel would misorder the steps. Treat it as a
standalone goal: it is the first evidence that a visit is assembling a packet
rather than making a single sheet.

Create a shared site segment named **Organic Search**:

1. Open the dashboard filter.
2. Select **Channel**, `is`, **Organic Search**.
3. Save it as a site segment, not a personal segment.
4. Reopen the segment and confirm the goals are filtered with it.

Plausible documents [channel filtering and saved segments](https://plausible.io/docs/filters-segments).
Its attribution is visit-level and privacy-preserving; do not try to identify
individual visitors. Umami has no channel filter to match it: it reports the same
grouping under **Channels**, but its segment builder offers referrer, location,
environment, UTM, and event instead, so the ordered questions are read under one
referrer segment per search engine, which "Read the events in Umami" names. The
funnels stay where the ordered questions live, since this plan has no funnel
report of its own.

### Umami beside Plausible

Umami is this site's own analytics service. It runs on the same host as the web
container, as the two accessories in `config/deploy.yml`, and it measures beside
Plausible until the cutover below. It is the only reason the `entry_method`,
`songbook_size`, `songbook_origin`, `campaign_source`, `campaign_name`,
`page_count_in_session`, and `songbook_offer_surface` parameters the application
sends with events can be read next to the counts: Umami reports them as event
properties, on a plan that costs
nothing at any traffic, where this Plausible plan drops them. It also exposes a
read-only MCP endpoint, so the same figures can be asked for in sentences instead
of clicked through.

#### Set up the service

Host, database, and application are Kamal accessories. They are booted once, and
`bin/kamal deploy` neither starts, stops, nor updates them.

1. Point `analytics.printlyrics.app` at the web host in DNS. kamal-proxy requests
   the certificate for that host on first boot, so the record must exist first;
   without it the proxy has nothing to answer for and no certificate to serve.

   In Cloudflare that is one **A** record — name `analytics`, IPv4
   `46.225.21.111` (the host in `servers.web.hosts`), TTL Auto. Add no AAAA
   record unless the host really has IPv6, because Let's Encrypt prefers it and
   a wrong one breaks issuance. Do not use a CNAME: the record is the statement
   of where kamal-proxy runs.

   Proxied or not is the operator's call, and both work:

   - **DNS only** is the plain Kamal path. The proxy completes its preferred
     `tls-alpn-01` challenge on port 443 against the origin directly, and Umami
     sees each visitor's own address without trusting any header.
   - **Proxied** matches the apex, which is orange today and still holds a valid
     Let's Encrypt certificate, so issuance demonstrably completes behind it:
     kamal-proxy registers autocert's `http-01` handler, so a failed
     `tls-alpn-01` falls back to port 80, which the proxy passes through. It also
     hides the origin address, edge-caches `script.js`, and puts Cloudflare in
     front of the dashboard and the MCP endpoint. Two things must then be true:
     the zone's SSL/TLS mode is **Full (strict)**, because a Flexible setting
     loops against the proxy's own HTTP-to-HTTPS redirect, and the accessory's
     `forward_headers` stays on, because otherwise every visitor reaches Umami as
     a Cloudflare address and the visitor and session counts derived from it are
     wrong. If a renewal ever fails, Cloudflare's Bot Fight Mode challenging the
     ACME validator is the first thing to check.
2. Supply the two credentials from Proton Pass. `.kamal/secrets` reads them with
   `pass-cli` from items titled **PrintLyrics Umami DB** and **PrintLyrics Umami
   App Secret**, composes `UMAMI_DATABASE_URL` from the first, and the accessories
   receive them under PostgreSQL's and Umami's own variable names
   (`POSTGRES_PASSWORD`, `APP_SECRET`, `DATABASE_URL`). Neither value belongs in
   `config/deploy.yml`, and the database password is hex on purpose: it is
   interpolated into a connection string, so a value containing `:` `@` `/` or
   `#` would break it.

   The file is read on the machine running the command, never on the server:
   `pass-cli` does not exist there, and the containers only ever receive plain
   environment variables. Kamal uploads the resolved values over SSH into
   `.kamal/apps/printlyrics/env/accessories/*.env` on the host, mode `0600`, and
   starts each container with them. Every accessory command — boot, reboot,
   restore — therefore needs a live `pass-cli` session, and `bin/kamal deploy` is
   not one of them: it neither boots nor restarts an accessory. The deploy
   workflow writes its own `.kamal/secrets` holding only the registry password
   and `RAILS_MASTER_KEY`, so CI never sees these values.

   A missing or logged-out `pass-cli` does not stop the command. The substitution
   yields an empty value and the failure lands on the service instead: PostgreSQL
   refuses to initialize with an empty superuser password, and Umami cannot reach
   a database whose password is empty. Since `boot umami-db` reports only that the
   container started, run this first and expect `49`:

   ```sh
   pass-cli item view --vault-name printlyrics \
     --item-title "PrintLyrics Umami DB" --field password | wc -c
   ```
3. Boot the database before the application, then confirm both:

   ```sh
   bin/kamal accessory boot umami-db
   bin/kamal accessory boot umami
   bin/kamal accessory details umami
   ```

   The application exits on its first start if the database is not accepting
   connections yet. That is not a misconfiguration: `bin/kamal accessory start
   umami` once the database reports healthy.
4. Sign in at `https://analytics.printlyrics.app` as **admin** / **umami**, and
   change the password immediately. The dashboard is public; the account is the
   only thing in front of it. Two-factor authentication is available if
   `TWO_FACTOR_ENCRYPTION_KEY` (`openssl rand -hex 32`) is added to the
   accessory's secrets beside `UMAMI_APP_SECRET`; without it Umami refuses to
   enable 2FA rather than storing a secret it cannot encrypt.
5. Add the site: **Settings > Websites > Add website**, name it `PrintLyrics`,
   domain `printlyrics.app`. Copy the website ID it generates.
6. Set `UMAMI_WEBSITE_ID` in `config/deploy.yml` to that value and deploy. The
   tracker renders only when it is present — a blank value renders no tracker at
   all rather than one that reports to nothing — so a host that has not been
   through this step still reports to Plausible alone.
7. Leave `DISABLE_TELEMETRY=1` and `MCP_ENABLED=1` set, as `config/deploy.yml`
   ships them. Umami sends anonymous telemetry to its authors by default, and a
   self-hosted instance has no reason to participate. Do not add
   `DISABLE_BOT_CHECK` for the same reason: Umami excludes known bots from its
   statistics by default, by their User-Agent, and that variable turns the check
   off rather than tightening it.

Do not turn on the tracker's own capture. It reports the live `location.href`,
`document.title`, and `document.referrer`, and a saved page carries its share
token and its song title in all three. The application has sent every pageview
and every event through `app/javascript/lib/analytics.js` for that reason, and
the script tag in `app/views/layouts/application.html.erb` carries
`data-auto-track="false"` so the tracker only ever sends what it is handed.
`test/integration/analytics_test.rb` holds that flag the way the Plausible snippet's
`plausible.init` flags are held.

The tag is deferred rather than async so that it runs before the application's
own modules, which is what makes "exactly one pageview per visit" true from the
first page load. The cost is that an unreachable analytics host delays the
page's own scripts until its request fails; the host is on the same machine, so
that failure is immediate. Section 5 watches for it.

#### Read the events in Umami

Umami needs no goal registration: an event appears in its **Events** report the
first time it arrives, under the product's own name, spaces and all. There is no
name mapping to keep in step, and no per-event charge.

| Plausible | Umami surface | How the figure is read |
| --- | --- | --- |
| Goals grid | **Events** | The row's **Events** count is `Total`; **Visitors** is `Uniques`. |
| Goals grid | **Goals** | Optional saved conversions for the readings below. Umami counts an event without one. |
| Funnels | **Funnels** | Build three, each with a 60-minute window: **Search to sheet** (`Song Search Submitted` → `Print Page Generated`), **Paste to sheet** (`Manual Entry Submitted` → `Print Page Generated`), and **Sheet to printer** (`Print Page Generated` → `Print Dialog Opened`), the last set to open because a manual-entry visitor can enter at the first step. |
| Properties | **Event data** | Each property with its value counts: `entry_method`, `songbook_size`, `songbook_origin`, `campaign_source`, `campaign_name`, `page_count_in_session`, `songbook_offer_surface`, and the feedback event's `feedback_surface`, `song_query`, and `feedback_note`. |
| Explore | **Reports**, **Segments**, **Cohorts**, **Journeys** | Ad-hoc queries over the same events and properties. |

Rules that make those surfaces read correctly:

- **Properties are per event.** `entry_method` rides only on
  `Print Dialog Opened`, `songbook_origin` only on `Songbook Created`,
  `songbook_offer_surface` only on `Songbook Offer Shown`, and the size and
  page-count buckets only on the events that set them. Event data has no
  `(not set)` bucket, so a property that never arrived is absent rather than
  zero, and a breakdown needs the event that carries it.
- **A pageview is a payload with no name.** Umami files a payload without a name
  as a pageview and the rest as events, which is why `Print Page Generated` is an
  event row and not a pageview.
- **Visitors are visit-scoped, and the salt rotates.** Umami counts a visitor
  from a salted hash of address and user agent, rotating the salt monthly
  (`SALT_ROTATION`). That is the closest match to Plausible's Uniques, and it is
  a different quantity across a rotation boundary.
- **The population is the event, not the visitor total.** Anything that runs the
  tracker is counted and only a User-Agent check stands in front of it, so the
  visitor and pageview totals describe what the site received rather than who
  used it. Read every figure below from the events instead — an event's own
  **Visitors** and **Events** counts, or the funnel whose first step is
  `Print Page Generated`. A crawler does not open a print dialog or build a
  songbook, so those counts are the quantity Plausible's goals report, and the
  totals stay out of the comparison.
- **`Second Print Page Generated` stays out of the ordered funnel.** It fires
  before the second print dialog, so folding it into the funnel would misorder
  the steps. Read it as a standalone event, the way Plausible reads its own goal.
- **Umami adds no events.** Unlike the Google tag it replaces, it stores only
  what the application sends, so an unexpected event is instrumentation drift and
  nothing else.
- **A segment's filters are not a union, and a list belongs inside one value.**
  Two filters of the same dimension combine rather than union: a segment holding
  four referrer filters matches nothing, because no visit arrives from four
  engines, and nothing in the dashboard reports an empty segment. A comma list
  inside one filter's value is the OR — `referrer` `is` `bing.com,google.com`
  returns both rows — but a value carrying an operator takes one value only
  (`c.yahoo.com` returns all eight Yahoo subdomains, `c.yahoo.com,c.duckduckgo.com`
  returns nothing). One segment per engine is therefore what reads correctly, and
  a new segment is checked against a count the referrer report already gives
  before it is trusted.
- **A funnel takes a segment, not an inline dimension filter.** `run_funnel` with
  a saved segment scopes its steps correctly (`Mobile`: 44 in, 27 out), while the
  same call with `filters: { referrer: "bing.com" }` returns zero steps where the
  unfiltered funnel returns 174. A filtered funnel is therefore always the
  segment's, and a zero-step funnel is a filter problem before it is a product
  finding.
- **Nothing marks a change on the timeline by itself.** Annotate what changes a
  reading — an instrumentation release, a sitemap submission, an indexing change,
  the measurement start — because a chart shows an effect and never its cause,
  and the review reads both. The dashboard names the feature **Notes** and labels
  the control with that same word; it is a quiet button at the right end of the
  main chart's legend row, on the website's own route (`/websites/<id>`, no tab
  selected), and not an entry in the site navigation. Clicking a marker pulls the
  dashboard onto that note's date when the chart spans more than one day and is
  not hourly — the one click a review uses instead of re-filtering by hand. A note
  is written as the change happens and cannot be reconstructed afterwards, which
  is why the release that added the offer's two events (`0eca1fd`, 2026-10-07) is
  the worked example of one nobody wrote.

Campaign performance needs no application support: Umami attributes a visit from
the landing URL's own `utm_source`, `utm_medium`, and `utm_campaign`, and reports
them under **UTM**. `AnalyticsCampaigns` still serve Plausible's properties, and
ride on Umami's events as `campaign_source` and `campaign_name`; the cutover
deletes them, because the native attribution is what the readings use.

#### The readings a count cannot make

Two of the review's questions are attributed or ordered rather than counted, and
each is one MCP call over events that already arrive. Both are rows in the
section 4 table, and neither needs an object saved in the dashboard first.

- **Which channel's visitors make a sheet.** `run_attribution` with
  `conversionType: "event"`, `conversion: "Print Page Generated"`, and
  `model: "first-click"` reads a conversion against the referrer the visit
  arrived from. That report counts arrivals and this one counts generations, and
  the two rank differently: in the first eight days Bing brought three times
  Google's visitors and Google converted nearly twice their share.

  | Referrer | Visitors | Generating a sheet | Share |
  | --- | --- | --- | --- |
  | bing.com | 243 | 67 | 27.6% |
  | google.com | 77 | 39 | 50.6% |
  | search.yahoo.com and its subdomains | 168 | 20 | 11.9% |
  | duckduckgo.com | 55 | 15 | 27.3% |

  The same call answers for UTM, which is the only place a tagged link's channel
  is legible: seven converting visitors carried `utm_source` from a ChatGPT link,
  against the three the referrer dimension credits. Tag what is handed out — it
  is the one acquisition reading the application does not have to build.
- **Where a search dies.** `run_journey` with `startStep: "/"` continues the path
  after the landing page. In the same eight days, the step that follows a search
  is the miss prompt or the paste form about twice as often as a picked result,
  so the loss is in the picking rather than in the making. **Search to printer**
  states that as ordered steps; the journey states it before that funnel exists.
  Read the journey's counts as visits rather than visitors — they sum past the
  site's visitor total, and what the dashboard's own view shows is what settles
  the unit.

#### Ask Umami directly (MCP)

Umami ships a read-only MCP server, and `MCP_ENABLED=1` exposes it at
`https://analytics.printlyrics.app/mcp`. It calls the same API the dashboard
does, with the same website and team permissions as the key that authenticates
it, and it never reads the database.

1. Create a key under **Settings > API keys** in the dashboard and save it; it is
   shown once. Treat it as a credential: whoever holds it can read the analytics.
   It authenticates a client, not the application, so it belongs in Proton Pass
   beside the two service secrets rather than in `credentials.yml.enc`, which no
   Umami code path reads, or in a committed client config, which would hand it
   to everyone who clones the repository.
2. Point an MCP client at the endpoint with the key as a bearer token. The
   client has to support Streamable HTTP with custom headers:

   ```json
   {
     "mcpServers": {
       "umami": {
         "url": "https://analytics.printlyrics.app/mcp",
         "headers": { "Authorization": "Bearer umami_<your-api-key>" }
       }
     }
   }
   ```

3. Call `list_websites` first for the website ID every other tool needs, and
   `get_website_daterange` when it is not obvious which dates hold data. The
   pinned image (`ghcr.io/umami-software/umami:3.4.0`) exposes 23 read-only
   tools — `list_websites`, `get_website_daterange`, `get_website_stats`,
   `get_website_traffic`, `get_website_metrics`, `get_realtime`, `get_events`,
   `get_event_stats`, `get_event_series`, `get_event_properties`,
   `get_sessions`, `get_session_stats`, `get_session`, `get_annotations`,
   `list_segments`, `list_funnels`, `run_funnel`, `get_goals`, `run_journey`,
   `run_retention`, `run_attribution`, `get_revenue`, and `get_performance`.
   `get_revenue` and `get_session_stats` answer questions nothing else here
   asks, so the readings in section 4 do not use them, and `run_retention` and
   `get_performance` are refused for the reasons in "What Umami does not carry".
   The list follows the image tag rather than this document: after an image bump,
   ask the server itself with `tools/list`.
4. Dates are ISO 8601 strings, both ends supplied. The questions worth asking are
   the ones section 4 records by hand, so ask the same ones:

   > Which events did PrintLyrics get last week, and how many visits made a
   > second print page? Show how many printed a songbook as one job.

   > Which entry pages brought visits that opened a print dialog in September?

   > Which referrers brought the visitors that generated a print page, and which
   > UTM sources did they land with?

   > For visits that landed on the homepage, what followed a search?

5. Delete the key under **Settings > API keys** to revoke every client using it.
   Nothing in this document depends on MCP; it reads the reports the dashboard
   reads, and a blocked or revoked key changes no figure here.

#### What Umami does not carry

- **No history.** Nothing already in Plausible can be imported. Keep the export;
  the closing record in section 4 is its summary.
- **No single goals grid.** The Events report gives both counts per event, so
  every goal on the Plausible side is a row here, or one of the saved goals, and
  never one table. `Feedback Submitted` and the offer's two events are the
  exceptions on both sides: they are Umami's alone, and they are read from
  **Event data** rather than from a goal.
- **No automatic events to filter out.** That is the point, and it is also what
  has to be rechecked after an upgrade: the tag's `data-auto-track="false"` and a
  `/api/send` that stores only what it was sent are the two claims the production
  smoke test verifies.
- **No bot filtering beyond the User-Agent check.** Umami drops known bots by
  their User-Agent and nothing else: no referrer-spam domains, no data-center
  address ranges, and no traffic-pattern detection. Plausible applies all four
  layers, so a crawler that presents a browser User-Agent is recorded here and
  filtered there, and the two visitor and pageview totals are not comparable for
  that reason as well as for the visit definition. The reports have no bot
  dimension, the filter set has no exclusion operator, and collected rows cannot
  be removed, so this cannot be filtered out afterwards. The check has to happen
  before the payload arrives: at the edge, or in Umami's own `IGNORE_IP` list.

  The server-sent `Feedback Submitted` event obeys the same check, because it
  carries the visitor's own User-Agent: a submission from a client Umami reads
  as a bot is dropped with that client's pageviews, which keeps a bot-filled
  form out of the demand list. Umami answers 200 whether it stored the event or
  dropped it, so a clean return from `UmamiClient` confirms acceptance and not
  storage.
- **No page experience under this configuration.** The tracker installs its Core
  Web Vitals collectors from inside the initialization that
  `data-auto-track="false"` disables, so adding `data-performance="true"` alone
  collects nothing — and the only way to make it collect is to switch the
  tracker's own capture on, which sends a second nameless payload per load
  carrying the raw `location.href` and `document.title`. That doubles the
  pageview count and reports a saved page's token and song title, so the report
  stays empty on purpose. Read page experience from Search Console's Core Web
  Vitals report instead: it covers the three public surfaces and never sees a
  token-addressed page.
- **No session replay.** The instance serves `recorder.js` beside `script.js`,
  and nothing loads it. A recording captures the DOM of whatever page it runs on,
  and some of those pages are somebody's saved sheet, so loading it would be the
  privacy incident the smoke test looks for rather than a feature to switch on.
- **No retention.** A cohort here is the salted visitor hash, which rotates
  monthly and which no product surface can be tied to: `docs/measurement-contract.md`
  declines durable identity, so a returning-visitor reading would describe a hash
  rather than a visitor.
- **No revenue.** Nothing on the site is sold, so the report has nothing to read.

### Production event smoke test

Use a normal production browser with developer tools open. In the Network tab,
filter for the destinations you are checking — `plausible.io` and the analytics
host, `analytics.printlyrics.app`, while the parallel run lasts — and preserve
the log across navigation.

1. Arrive from a real search-result click when practical. For a controlled
   transport test, use a search-engine referrer, but do not count that test in
   launch performance.
2. Load the homepage and navigate to each printing guide and back. Each Turbo
   visit must send exactly one pageview.
3. Search for a song. Confirm `Song Search Submitted` arrives once and that a
   search which matched sends no `Song Search Missed`. Choose a result and
   confirm exactly one `Song Result Selected` arrives, before the lyrics load.
   Generate the print page from it and confirm `Print Page Generated` arrives
   once. Then search for something that cannot match and confirm the miss
   arrives once and that no `Song Result Selected` follows it. Submit the miss
   prompt with the song you wanted: the note is stored, and `Feedback Submitted`
   arrives at `analytics.printlyrics.app` carrying the song, the note, and
   `feedback_surface=search_miss` — from the server, so the request carries no
   browser event, and nothing carrying that query may reach `plausible.io`.
4. Open the print dialog. Confirm `Print Dialog Opened` is sent before the
   browser invokes its native print dialog, and that `Songbook Printed` is not
   sent, because a single sheet is not a set. Canceling the dialog is
   sufficient.
5. Generate a second song's print page in the same visit. Confirm
   `Second Print Page Generated` arrives exactly once. Generate a third song and
   confirm it does not arrive again. Reloading the first page must not add a
   count either, and the count must be the visit's: generating the second sheet
   in a second tab must still arrive as one visit's second sheet.
6. On that second sheet, confirm the songbook suggestion appears with both
   sheets counted, then choose **Make a songbook**. Confirm the set opens with
   every sheet in generation order, that it lists each song, and that exactly
   one `Songbook Created` and one `Songbook Created From Offer` arrive.
   `Songbook Offer Shown` arrives in Umami alone when the offer renders, and
   `Songbook Offer Dismissed` when **Not now** is chosen — with no such request
   to `plausible.io`, which has no goal for either. Reloading the set must
   report the creation events once, and so must leaving the set and returning to
   it with the browser's Back button: the visit keeps the pages, and the set's
   own page is restored from Turbo's cache with the creation marker still in it.
   Now return to the entry panel with two sheets in the visit, confirm the same
   suggestion appears there, and confirm **Not now** leaves it out of the next
   page rendered.
7. From a generated page, choose **Add another song**, add a second song, and
   print the set. Confirm exactly one `Songbook Created` arrives for the second
   song and no `Songbook Created From Offer`, because a set built by adding a
   song did not come from the suggestion. Confirm printing sends one
   `Print Dialog Opened` and one `Songbook Printed`, and that the print preview
   shows one sheet per song. Adding a third song must not report the creation
   again.
8. Confirm no other event arrives, custom or automatic. The application emits
   exactly thirteen names — ten the browser sends to both destinations, two the
   browser sends to Umami alone (`Songbook Offer Shown`, `Songbook Offer
   Dismissed`), and one the server sends (`Feedback Submitted`) — so an
   unexpected custom event means stale instrumentation; an automatic
   `Form: Submission`, `File Download`, or
   `Outbound Link: Click` means the `plausible.init` flags did not take
   effect, and on a saved page it reports the real token. Submit a `button_to`
   form on a saved page — **Make a songbook**, **Add another song**, or a
   set's **Remove** — and confirm the only request to `plausible.io` is the
   pageview, whose `u` reads `/lyrics/:token` or `/songbooks/:token`.
9. Inspect every event payload. A saved page must report the synthetic location
   `/lyrics/:token`, never the real token, and a songbook must report
   `/songbooks/:token`; that holds for the trailing-slash form Rails serves as
   the same page, `/lyrics/<token>/`. The entry form in songbook context reports its
   `songbook` parameter as `:token`, never the real value. No tracker payload may
   contain lyrics, song title, artist, album, or source ID. The one payload that
   carries a visitor's own words is the server-sent `Feedback Submitted` event,
   which exists to carry the song they typed and the note they wrote: it must
   reach `analytics.printlyrics.app` and must never reach `plausible.io`, and it
   must never carry the reply address from the same form.
10. In Plausible's realtime view, confirm the events appear. Reopen the **Organic
    Search** segment after a genuine organic visit and confirm its attribution.
11. Confirm the same flow reaches Umami. The tracker loads from
    `analytics.printlyrics.app/script.js` and posts every payload to `/api/send`
    on that same host, so filter the Network tab for the host and check that
    every step above arrived under the same name, with `url` and `title` reading
    `/lyrics/:token` or `/songbooks/:token` on saved surfaces. Read them back in
    the dashboard's **Events** report and their properties under **Event data**;
    the realtime view confirms delivery within seconds. A song title, an artist,
    or a real token in any browser-sent payload is the privacy incident below;
    the server-sent `Feedback Submitted` event carries the song the visitor
    typed by design, and reaching Plausible with it is the incident there.
    Umami stores only what the application sent — there is no auto-collected
    event that could carry a document URL behind the redaction, the way the
    Google tag's own events could. The tracker's capture is off at initialization
    in the script tag instead, and opening a saved page directly, in a fresh
    browser session, is what confirms it stayed off.

Both destinations run at once during the parallel run, so every check above has
to pass twice: a step that reaches only one of them is an unfinished migration,
not a partial success.

`Print Dialog Opened` is the product's **organic print completion** proxy. It
means the visitor opened the browser dialog; it does not prove that a physical
page was printed.

`Second Print Page Generated` is the **packet-intent** signal: the visit produced
a second distinct print page. It is a leading indicator that someone is preparing
several songs at once, which is the case a single-sheet tool serves poorly.

`Songbook Printed` is the subset of `Print Dialog Opened` where the printed
surface was a set, so it is the signal that a packet became one print job.
Compare it against `Second Print Page Generated`: a persistent gap means visitors
are still assembling sets by hand, and a closing gap means the songbook surface
absorbed the work. `Print Dialog Opened` minus `Songbook Printed` is the
single-sheet prints, which no goal reports directly.

The sheet that crosses two in a visit offers the visitor the sheets it already
has, as a songbook, so the offer and `Second Print Page Generated` fire from the
same moment. The offer is rendered from the visit the server holds, so every tab
gathers the same set and the entry panel — where a visit that already made
sheets returns for the next one — carries it as the same component. Either
answer settles it for the rest of the visit: **Make a songbook** is the creation
itself, and **Not now** is held in the same place, so the next page rendered
leaves the offer out.

The offer's own moments are Umami's alone: `Songbook Offer Shown` when a response
renders the strip, and `Songbook Offer Dismissed` when the visitor answers it
with **Not now**. They are properties-carried readings rather than goals: a
showing carries the same `page_count_in_session` the sheet events use, and
`songbook_offer_surface`, which is `sheet` on the page that crossed two and
`entry` on the panel the visit comes back to. They exist to say whether the
offer was there at all, which the question `Songbook Created From Offer` alone
cannot answer, and the surface is what separates a strip beside the print button
from one above a search box the visitor was already leaving. A showing is a
response rather than a visit: the entry panel's strip is inside the frame its
searches re-render, so one visit reports one for the sheet that crossed two and
one for every frame response beneath it, and the count is of renderings. Read
both names by session — whether the strip was there, and what the visits that
saw it went on to do.

Read the offer's conversion as the subset over the total the contract names —
`Songbook Created From Offer` over `Songbook Created` — and not over
`Songbook Offer Shown`: a rate over renderings answers how often a response
converted, not how often the offer did. Read the two surfaces apart before
drawing anything from either total: one name over both placements reports a strip
nobody saw and a strip nobody acted on as the same number.

`Second Print Page Generated` is the demand the suggestion can reach, because the
offer renders only to a visit that already holds two sheets, and it keeps the
definition above: the second distinct sheet of a visit, by whichever route that
visit made it. A visit that instead reaches two songs by adding one to a draft an
earlier visit started generated one sheet of its own, and reports
`Songbook Created` with `songbook_origin` of `add_song` and no
`Second Print Page Generated`. That set was finished rather than started, so read
the two names together and never as one another's denominator.

A low offer share next to a healthy remainder means the set surface is being
found without the nudge doing any work, and the suggestion is the part to
change. Both falling together means the set surface itself is not landing.

If an event is missing, first check the browser request, content blocking, the
exact event spelling, and whether the production asset release is current. For a
Umami event, also confirm the tracker loaded at all — a host that does not
resolve, a policy that does not allow its origin, or a blank `UMAMI_WEBSITE_ID`
each leave `window.umami` undefined and drop every event silently while
Plausible keeps reporting — and that the website ID in the dashboard is the one
in `config/deploy.yml`. If events duplicate, stop
the measurement launch and fix the Turbo/pageview lifecycle before collecting a
baseline. If a real token appears in any payload, or a song title or other song
metadata appears in a browser-sent payload or anywhere at Plausible, treat it as
a privacy incident: disable the affected instrumentation,
deploy the redaction fix, and exclude the contaminated test period. The
`analyticsUrl` helper in `app/javascript/lib/analytics.js` is the single place
that rewrites tokens, and the title and referrer every destination reports are
derived from it, so a new token-addressed surface must be added there. It covers
the trailing-slash form Rails serves as well; before it did, `/lyrics/<token>/`
reported the real token. Plausible's automatic
capture is the one reported location that never passes through it, which is why
the snippet disables it at initialization rather than relying on site settings.

### Cutting over to Umami

Run Umami and Plausible together for two weeks, then compare
`Print Page Generated` and `Print Dialog Opened` over the same window in each
dashboard, beside the four properties only Umami can read. What matters is that
every one of the ten events Plausible receives is present in both and that the
two series move together — the three names that are Umami's alone
(`Feedback Submitted`, `Songbook Offer Shown`, `Songbook Offer Dismissed`) are
absent from Plausible by design rather than a gap. The counts
will not match exactly, because the two products define a
visit and a visitor differently and because Plausible filters non-human traffic
in layers Umami does not have, so a lower Umami figure is not by itself a
failure — but an event missing from either is an instrumentation problem, and
the instrumentation is fixed before any number is compared. Compare the events,
their counts, and their properties, and read both the same way for the
population that generated a print page; the raw visitor and pageview totals are
the one figure that is not comparable, and Plausible's export is their record
for the days before the cutover.

To finish the cutover:

1. Remove the Plausible script and its bootstrap from
   `app/views/layouts/application.html.erb`, and drop `https://plausible.io` from
   both `policy.script_src` and `policy.connect_src` in
   `config/initializers/content_security_policy.rb`.
2. Delete `AnalyticsCampaigns`, `analytics_campaign_data`, `captureCampaign`, the
   `data-analytics-campaigns` attribute on the layout's `<body>`, and the
   campaign test in `test/integration/lyrics_flow_test.rb`. Umami reads
   `utm_source`, `utm_medium`, and `utm_campaign` natively, and the native
   attribution is what the reviews use.
3. Update `test/integration/analytics_test.rb` and
   `test/integration/content_security_policy_test.rb`: delete the Plausible
   snippet test and the Plausible origin from the policy assertions, which are
   the last places that name it.
4. Redeploy, re-run the production smoke test against Umami alone, and record the
   cutover release.
5. Cancel Plausible, and restart the 90-day measurement window at the cutover
   date. Changing the measurement system restarts the window; it never
   reinterprets the days collected under the previous one.
6. Keep the Plausible export with the launch issue. It is the record of
   everything before the cutover, and Umami can never hold it.

The service is the operator's now, and it is not part of a deploy:

```sh
bin/kamal accessory logs umami --follow
bin/kamal accessory reboot umami     # after bumping the image tag in config/deploy.yml
bin/kamal accessory exec umami-db "pg_dump -U umami umami" > umami-backup.sql
```

Upgrades are the operator's call, not CI's. Take a dump before one and keep it
somewhere that is not the server, because the database holds the only copy of
every measurement taken after the cutover.

## 3. Song catalog removed

Earlier releases published a browsable catalog at `/songs` plus one page per
sourced song, populated by `db/seeds.rb` and refreshed daily by
`bin/rails songs:verify_catalog`. That surface is gone.

It was removed after the September 2026 Search Console export showed the whole
catalog earning impressions but no clicks: the queries it targeted want to read
lyrics, and PrintLyrics deliberately publishes no lyric text. The pages ranked
in about position 50, and roughly 160 impressions produced zero clicks.

Nothing needs seeding or verifying now:

- `db/seeds.rb` keeps only an explanatory comment;
- the `songs:verify_catalog` task and its `kamal verify_catalog` alias are gone;
- `bin/ci` still runs `db:seed:replant` so the file stays loadable.

Songs are still recorded on demand when someone generates a sourced lyric sheet.
That preserves the private demand count without publishing anything. If a public
catalog is ever reintroduced, treat it as a new decision with its own
measurement plan rather than reviving these pages.


## 4. Capture baselines and review outcomes

On launch day, record zero or current values for the previous 30 days:

| Signal | Source |
| --- | --- |
| Valid indexed pages and excluded-page reasons | Search Console Page indexing |
| Queries, impressions, clicks, CTR, and average position | Search Console Performance |
| Organic visitors and entry pages | Plausible **Organic Search** segment |
| `Print Page Generated` from organic visits | Plausible goal |
| `Print Dialog Opened` from organic visits | Plausible goal |
| Generated-to-dialog conversion rate | Umami funnel **Sheet to printer** |
| Where a search is lost: nothing picked, or picked and not made | Umami funnel **Search to printer**, or `run_journey` from `/` |
| `Second Print Page Generated` from organic visits | Plausible goal |
| Share of generating visits that reach a second sheet | Plausible goal `Second Print Page Generated` |
| Sets printed as one job | Plausible goal `Songbook Printed` |
| Sets created, and how many came from the suggestion | Plausible goals `Songbook Created` and `Songbook Created From Offer` |
| Referrers that generated a sheet, and each one's share of its arrivals | Umami `run_attribution` over `Print Page Generated`, first click |

The parallel run reads every one of these twice. Record both figures for the same
window and label which system each came from: the **Source** column above names
the Plausible surface, which stays the destination of record until the cutover,
and the same signals read from Umami's **Events** report and its **Organic
Search** segment. After the cutover the Umami figures are the only ones, and the
recorded Plausible baseline is the comparison point for them.

At 30 days, confirm the instrumentation is reliable before changing any target.
Review query intent, indexed surfaces, impressions, clicks, both completion
events, packet intent, conversion, and device mix together. Visibility without
usable print pages is not success.

At 90 days, the calibration target is:

> At least 25 `Print Dialog Opened` events attributed to Organic Search in a
> rolling 30-day window.

Record the exact window, organic segment, total events, unique conversions, and
the corresponding `Print Page Generated` count. If the first 30 days exposed a
measurement problem, fix it and restart the window; do not reinterpret broken
data. Once reliable conversion data exists, the site owner may replace the
calibration target with a conversion-informed target without expanding product
scope.

Every review also reads the feedback visitors sent, because it is the one
channel that holds what no dashboard can: the songs they asked for and could
not get. In production the table is read with `bin/kamal feedback`, newest
first, and it is the demand list the next source addition or tool is chosen
from. A miss counts in Umami, and a stored submission is reported there as
`Feedback Submitted` with the query, the note, and the surface as properties, so
the demand can be read beside the counts that surround it. The table stays the
record: it alone holds the reply address.

### Recorded baseline, 2026-09-14

Taken from the Search Console performance export (three months to 2026-09-12)
and the Plausible export (49 days to 2026-09-14). Use these as the comparison
point for the 30- and 90-day reviews.

Google Search Console, whole period: 1,347 impressions, 64 clicks, 4.4% CTR.

| Window | Impressions/day | Clicks/day | Average position |
| --- | --- | --- | --- |
| August | 20.1 | 1.03 | 24.0 |
| September (to 09-12) | 50.3 | 2.17 | 9.6 |

| Device | Clicks | Impressions | CTR | Average position |
| --- | --- | --- | --- | --- |
| Mobile | 40 | 577 | 6.93% | 6.08 |
| Desktop | 23 | 749 | 3.07% | 26.71 |

| Page | Impressions | Clicks | CTR | Average position |
| --- | --- | --- | --- | --- |
| `/` | 973 | 54 | 5.55% | 16.79 |
| `/print-lyrics-on-one-page` | 323 | 10 | 3.10% | 17.21 |
| `/print-a-songbook` | — | — | — | — |

`/print-a-songbook` was added after this export and has no baseline row: its first
30 days are its baseline. Record it the same way as the other two.

Head queries, and the positions to beat:

| Query | Impressions | Clicks | CTR | Average position |
| --- | --- | --- | --- | --- |
| `printable lyrics` | 132 | 6 | 4.55% | 10.21 |
| `print lyrics` | 56 | 7 | 12.50% | 9.16 |
| `printable song lyrics` | 56 | 5 | 8.93% | 14.36 |
| `print song lyrics` | 12 | 2 | 16.67% | 11.58 |

Plausible: 725 visitors over 49 days, of which 36 days drew 10 visitors or
fewer. The last measured week (09-08 to 09-14) drew 334 visitors against 291
the week before.

Two properties of this baseline matter when reading the next review:

- The site sits on the page-one/page-two boundary. At position 16.79 the
  homepage earns impressions but few clicks. Position, not conversion, is the
  constraint, so judge changes by average position on the four head queries.
- Mobile ranks far better than desktop (6.08 against 26.71) and supplies 63% of
  clicks. Printing is a desktop task, so check whether mobile Google traffic
  converts into generated sheets before counting it as progress.

### Closing Plausible record, 2026-09-21

The all-time export taken before the Google dual run, covering 56 days from
2026-07-28: 908 visitors, 2,606 pageviews, and 941 visits. Channels: Organic
Search 662, Direct 214, AI Assistants 43, Referral 2. Sources: Bing 305, Direct
214, Yahoo! 141, Google 109, DuckDuckGo 96, ChatGPT 37. Conversions:
`Print Page Generated` 215 unique and 846 total, `Print Dialog Opened` 155 and
925, `Second Print Page Generated` 30 and 39.

`Songbook Created`, `Songbook Created From Offer`, and `Songbook Printed` show no
conversions anywhere in that export, because the songbook surface shipped on
2026-09-21, the day it was taken. They are unverified in production: confirm all
three in both dashboards during the parallel run, before the cutover.

Umami cannot ingest them either, so this section is the all-time record for the
period before the migration. Keep the exported CSVs with the launch issue.

### Reading the target after the cutover

The 90-day target above is written in Plausible's unit: 25 `Print Dialog Opened`
events, unique per visit, attributed to Organic Search. In Umami the same
quantity is that event's **Visitors** count under the organic segments — the
referrer segments, one per engine, because referrer is the acquisition dimension
Umami can filter on. Its **Channels** report groups the same traffic but cannot
be saved as a filter, so a channel figure is a reading of its own rather than a
segment's. The two numbers will not match, and a smaller Umami number is not by
itself a failure: Umami derives a visitor from a salted hash of address and user
agent, rotates that salt monthly, and files a payload with no name as a pageview,
so its unit differs from Plausible's in ways neither product controls. Record
which system a figure came from in every review, and never compare a Umami count
against a Plausible baseline as though the two measured the same thing. Restart
the window at the cutover so all 90 days come from one system.

### First Umami reading, 2026-10-07

The first eight days of the Umami series, from the site's creation on 2026-09-30
to this reading: 2,338 pageviews, 642 visitors, and 744 visits, over 45
countries. These are Umami's figures, so they are not a comparison against the
Plausible baseline above; they are the window the 30-day review stacks against,
and the first window that holds the whole songbook surface, which shipped on
2026-09-21.

The population, which is the figure every reading uses rather than the visitor
and pageview totals: `Song Search Submitted` 1,254 · `Print Page Generated` 723 ·
`Manual Entry Submitted` 639 · `Print Dialog Opened` 441 · `Song Search Missed`
185 · `Song Result Selected` 144 · `Second Print Page Generated` 87 ·
`Songbook Printed` 78 · `Songbook Created` 54 · `Songbook Created From Offer` 8 ·
`Feedback Submitted` 1.

| Reading | Value |
| --- | --- |
| Search to sheet | 317 in, 141 out — 55.5% lost |
| Paste to sheet | 161 in, 161 out |
| Sheet to printer | 174 in, 118 out — 32.2% lost |
| Search to printer | 318 in, 40 picked a result (87.4% lost), 30 generated a sheet, 19 opened the dialog |
| Mobile | 44 of 163 mobile visitors generated a sheet, the same share as the 174 of 642 overall |
| Searches that picked a result | 144 of 1,254 submissions, with 185 carrying the miss prompt |
| Generating visitors by first-click referrer | Bing 67 · Google 39 · Yahoo 20 · DuckDuckGo 15, of 174 |
| Journeys from `/` that take no further step | the largest single group in the report, 266 of its counts |
| Visitors by device | laptop 452 · mobile 163 · desktop 16 · tablet 11 |
| Visitors by channel | organicSearch 379 · referral 170 · direct 115 · llm 5, as the channel report scopes them |
| Properties | `entry_method` print_page 363 / songbook 78 · `songbook_origin` add_song 46 / offer 8 · `page_count_in_session` and `songbook_size` in their buckets · one feedback record |
| The three the closing record lists as unverified | confirmed in Umami: `Songbook Created` 54, `Songbook Created From Offer` 8, `Songbook Printed` 78; Plausible's half of that check is still the operator's |
| The offer's two Umami-only events | both arrive: `Songbook Offer Shown` 46 and `Songbook Offer Dismissed` 3 by 2026-10-08. This reading recorded no rows for them because it was taken before the first showing, at 2026-10-07T22:24:52Z — the release shipped that day, so the observation was unmade rather than the event missing, and it is made now |

## 5. Monitor and recover

Review these symptoms weekly during the first 90 days:

| Symptom | Owner action |
| --- | --- |
| Sitemap is not `Success` | Fix fetch/XML error, then resubmit and record recovery |
| Intended page is excluded | Inspect canonical, robots, response status, and rendered content |
| Saved lyric or songbook URL is indexed | Verify `noindex`, sitemap exclusion, and request recrawl |
| Impressions rise but completions do not | Compare entry pages and funnel drop-off; improve the tool path |
| Songbook guide earns impressions but no `Songbook Created` | Read the guide's entry pages against `Second Print Page Generated` and the offer; fix the path from the guide into a second sheet before rewriting the guide |
| Events disappear or duplicate | Repeat production smoke test and repair measurement before analysis |
| A real share token or saved path appears in a dashboard, export, or report | Privacy incident: confirm the `data-auto-track="false"` tag and the `plausible.init` flags in `app/views/layouts/application.html.erb`, check a saved page with and without a trailing slash, then exclude the contaminated days instead of reinterpreting them |
| Umami events lag or stop while Plausible's continue | Check `UMAMI_WEBSITE_ID` in `config/deploy.yml`, that `analytics.printlyrics.app` resolves and serves `/script.js`, that the policy still allows that origin, and that the accessory is running (`bin/kamal accessory details umami`); the two destinations fail independently |
| Every page's own scripts stall before the page becomes interactive | The tracker is deferred and therefore on the critical path. Confirm the analytics host answers instead of hanging — `curl -sI https://analytics.printlyrics.app/script.js` — and restart the accessory if it is not; the service is on the same machine, so a healthy failure is immediate, and a hanging one is the symptom worth catching |
| Takedown or source complaint | Remove the affected public song from discovery and preserve the private saved-page contract pending review |

Keeping lyrics out of indexable responses reduces exposure; it is not legal
clearance. Escalate source-policy or takedown questions to the site owner and do
not publish lyric text in public HTML, structured data, or analytics.

## 6. Roll back public discovery safely

Three pages are offered to crawlers: the homepage and the two printing guides,
`/print-lyrics-on-one-page` and `/print-a-songbook`. Each guide answers one
printing intent and links into the tool; neither is a keyword variant of the
other.

If a guide must be withdrawn:

1. Deploy a change that removes the affected URL from `SitemapsController`.
2. Return `noindex` or `410 Gone` from the withdrawn page as appropriate. Keep
   the homepage available unless the whole tool must come down.
3. Do not delete `Song` records to remove discovery. They hold no public URL and
   carry the private demand count.
4. Do not change or delete saved `/lyrics/<token>` pages. Their URL, retention,
   print controls, and `noindex` behavior remain intact.
5. Validate the new sitemap signed out, submit it in Search Console, and record
   the rollback release and recovery status.

Removing a URL from a sitemap alone is not an immediate removal mechanism.
Confirm the page-level robots/status response and monitor Search Console until
the withdrawn URLs leave the index.

## Dry-run sign-off

A second operator, or the site owner in a separate walkthrough, checks each
launch-record row using only this document. Record their name, date, omissions,
and corrections in the launch issue. U6 is operationally ready when that person
can reproduce the Search Console property and sitemap submission, every event in
the dashboard that receives it, the four Umami funnels and the saved segments,
the Umami properties, the MCP endpoint with their own API key, the organic
segment or comparison, the baseline, the review dates, and every recovery path
without undocumented knowledge.

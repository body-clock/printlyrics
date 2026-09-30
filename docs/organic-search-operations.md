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
| Plausible goals | Site owner | All nine exact event names exist, automatic goals off in settings and disabled in the snippet | |
| Umami parallel run | Site owner | The Umami site exists, the tracker renders on production, and all nine events plus every property arrive beside Plausible's | |
| Organic Search segment | Site owner | Saved site segment can be reopened | |
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
3. `Manual Entry Submitted`
4. `Print Page Generated`
5. `Print Dialog Opened`
6. `Second Print Page Generated`
7. `Songbook Created`
8. `Songbook Created From Offer`
9. `Songbook Printed`

Keep this list short deliberately. Each goal answers one question, and every
addition costs dashboard legibility and has to earn its place:

| Goal | Question it answers |
| --- | --- |
| `Song Search Submitted` | Did a visit look for a song by name? |
| `Song Search Missed` | Did that search find nothing? |
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
`campaign_source`, `campaign_name`, and `page_count_in_session` with events.
**Plausible cannot read any of them on this plan, and no reading below depends on
them here.** Umami records all six as event properties, which is why it runs
beside Plausible for the two weeks in "Umami beside Plausible" below: it is the
first destination this site has had that can report them next to the counts.

Four of the goals are subsets of another, which is how a total and a split are
read without properties:

- `Song Search Missed` is the subset of `Song Search Submitted` whose query
  found nothing. It counts the searches that failed to serve the visitor; what
  they were looking for is in the feedback table and never in analytics.
- `Second Print Page Generated` is the subset of `Print Page Generated` at the
  second distinct sheet of a visit.
- `Songbook Printed` is the subset of `Print Dialog Opened` where the printed
  surface was a set. `Print Dialog Opened` still counts every print, so its
  series and its 90-day target stay continuous.
- `Songbook Created From Offer` is the subset of `Songbook Created` where the
  suggestion started the set. The offer's conversion rate is one over the other.

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
Create a funnel from `Print Page Generated` to `Print Dialog Opened`. Manual-entry
visitors can legitimately enter at `Print Page Generated`, so review that goal and
`Print Dialog Opened` separately as well as through the funnel. Create the two
entry funnels beside it, one from `Song Search Submitted` and one from
`Manual Entry Submitted`, each ending at `Print Page Generated`. Comparing the
two ways into the tool is what no property on this plan can do.

`Second Print Page Generated` is deliberately outside that linear funnel. It
fires during the second generation, which precedes the second print dialog, so
folding it into the ordered funnel would misorder the steps. Treat it as a
standalone goal: it is the first evidence that a visit is assembling a packet
rather than making a single sheet.

Create a shared site segment named **Organic Search**:

1. Open the dashboard filter.
2. Select **Channel**, `is`, **Organic Search**.
3. Save it as a site segment, not a personal segment.
4. Reopen the segment and confirm the goals and funnel are filtered with it.

Plausible documents [channel filtering and saved segments](https://plausible.io/docs/filters-segments).
Its attribution is visit-level and privacy-preserving; do not try to identify
individual visitors.

### Umami beside Plausible

Umami is this site's own analytics service. It runs on the same host as the web
container, as the two accessories in `config/deploy.yml`, and it measures beside
Plausible until the cutover below. It is the only reason the `entry_method`,
`songbook_size`, `songbook_origin`, `campaign_source`, `campaign_name`, and
`page_count_in_session` parameters the application has always sent can be read
next to the counts: Umami reports them as event properties, on a plan that costs
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

#### Read the nine events in Umami

Umami needs no goal registration: an event appears in its **Events** report the
first time it arrives, under the product's own name, spaces and all. There is no
name mapping to keep in step, and no per-event charge.

| Plausible | Umami surface | How the figure is read |
| --- | --- | --- |
| Goals grid | **Events** | The row's **Events** count is `Total`; **Visitors** is `Uniques`. |
| Goals grid | **Goals** | Optional saved conversions for the readings below. Umami counts an event without one. |
| Funnels | **Funnels** | Build from `Print Page Generated` to `Print Dialog Opened`, set to open, because a manual-entry visitor can enter at the first step, and build the two entry funnels the goals describe. |
| Properties | **Event data** | Each property with its value counts: `entry_method`, `songbook_size`, `songbook_origin`, `campaign_source`, `campaign_name`, `page_count_in_session`. |
| Explore | **Reports**, **Segments**, **Cohorts**, **Journeys** | Ad-hoc queries over the same events and properties. |

Rules that make those surfaces read correctly:

- **Properties are per event.** `entry_method` rides only on
  `Print Dialog Opened`, `songbook_origin` only on `Songbook Created`, and the
  size and page-count buckets only on the events that set them. Event data has no
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

Campaign performance needs no application support: Umami attributes a visit from
the landing URL's own `utm_source`, `utm_medium`, and `utm_campaign`, and reports
them under **UTM**. `AnalyticsCampaigns` still serve Plausible's properties, and
ride on Umami's events as `campaign_source` and `campaign_name`; the cutover
deletes them, because the native attribution is what the readings use.

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
   asks, so the readings in section 4 do not use them. The list follows the
   image tag rather than this document: after an image bump, ask the server
   itself with `tools/list`.
4. Dates are ISO 8601 strings, both ends supplied. The questions worth asking are
   the ones section 4 records by hand, so ask the same ones:

   > Which events did PrintLyrics get last week, and how many visits made a
   > second print page? Show how many printed a songbook as one job.

   > Which entry pages brought visits that opened a print dialog in September?

5. Delete the key under **Settings > API keys** to revoke every client using it.
   Nothing in this document depends on MCP; it reads the reports the dashboard
   reads, and a blocked or revoked key changes no figure here.

#### What Umami does not carry

- **No history.** Nothing already in Plausible can be imported. Keep the export;
  the closing record in section 4 is its summary.
- **No single goals grid.** The Events report gives both counts per event, but
  the nine goals are read as nine rows or as saved goals, not as one table.
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
3. Search for a song. Confirm `Song Search Submitted` arrives once, that
   choosing a result sends nothing of its own, and that a search which matched
   sends no `Song Search Missed`. Search for something that cannot match and
   confirm the miss arrives once. Generate the print page from a result and
   confirm `Print Page Generated` arrives once.
4. Open the print dialog. Confirm `Print Dialog Opened` is sent before the
   browser invokes its native print dialog, and that `Songbook Printed` is not
   sent, because a single sheet is not a set. Canceling the dialog is
   sufficient.
5. Without closing the tab, generate a second song's print page. Confirm
   `Second Print Page Generated` arrives exactly once. Generate a third song and
   confirm it does not arrive again. Reloading the first page must not add a
   count either.
6. On that second sheet, confirm the songbook suggestion appears with both
   sheets counted, then choose **Make a songbook**. Confirm the set opens with
   every sheet in generation order, that it lists each song, and that exactly
   one `Songbook Created` and one `Songbook Created From Offer` arrive. The
   suggestion itself sends no event, and **Not now** must send none either.
   Reloading the set must report neither again.
7. From a generated page, choose **Add another song**, add a second song, and
   print the set. Confirm exactly one `Songbook Created` arrives for the second
   song and no `Songbook Created From Offer`, because a set built by adding a
   song did not come from the suggestion. Confirm printing sends one
   `Print Dialog Opened` and one `Songbook Printed`, and that the print preview
   shows one sheet per song. Adding a third song must not report the creation
   again.
8. Confirm no other event arrives, custom or automatic. The application emits
   exactly nine names, so an unexpected custom event means stale
   instrumentation; an automatic `Form: Submission`, `File Download`, or
   `Outbound Link: Click` means the `plausible.init` flags did not take
   effect, and on a saved page it reports the real token. Submit a `button_to`
   form on a saved page — **Make a songbook**, **Add another song**, or a
   set's **Remove** — and confirm the only request to `plausible.io` is the
   pageview, whose `u` reads `/lyrics/:token` or `/songbooks/:token`.
9. Inspect every event payload. A saved page must report the synthetic location
   `/lyrics/:token`, never the real token, and a songbook must report
   `/songbooks/:token`; that holds for the trailing-slash form Rails serves as
   the same page, `/lyrics/<token>/`. The entry form in songbook context reports its
   `songbook` parameter as `:token`, never the real value. No payload may
   contain lyrics, song title, artist, album, or source ID.
10. In Plausible's realtime view, confirm the events appear. Reopen the **Organic
    Search** segment after a genuine organic visit and confirm its attribution.
11. Confirm the same flow reaches Umami. The tracker loads from
    `analytics.printlyrics.app/script.js` and posts every payload to `/api/send`
    on that same host, so filter the Network tab for the host and check that
    every step above arrived under the same name, with `url` and `title` reading
    `/lyrics/:token` or `/songbooks/:token` on saved surfaces. Read them back in
    the dashboard's **Events** report and their properties under **Event data**;
    the realtime view confirms delivery within seconds. A song title, an artist,
    or a real token in any payload is the privacy incident below.
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

The sheet that is generated second in a tab offers the visitor the sheets it
already has, as a songbook, so the offer and `Second Print Page Generated` fire
from the same moment. Neither the offer nor its dismissal sends an event.

Read the offer's conversion as `Songbook Created From Offer` over
`Songbook Created`. `Second Print Page Generated` counts visits that made a
second sheet, by any route, so it is the denominator for how much of that demand
the suggestion reaches at all.

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
baseline. If a real token or song metadata is
present, treat it as a privacy incident: disable the affected instrumentation,
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
every one of the nine events is present in both and that the two series move
together. The counts will not match exactly, because the two products define a
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
| Generated-to-dialog conversion rate | Plausible goals/funnel |
| `Second Print Page Generated` from organic visits | Plausible goal |
| Share of generating visits that reach a second sheet | Plausible goal `Second Print Page Generated` |
| Sets printed as one job | Plausible goal `Songbook Printed` |
| Sets created, and how many came from the suggestion | Plausible goals `Songbook Created` and `Songbook Created From Offer` |

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
not get. In production that is `bin/kamal feedback`, newest first, and the
queries there are the demand list the next source addition or tool is chosen
from. A miss counts in Umami; what was missed lives only there.

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
quantity is that event's **Visitors** count under the **Organic Search**
segment. The two numbers will not match, and a smaller Umami number is not by
itself a failure: Umami derives a visitor from a salted hash of address and user
agent, rotates that salt monthly, and files a payload with no name as a pageview,
so its unit differs from Plausible's in ways neither product controls. Record
which system a figure came from in every review, and never compare a Umami count
against a Plausible baseline as though the two measured the same thing. Restart
the window at the cutover so all 90 days come from one system.

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
can reproduce the Search Console property and sitemap submission, all nine
events in both dashboards, the Umami properties, the MCP endpoint with their own
API key, the organic segment or comparison, the baseline, the review dates, and
every recovery path without undocumented knowledge.

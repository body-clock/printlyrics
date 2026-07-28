# Organic Search Operations

This runbook starts and operates PrintLyrics' organic-search measurement window.
It does not promise a search ranking. The site owner owns every external-console
step, the recurring catalog check, and the 30- and 90-day reviews.

Do not start the 90-day window until the launch checklist is complete.

## Launch record

Copy this table into the launch issue and fill every field.

| Evidence | Owner | Expected result | Recorded value |
| --- | --- | --- | --- |
| Production release and smoke-test time | Site owner | Current release is healthy | |
| Search Console Domain property | Site owner | `printlyrics.app` is verified | |
| Sitemap fetch | Site owner | `https://printlyrics.app/sitemap.xml` is `Success` | |
| Plausible goals | Site owner | All four exact event names exist | |
| Organic Search segment | Site owner | Saved site segment can be reopened | |
| Launch catalog seed | Site owner | Twenty metadata-only song pages exist | |
| Verifier first run | Site owner | Command exits successfully and prints counts | |
| Verifier next run | Site owner | Scheduler shows the next daily run | |
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
   non-indexed counts. Inspect the homepage, guide, `/songs`, and one eligible
   song with URL Inspection.

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

## 2. Configure Plausible

In the Plausible site for `printlyrics.app`, open **Settings > Goals** and add a
custom-event goal for each exact, case-sensitive name:

1. `Song Search Submitted`
2. `Song Selected`
3. `Print Page Generated`
4. `Print Dialog Opened`

Do not constrain these goals with song titles, artist names, source IDs, lyric
tokens, or URLs. The only custom property the application sends is the
low-cardinality `entry_method` workflow context.

Plausible requires received events to be configured as goals before they appear
as conversions; see its [custom-event goal documentation](https://plausible.io/docs/custom-event-goals).
Create a funnel with the four goals in the order above. Manual-entry visitors
can legitimately enter at `Print Page Generated`, so review that goal and
`Print Dialog Opened` separately as well as through the search funnel.

Create a shared site segment named **Organic Search**:

1. Open the dashboard filter.
2. Select **Channel**, `is`, **Organic Search**.
3. Save it as a site segment, not a personal segment.
4. Reopen the segment and confirm the goals and funnel are filtered with it.

Plausible documents [channel filtering and saved segments](https://plausible.io/docs/filters-segments).
Its attribution is visit-level and privacy-preserving; do not try to identify
individual visitors.

### Production event smoke test

Use a normal production browser with developer tools open. In the Network tab,
filter for Plausible event requests and preserve the log across navigation.

1. Arrive from a real search-result click when practical. For a controlled
   transport test, use a search-engine referrer, but do not count that test in
   launch performance.
2. Load the homepage and navigate to the one-page guide and back. Each Turbo
   visit must send exactly one pageview.
3. Search for a song, select a result, and generate its print page. Confirm the
   first three custom events arrive once and in order.
4. Open the print dialog. Confirm `Print Dialog Opened` is sent before the
   browser invokes its native print dialog. Canceling the dialog is sufficient.
5. Inspect every event payload. A saved page must report the synthetic location
   `/lyrics/:token`, never the real token. No payload may contain lyrics, song
   title, artist, album, or source ID.
6. In Plausible's realtime view, confirm the events appear. Reopen the **Organic
   Search** segment after a genuine organic visit and confirm its attribution.

`Print Dialog Opened` is the product's **organic print completion** proxy. It
means the visitor opened the browser dialog; it does not prove that a physical
page was printed.

If an event is missing, first check the browser request, content blocking, the
exact goal spelling, and whether the production asset release is current. If
events duplicate, stop the measurement launch and fix the Turbo/pageview
lifecycle before collecting a baseline. If a real token or song metadata is
present, treat it as a privacy incident: disable the affected instrumentation,
deploy the redaction fix, and exclude the contaminated test period.

## 3. Schedule catalog verification

Seed the initial catalog once on an existing production database:

```sh
bin/kamal app exec --reuse "bin/rails db:seed"
```

The seed is idempotent. It adds 20 metadata-only songs selected from entries
near the top of the Genius global chart on July 16, 2026, makes those curated
pages public, and does not overwrite metadata later refreshed from LRCLIB.
It never stores lyrics.

Outside this curated set, a sourced song becomes public only after three
successful print-page generations. This threshold reduces the chance that one
visitor's action is immediately disclosed; it does not represent three distinct
people. Manually entered lyrics never enter the song catalog.

Run a bounded batch daily. The task checks unverified and least-recently checked
promoted songs first. A confirmed source not-found removes a song from public
discovery; a transient source failure leaves its prior status intact for retry.

From a production application context:

```sh
LIMIT=100 bin/rails songs:verify_catalog
```

From the deployment checkout:

```sh
bin/kamal verify_catalog
```

The Kamal alias uses the default limit of 100. For a smaller manual batch:

```sh
bin/kamal app exec --reuse "env LIMIT=25 bin/rails songs:verify_catalog"
```

Configure the host scheduler for one daily invocation. Prevent overlapping
runs, retain stdout/stderr, and alert on a nonzero exit. A successful run prints
`checked`, `available`, `unavailable`, and `failed` counts. The scheduler record
must show:

- owner: site owner;
- exact command and working directory;
- daily cadence and timezone;
- last exit status and captured output;
- first successful run time;
- next scheduled run time.

`failed` can be nonzero when LRCLIB has transient errors even though the command
completes. Review it daily. Retry the same bounded command once after the source
recovers; repeated checks are safe. If failures persist, reduce `LIMIT`, verify
LRCLIB outside the application, and leave existing pages in their last known
state. Never respond to a transient outage by bulk-marking songs unavailable.

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

At 30 days, confirm the instrumentation is reliable before changing any target.
Review query intent, indexed surfaces, impressions, clicks, both completion
events, conversion, device mix, and catalog-verifier health together. Visibility
without usable print pages is not success.

At 90 days, the calibration target is:

> At least 25 `Print Dialog Opened` events attributed to Organic Search in a
> rolling 30-day window.

Record the exact window, organic segment, total events, unique conversions, and
the corresponding `Print Page Generated` count. If the first 30 days exposed a
measurement problem, fix it and restart the window; do not reinterpret broken
data. Once reliable conversion data exists, the site owner may replace the
calibration target with a conversion-informed target without expanding product
scope.

## 5. Monitor and recover

Review these symptoms weekly during the first 90 days:

| Symptom | Owner action |
| --- | --- |
| Sitemap is not `Success` | Fix fetch/XML error, then resubmit and record recovery |
| Intended page is excluded | Inspect canonical, robots, response status, and rendered content |
| Saved lyric URL is indexed | Verify `noindex`, sitemap exclusion, and request recrawl |
| Impressions rise but completions do not | Compare entry pages and funnel drop-off; improve the tool path |
| Events disappear or duplicate | Repeat production smoke test and repair measurement before analysis |
| Verifier has repeated failures | Reduce batch, inspect source health, retry safely after recovery |
| Takedown or source complaint | Remove the affected public song from discovery and preserve the private saved-page contract pending review |

Keeping lyrics out of indexable responses reduces exposure; it is not legal
clearance. Escalate source-policy or takedown questions to the site owner and do
not publish lyric text in public catalog HTML, structured data, or analytics.

## 6. Roll back public discovery safely

If the catalog or guide must be withdrawn:

1. Stop submitting new public URLs and pause the verifier schedule.
2. Deploy a change that removes the affected guide, browse, and song URLs from
   the sitemap.
3. Return `noindex` or `410 Gone` from withdrawn public catalog pages as
   appropriate. Keep the homepage available.
4. Do not delete `Song` records merely to remove discovery.
5. Do not change or delete saved `/lyrics/<token>` pages. Their URL, retention,
   print controls, and `noindex` behavior remain intact.
6. Validate the new sitemap signed out, submit it in Search Console, and record
   the rollback release and recovery status.

Removing a URL from a sitemap alone is not an immediate removal mechanism.
Confirm the page-level robots/status response and monitor Search Console until
the withdrawn URLs leave the index.

## Dry-run sign-off

A second operator, or the site owner in a separate walkthrough, checks each
launch-record row using only this document. Record their name, date, omissions,
and corrections in the launch issue. U6 is operationally ready when that person
can reproduce the Search Console property and sitemap submission, all four
Plausible goals, the organic segment, a bounded verifier run, the baseline, the
review dates, and every recovery path without undocumented knowledge.

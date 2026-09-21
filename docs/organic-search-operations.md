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
| Plausible goals | Site owner | All three exact event names exist, automatic goals off | |
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
   non-indexed counts. Inspect the homepage and the guide with URL Inspection.

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

1. `Print Page Generated`
2. `Print Dialog Opened`
3. `Second Print Page Generated`

Keep this list short deliberately. Three goals answer three distinct questions:
did the tool produce a sheet, did that sheet reach the printer, and is anyone
assembling more than one. Every additional goal costs dashboard legibility and
has to earn its place against those questions.

Do not constrain these goals with song titles, artist names, source IDs, lyric
tokens, or URLs. The application sends only low-cardinality workflow properties:
`entry_method`, `songbook_size`, `campaign_source`, `campaign_name`, and
`page_count_in_session`.

`page_count_in_session` is a bucket — `1`, `2`, `3-5`, or `6+` — reporting how
many distinct print pages the visit had generated when the event fired. It is a
running count, not a final total, so read the highest bucket a session reached
rather than the value on any single event. Both `Print Page Generated` and
`Print Dialog Opened` carry it.

A songbook — the ordered set of pages a visit assembles and prints as one job —
adds no fourth goal. Printing a set reuses `Print Dialog Opened` and is read
from two properties on that event:

- `entry_method` is `print_page` for a single generated sheet and `songbook` for
  a set. Compare the two to see whether the set surface is actually used.
- `songbook_size` is the same `2`, `3-5`, `6+` bucket shape, reporting how many
  songs the printed set held.

A single-song sheet printed from a songbook reports `entry_method: songbook`
with `songbook_size: 1`. Read that as a set the visitor had not finished adding
to, not as an ordinary single-page print.

Turn off Plausible's automatic goals — **Form submissions**, **File downloads**,
**Outbound links**, and **404** — under **Settings > General > Default
tracking**. `Form: Submission` pools every form on the site into one number (the
search form, each result button, and the generate form all post), so it does not
describe any single product step, and it counts toward billable pageviews.
PrintLyrics sends none of these events from application code.

Campaign properties are retained in session storage after a visitor arrives on
an allowlisted campaign URL. Supported launch values are:

- `utm_source`: `church`, `email`, `facebook`, `musician`, `outreach`, `reddit`,
  or `teacher`
- `utm_campaign`: `large_print`, `singer_rehearsal`, `teacher_handouts`, or
  `worship_handouts`

`AnalyticsCampaigns` is the source of truth for both lists; it is rendered into
the page and read by `app/javascript/lib/analytics.js`. Change that object and
this section together.

For example:

```text
https://printlyrics.app/?utm_source=outreach&utm_campaign=worship_handouts
```

Unknown values are ignored so arbitrary query-string content cannot become an
analytics property.

Plausible requires received events to be configured as goals before they appear
as conversions; see its [custom-event goal documentation](https://plausible.io/docs/custom-event-goals).
Create a funnel from `Print Page Generated` to `Print Dialog Opened`. Manual-entry
visitors can legitimately enter at `Print Page Generated`, so review that goal and
`Print Dialog Opened` separately as well as through the funnel.

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

### Production event smoke test

Use a normal production browser with developer tools open. In the Network tab,
filter for Plausible event requests and preserve the log across navigation.

1. Arrive from a real search-result click when practical. For a controlled
   transport test, use a search-engine referrer, but do not count that test in
   launch performance.
2. Load the homepage and navigate to the one-page guide and back. Each Turbo
   visit must send exactly one pageview.
3. Search for a song and select a result. Confirm neither action sends a custom
   event. Generate the print page and confirm `Print Page Generated` arrives
   once and carries `page_count_in_session: "1"`.
4. Open the print dialog. Confirm `Print Dialog Opened` is sent before the
   browser invokes its native print dialog, and that it carries the same
   bucket. Canceling the dialog is sufficient.
5. Without closing the tab, generate a second song's print page. Confirm
   `Print Page Generated` now carries `page_count_in_session: "2"` and that
   `Second Print Page Generated` arrives exactly once. Generate a third song and
   confirm it does not arrive again. Reloading the first page must not add a
   count either.
6. On that second sheet, confirm the songbook suggestion appears with both
   sheets counted, then choose **Make a songbook**. Confirm the set opens with
   every sheet in generation order and that it lists each song. The suggestion
   sends no event of its own, and **Not now** must send none either.
7. From a generated page, choose **Add another song**, add a second song, and
   print the set. Confirm exactly one `Print Dialog Opened` arrives for the
   whole set, carrying `entry_method: "songbook"` and `songbook_size: "2"`, and
   that the print preview shows one sheet per song.
8. Confirm no other custom event arrives. The application emits exactly three
   event names, so an unexpected one means stale instrumentation or an automatic
   goal still enabled in site settings.
9. Inspect every event payload. A saved page must report the synthetic location
   `/lyrics/:token`, never the real token, and a songbook must report
   `/songbooks/:token`. The entry form in songbook context reports its
   `songbook` parameter as `:token`, never the real value. No payload may
   contain lyrics, song title, artist, album, or source ID.
10. In Plausible's realtime view, confirm the events appear. Reopen the **Organic
    Search** segment after a genuine organic visit and confirm its attribution.

`Print Dialog Opened` is the product's **organic print completion** proxy. It
means the visitor opened the browser dialog; it does not prove that a physical
page was printed.

`Second Print Page Generated` is the **packet-intent** signal: the visit produced
a second distinct print page. It is a leading indicator that someone is preparing
several songs at once, which is the case a single-sheet tool serves poorly.

`Print Dialog Opened` with `entry_method: songbook` is the signal that the
packet actually became one print job. Compare its volume against
`Second Print Page Generated`: a persistent gap means visitors still assemble
sets by hand, and a closing gap means the songbook surface absorbed the work.

The sheet that is generated second in a tab offers the visitor the sheets it
already has, as a songbook, so the offer and `Second Print Page Generated` fire
from the same moment. Neither the offer nor its dismissal sends an event: read
the offer's effect as the change in that same gap over time, not as a
conversion of its own. A set can also be started without an offer, and an offer
can be declined, so the two counts were never expected to match. Adding a goal
for the offer itself is a separate decision that has to earn its place against
the three-goal budget.

If an event is missing, first check the browser request, content blocking, the
exact goal spelling, and whether the production asset release is current. If
events duplicate, stop the measurement launch and fix the Turbo/pageview
lifecycle before collecting a baseline. If a real token or song metadata is
present, treat it as a privacy incident: disable the affected instrumentation,
deploy the redaction fix, and exclude the contaminated test period. The
`analyticsUrl` helper in `app/javascript/lib/analytics.js` is the single place
that rewrites tokens, so a new token-addressed surface must be added there.

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
| Share of generating sessions that reach a second sheet | `page_count_in_session` on `Print Page Generated` |
| Sets printed as one job, and their size | `entry_method` and `songbook_size` on `Print Dialog Opened` |

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

## 5. Monitor and recover

Review these symptoms weekly during the first 90 days:

| Symptom | Owner action |
| --- | --- |
| Sitemap is not `Success` | Fix fetch/XML error, then resubmit and record recovery |
| Intended page is excluded | Inspect canonical, robots, response status, and rendered content |
| Saved lyric or songbook URL is indexed | Verify `noindex`, sitemap exclusion, and request recrawl |
| Impressions rise but completions do not | Compare entry pages and funnel drop-off; improve the tool path |
| Events disappear or duplicate | Repeat production smoke test and repair measurement before analysis |
| Takedown or source complaint | Remove the affected public song from discovery and preserve the private saved-page contract pending review |

Keeping lyrics out of indexable responses reduces exposure; it is not legal
clearance. Escalate source-policy or takedown questions to the site owner and do
not publish lyric text in public HTML, structured data, or analytics.

## 6. Roll back public discovery safely

Only two pages are offered to crawlers: the homepage and the printing guide.

If either must be withdrawn:

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
can reproduce the Search Console property and sitemap submission, all three
Plausible goals, the organic segment, the baseline, the review dates, and every
recovery path without undocumented knowledge.

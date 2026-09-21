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
| Plausible goals | Site owner | All six exact event names exist, automatic goals off | |
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
4. `Songbook Created`
5. `Songbook Created From Offer`
6. `Songbook Printed`

Keep this list short deliberately. Each goal answers one question, and every
addition costs dashboard legibility and has to earn its place:

| Goal | Question it answers |
| --- | --- |
| `Print Page Generated` | Did the tool produce a sheet? |
| `Print Dialog Opened` | Did a sheet reach the printer? |
| `Second Print Page Generated` | Is a visit assembling more than one sheet? |
| `Songbook Created` | Did a set of sheets come into being? |
| `Songbook Created From Offer` | Did the suggestion produce that set? |
| `Songbook Printed` | Did a set reach the printer as one job? |

### Why these are goals and not properties

This site's Plausible plan does not include custom properties, so an event's
name is the only dimension the dashboard can read. Every split that would
otherwise be a property is its own goal instead.

The application still sends `entry_method`, `songbook_size`, `songbook_origin`,
`campaign_source`, `campaign_name`, and `page_count_in_session` with events.
**None of them can be read on this plan, and no reading below depends on them.**
They are left in place so that a plan change activates them without a code
change. Until then they are inert, and payload inspection cannot verify them in
the dashboard.

Two of the goals are subsets of another, which is how a total and a split are
read without properties:

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
   once.
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
8. Confirm no other custom event arrives. The application emits exactly six
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
| Share of generating visits that reach a second sheet | Plausible goal `Second Print Page Generated` |
| Sets printed as one job | Plausible goal `Songbook Printed` |
| Sets created, and how many came from the suggestion | Plausible goals `Songbook Created` and `Songbook Created From Offer` |

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
can reproduce the Search Console property and sitemap submission, all six
Plausible goals, the organic segment, the baseline, the review dates, and every
recovery path without undocumented knowledge.

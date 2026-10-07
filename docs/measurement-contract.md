# Measurement Contract

This is the measurement contract for the small musician-focused tools that
share one analytics pipeline: what analytics decides, what every tool reports,
and what never leaves the browser.

## Why this exists, and what analytics decides

Analytics is a detector of where a shipped flow leaks. It is never a generator
of what to build: direction, demand research, and trends decide what a flow
contains, and instrumentation only says whether the flow that shipped works.

The recorded baseline in section 4 of `docs/organic-search-operations.md` is
roughly 16 visitors a day and 3.8 unique `Print Page Generated` a day. At that
scale a ten-to-twenty-percent effect is unreadable in days. Only
order-of-magnitude structure is legible: a step of the funnel losing most of its
visitors, or a crawlable surface earning no pageviews.

Read the event population rather than the visitor and pageview totals, which
count traffic that never used the tool:
`docs/organic-search-operations.md` carries the bot-filtering reason the two
destinations disagree on those totals.

## The vocabulary

The naming rule is `<Product Noun> <Past-Tense Verb>`, in the product's own
words, and the dashboards keep the name verbatim. There is no mapping table:
the name the code sends is the name the dashboard lists.

One event per distinct thing worth counting. When a total and its subset both
matter, the subset is its own event, because this plan cannot read custom
properties. `Songbook Created` and `Songbook Created From Offer` are the worked
example: the subset over the total is the offer's conversion rate.

A saved funnel carries a name too, and it follows the same rule: the funnel that
reads a tool's attempt to its output is named `<entry> to <outcome>` in the
product's own words. The print tool's three are `Search to sheet`, `Paste to
sheet`, and `Sheet to printer`.

The thirteen names in use, grouped by the flow that fires them:

- Print flow: `Print Page Generated`, `Second Print Page Generated`, `Print
  Dialog Opened`, `Songbook Created`, `Songbook Created From Offer`, `Songbook
  Printed`, `Songbook Offer Shown`, `Songbook Offer Dismissed`.
- Entry flow: `Song Search Submitted`, `Song Search Missed`, `Song Result
  Selected`, `Manual Entry Submitted`, `Feedback Submitted`.

## The three slots every tool fills

Every tool declares an attempt, an output, and a completion, each with its own
event: the attempt is what the visitor asked for, the output is what the tool
produced, and the completion is what the visitor did with it.

The print tool is the worked example. Its attempt is `Song Search Submitted`
when the visitor searched or `Manual Entry Submitted` when they pasted lyrics.
Those two are not disjoint: the generate form posts to the same endpoint from
either route, so a sheet built from a search result reports both
`Song Result Selected` and `Manual Entry Submitted`. `Song Search Submitted`
minus `Song Result Selected` minus `Song Search Missed` is what separates a
paste from a search that was abandoned.
Its output is `Print Page Generated`, and its completion is
`Print Dialog Opened`, the sheet reaching the printer. `Songbook Printed`
completes the set surface; `Second Print Page Generated`, `Songbook Created`,
and `Songbook Created From Offer` are the artefacts and subsets between them.

The search step has an output of its own: `Song Result Selected` is the match
the visitor chose. Together with `Song Search Missed` it separates the two ways
a search fails to become a sheet — finding nothing, and finding something that
was then abandoned — which `Song Search Submitted` alone could not tell apart.
Attempt-to-output conversion is read with a funnel, so no property has to carry
it: `run_funnel` over the Umami MCP endpoint, or the saved funnel in the Umami
dashboard, which is where the ordered questions live because this Plausible plan
has no funnel report.

## How an entry surface reports its events

The names reach a destination in five shapes. Two are declared in the view by
the server, so the event a control reports is visible beside the control that
fires it.

A form that reports its own submit carries `data-analytics-submit` with the
event name as its value. In `app/views/lyrics/new.html.erb` the search form, the
manual pasted-lyrics form, and each result's select form report
`Song Search Submitted`, `Manual Entry Submitted`, and `Song Result Selected`.
A form whose event only this site's own service is to receive carries
`data-analytics-umami-submit` instead, which the same listener reads: the
offer's **Not now** reports `Songbook Offer Dismissed` that way and reaches no
third party. That listener lives in `app/javascript/application.js`.

An outcome the server knows and the client cannot carries
`data-analytics-response` with the event name as its value, on the element the
response renders: the miss prompt in the search results panel reports
`Song Search Missed`. It is reported on `turbo:frame-load` rather than
`turbo:load`, because a Turbo frame load never fires `turbo:load`, and Turbo's
cached snapshot restoration does not fire `turbo:frame-load` either, so a panel
restored by the Back button cannot report it twice. The reporting function is
`trackResponseEvents` in `app/javascript/lib/analytics.js`.

An outcome the server renders into a whole page carries
`data-analytics-page-response`, read on the load that follows the response, and
`data-analytics-response-key` naming the response that carried it, so a snapshot
Turbo replays — same markup, same key — reports nothing: the songbook offer, by
`trackPageResponses` in that file. `data-analytics-offer-surface` names which of
the offer's two placements rendered it, `sheet` or `entry`, and it is required
rather than optional: the two report one event, so a strip that did not say
where it was shown would be a showing nothing can attribute. The entry panel's
offer arrives with a frame render as well as with a page, so both ends of a
response are read.

Page-level markers ride `<body>` data attributes and are reported on
`turbo:load`: `trackPageview`, `trackGeneratedPage`, and `trackCreatedSongbook`,
all in `app/javascript/application.js`. `data-visit-sheet-count`, which
`sessionPageCountProperties` reads, is the visit's own total rather than a report
of its own.

The fifth reports from the server, to Umami alone: a feedback submission that
passed the challenge and was saved is sent by `UmamiClient`
(`app/services/umami_client.rb`) after the row is written, as
`Feedback Submitted`. Nothing refused, unjudged, or unsaved is reported, and no
browser is involved, so this is the one name with no marker in a view. It is
also the one payload carrying a visitor's own words — see "What must never
travel".

## What must never travel

No tracker payload carries lyrics, song titles, artists, albums, source IDs,
share tokens, or the query a visitor searched with. Reported locations, titles,
and referrers pass through `analyticsUrl`, `analyticsTitle`, and
`analyticsReferrer` in `app/javascript/lib/analytics.js`, which replace a saved
page's path and title with their synthetic forms and leave external referrers
alone.

One payload is the deliberate exception, and it is the only one sent from the
server: a stored feedback submission. `Feedback Submitted` carries the song the
visitor wanted, the note they wrote, and the surface they wrote it on — which is
the demand list the runbook's reviews are chosen from — and it travels to
**Umami only**. Umami is this site's own service; Plausible is a third party
that receives every event the browser dispatcher sends, so this payload is never
routed through `dispatch` in `lib/analytics.js` and has no Plausible goal. The
reply address a visitor opts into is not part of it: it stays in the table for
the operator's replies.

Counts and sizes travel as buckets, not raw values: `page_count_in_session` and
`songbook_size` through `songbookSizeProperties` and
`sessionPageCountProperties` in that file. The visit's total is the server's
(`app/models/visit.rb`): one list of the sheets a browser session made, in every
tab, and the same window Umami expires a visit on. The offer's two events carry
that same bucket and nothing else. Campaign values are allowlisted by the
server in `AnalyticsCampaigns` (`app/models/analytics_campaigns.rb`).

## Adding a tool

1. Declare the attempt and output events before the tool ships, and put the
   markers beside the controls that fire them — or, when only the server can
   know the outcome, report it from the server and say so here.
2. Create the goals in Plausible, and confirm them in Umami's Events report.
   Umami needs no registration: a name it receives is a row it lists. An event
   carrying a visitor's own words is Umami's alone and gets no Plausible goal.
3. Save a funnel from attempt to output in Umami, named `<entry> to <outcome>`.
4. Keep a free-tier limit in application state. Never derive a limit from
   analytics: a blocked, sampled, or bot-polluted client must not change what a
   visitor can do.
5. If the tool adds a crawlable surface, place it inside the sitemap and
   noindex rules the runbook already sets.

Per-tool limits and any cross-tool linking need durable identity, which the
current product does not have. That decision belongs before the second tool
rather than after it.

## Where the rest lives

`docs/organic-search-operations.md` holds the operations, the readings, and the
production smoke test that verifies this contract by hand. `PRODUCT.md` holds
the design principles a new tool has to keep.

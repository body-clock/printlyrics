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
count traffic that never used the tool and cannot be filtered after collection.
`docs/organic-search-operations.md` carries the bot-filtering reason.

## The vocabulary

The naming rule is `<Product Noun> <Past-Tense Verb>`, in the product's own
words, and the dashboards keep the name verbatim. There is no mapping table:
the name the code sends is the name the dashboard lists.

One event per distinct thing worth counting. When a total and its subset both
matter, the subset is its own event: a count over a count stays readable in the
dashboard and as a funnel step, and Umami carries the underlying split as a
property as well. `Songbook Created` and `Songbook Created From Offer` are the
worked example: the subset over the total is the offer's conversion rate.

A saved funnel carries a name too, and it follows the same rule: the funnel that
reads a tool's attempt to its output is named `<entry> to <outcome>` in the
product's own words. The print tool's three are `Search to sheet`, `Paste to
sheet`, and `Sheet to printer`, and one more carries the selection step that the
other three cannot: `Search to printer` reads the same attempt through
`Song Result Selected` and `Print Page Generated` to `Print Dialog Opened`, so
the search's loss is read as two — a search that found nothing to pick, and a
result that was picked and never made.

The twenty names in use, grouped by the flow that fires them:

- Print flow: `Print Page Generated`, `Second Print Page Generated`, `Print
  Dialog Opened`, `Songbook Created`, `Songbook Created From Offer`, `Songbook
  Printed`, `Songbook Offer Shown`, `Songbook Offer Dismissed`.
- Entry flow: `Song Search Submitted`, `Song Search Missed`, `Song Result
  Selected`, `Manual Entry Submitted`, `Feedback Submitted`, `Feedback Prompt
  Shown`.
- Account flow: `Account Created`, `Account Signed In`, `Account Prompt Shown`,
  `Account Prompt Dismissed`, `Library Item Saved`, `Account Library Opened`.
  These answer whether optional accounts are used at all, which is the decision
  a paid tier waits on. `Account Created` and `Account Signed In` split the
  method with `account_method`; the prompt pair carries
  `account_prompt_surface`; `Library Item Saved` carries `saved_item_type` and
  `save_source`; `Account Library Opened` counts a signed-in return to the
  library.

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
dashboard.

## How an entry surface reports its events

The names reach Umami in five shapes. Two are declared in the view by the
server, so the event a control reports is visible beside the control that
fires it.

A form that reports its own submit carries `data-analytics-submit` with the
event name as its value. In `app/views/lyrics/new.html.erb` the search form, the
manual pasted-lyrics form, and each result's select form report
`Song Search Submitted`, `Manual Entry Submitted`, and `Song Result Selected`;
the offer's **Not now** reports `Songbook Offer Dismissed` the same way. That
listener lives in `app/javascript/application.js`.

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
Turbo replays — same markup, same key — reports nothing: the songbook offer and
the sheet's feedback prompt, by `trackPageResponses` in that file.
`data-analytics-offer-surface` names which of the offer's two placements rendered
it, `sheet` or `entry`, and it is required rather than optional: the two report
one event, so a strip that did not say where it was shown would be a showing
nothing can attribute. Only the offer has that split; the prompt renders in one
place, under the sheet the visit just generated, and its key is that sheet. The
entry panel's offer arrives with a frame render as well as with a page, so both
ends of a response are read.

Account outcomes use the same page-response marker, because the server is the
only side that knows a registration, a sign-in, a prompt answer, or a save
finished. `Account Created`, `Account Signed In`, `Library Item Saved`, and
`Account Prompt Dismissed` ride one-shot session keys rendered by the layout on
the page that follows, so a reload or a Turbo snapshot cannot report them twice.
`Account Library Opened` is rendered by the library page itself, and
`Account Prompt Shown` by the prompt, each with a fresh key per response. All
six carry `page_count_in_session`, and their properties travel in
`data-analytics-props`: `account_method`, `account_prompt_surface`,
`saved_item_type`, or `save_source` as applicable.

The page-response path reports to Umami alone, so account events are ordinary
Umami readings.

Page-level markers ride `<body>` data attributes and are reported on
`turbo:load`: `trackPageview`, `trackGeneratedPage`, and `trackCreatedSongbook`,
all in `app/javascript/application.js`. `data-visit-sheet-count`, which
`sessionPageCountProperties` reads, is the visit's own total rather than a report
of its own.

The fifth reports from the server: a feedback submission that passed the
challenge and was saved is sent by `UmamiClient`
(`app/services/umami_client.rb`) after the row is written, as
`Feedback Submitted`. Nothing refused, unjudged, or unsaved is reported, and no
browser is involved, so this is the one name with no marker in a view. It is
also the one payload carrying a visitor's own words — see "What must never
travel".

A submission reports the surface it was written on, and one written on a sheet
reports that sheet in the synthetic `:token` form rather than the page it was
written from. It also carries the single answer the form offers,
`feedback_reason`, drawn from a fixed vocabulary (`Feedback::REASONS`) rather
than from anything the visitor typed. Two placements lead to a submission, and
each is counted on its own terms: the miss prompt renders beside `Song Search
Missed`, so `Song Search Missed` against `Feedback Submitted` on the search-miss
surface is that prompt's conversion, while the sheet's prompt carries its own
name, `Feedback Prompt Shown`, in the response that renders it.

One entry surface reports nothing at all. A printed sheet carries a code
(`SheetMark`, rendered once by `app/views/shared/_sheet_mark.html.erb` and cloned
onto every page the preview builds) that sends a scan to the homepage rather
than to the sheet it was printed from, tagged with the `paper` campaign value.
The address on paper therefore holds no token: a sheet that is photographed,
handed on, or lost cannot be used to open the page it was printed from, and the
entry form is what a scan lands on. The visit a scan produces reports an ordinary
pageview and then whatever the visitor does next, so the paper channel is read
from Umami's native attribution of the landing URL's `utm_source=paper` rather
than as an event of its own: there is no name for a scan, and a scan that fires
no event is not visible.

## What must never travel

No tracker payload carries lyrics, song titles, artists, albums, source IDs,
share tokens, or the query a visitor searched with. Reported locations, titles,
and referrers pass through `analyticsUrl`, `analyticsTitle`, and
`analyticsReferrer` in `app/javascript/lib/analytics.js`, which replace a saved
page's path and title with their synthetic forms. Entry-page `songbook` and
`revision` query values are both redacted to `:token`, including same-origin
referrers. External referrers remain unchanged.

One payload is the deliberate exception, and it is the only one sent from the
server: a stored feedback submission. `Feedback Submitted` carries the song the
visitor wanted, the note they wrote, the surface they wrote it on, and the answer
they chose — which is the demand list the runbook's reviews are chosen from. It
is sent directly to Umami by `UmamiClient`, never through the browser
dispatcher, so it does not depend on the tracker. The reply address a visitor
opts into is not part of it: it stays in the table for the operator's replies.

Counts and sizes travel as buckets, not raw values: `page_count_in_session` and
`songbook_size` through `songbookSizeProperties` and
`sessionPageCountProperties` in that file. The account properties are fixed
vocabularies too — `account_method`, `account_prompt_surface`,
`saved_item_type`, and `save_source` — and never carry an address, a token, or
a page title. The visit's total is the server's
(`app/models/visit.rb`): one list of the sheets a browser session made, in every
tab, and the same window Umami expires a visit on. The offer's two events carry
that same bucket and nothing else. Campaign values are read by Umami from the
landing URL; the application does not copy them into event properties.

The miss panel's lookup link is the one place a query leaves the page, and it
leaves by the visitor's own click rather than by a tracker: the link carries the
query to a search engine in a new tab and bears no marker, so no payload gains
the URL. Giving it one — an outbound-link event, say — would put the query in
the analytics payload, which is what this section forbids.

## Adding a tool

1. Declare the attempt and output events before the tool ships, and put the
   markers beside the controls that fire them — or, when only the server can
   know the outcome, report it from the server and say so here.
2. Confirm the event in Umami's Events report. Umami needs no registration: a
   name it receives is a row it lists. An event carrying a visitor's own words
   stays on Umami and is read from **Event data** rather than from a saved goal.
3. Save a funnel from attempt to output in Umami, named `<entry> to <outcome>`,
   and, when the attempt has a step between the two that a drop could be hiding
   in, a second one that carries it to the completion — `Search to printer` is
   that shape.
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

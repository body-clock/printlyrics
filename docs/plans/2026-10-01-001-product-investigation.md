---
title: PrintLyrics Product Investigation - Run 1
type: research
date: 2026-10-01
topic: product-investigation
---

# PrintLyrics Product Investigation - Run 1

The first run of `docs/product-investigator.md` against PrintLyrics. It was run
without a product thesis supplied, and its main result is about the measurement,
not about the visitors.

## 1. Window and instruments

| Item | Value |
| --- | --- |
| System | Umami, self-hosted, through the read-only MCP endpoint |
| Website created | 2026-09-30T03:52:55Z |
| Data recorded | 2026-09-30T04:05:18Z to 2026-10-01T06:26:26Z |
| Span | **26 hours**, 2 calendar days |
| Read window | 2026-09-30T00:00Z to 2026-10-01T23:59Z |

The window assumed by the question was 60 to 90 days. The instrument holds 26
hours. Umami was created on 2026-09-30 and activated by v1.11.0 on the same day,
and Umami cannot ingest earlier data, so nothing before 2026-09-30 exists in this
system and nothing can be recovered into it.

This is the load-bearing fact of the run. Every claim below is a single-window
observation, and none of them can be a cohort or a trend. The pre-cutover
Plausible record is the only longer series, and it exists as a manual export in
the operations runbook, not as a queryable instrument.

Two further windows are shorter than the read window:

- `Song Search Submitted`, `Song Search Missed`, and `Manual Entry Submitted`
  first appear at 2026-09-30T19:00Z. The first 15 hours of the window have no
  entry-path events at all, because the entry instrumentation shipped during the
  window.
- The three saved funnels were created at 2026-09-30T20:19Z. Their step-one
  events cover roughly 11 hours. `Run_funnel` returns visitors over the whole
  read window, so the two entry funnels are measured over a period in which
  their first step did not exist for most of the time.

No Search Console export was available to this run, so the external-demand
channel is empty: no finding below compares search demand against observed
behaviour, which is the comparison the method was built for.

## 2. Readings

Declared vocabulary is nine names. Eight arrived. `Songbook Created From Offer`
never fired.

### 2.1 Events

| Event | Events | Visitors | Visits |
| --- | --- | --- | --- |
| `Print Page Generated` | 111 | 26 | 34 |
| `Print Dialog Opened` | 76 | 22 | 27 |
| `Song Search Submitted` | 53 | — | — |
| `Manual Entry Submitted` | 37 | — | — |
| `Songbook Printed` | 14 | 4 | 5 |
| `Second Print Page Generated` | 14 | 14 | 14 |
| `Songbook Created` | 12 | 4 | 7 |
| `Song Search Missed` | 6 | — | — |
| `Songbook Created From Offer` | 0 | 0 | 0 |

Totals for context, not evidence: 317 pageviews, 94 visitors, 105 visits, 52
bounces (49.5%), 3.02 views per visit, 141 s average visit duration. Custom
events in total: 323 across 33 visitors.

### 2.2 Funnels

| Funnel | Step 1 | Step 2 | Conversion |
| --- | --- | --- | --- |
| `Search to sheet` | 22 | 13 | 59.1% |
| `Paste to sheet` | 15 | 15 | 100% |
| `Sheet to printer` | 26 | 22 | 84.6% |

### 2.3 Properties

| Property | Value | Count | Carried by |
| --- | --- | --- | --- |
| `page_count_in_session` | `1` | 60 | `Print Page Generated`, `Print Dialog Opened` |
| | `2` | 22 | |
| | `3-5` | 44 | |
| | `6+` | 61 | |
| `entry_method` | `print_page` | 62 | `Print Dialog Opened` |
| | `songbook` | 14 | |
| `songbook_size` | `1` | 6 | `Songbook Created`, `Songbook Printed`, `Print Dialog Opened` |
| | `2` | 28 | |
| | `3-5` | 6 | |
| `songbook_origin` | `add_song` | 12 | `Songbook Created` |
| | `offer` | 0 | |

`page_count_in_session` counts payloads, not sessions, and rides on two events,
so its 187 records are not 187 sessions. The `6+` bucket is 61 payloads, or 33%
of records, which is a large share of a small window and is examined in F1.

### 2.4 Acquisition and landings

| Dimension | Reading |
| --- | --- |
| Channels (visitors) | `organicSearch` 55, `direct` 21, `referral` 21 |
| Referrers (visitors) | `bing.com` 35, `search.yahoo.com` 21, `google.com` 13, `duckduckgo.com` 7 |
| Entry pages (views) | `/` 89, `/lyrics/:token` 7, `/songbooks/:token` 2, `/print-lyrics-on-one-page` 1 |
| Paths (views) | `/` 90, `/lyrics/:token` 28, `/songbooks/:token` 5, `/print-lyrics-on-one-page` 1 |
| Devices (visitors) | `laptop` 69, `mobile` 21, `desktop` 4 |
| Countries (visitors) | US 57, GB 11, CA 10, IN 3, DE 3, MY 3, then 6 single-visitor countries |

`/print-a-songbook` does not appear in either the path or the entry ranking: it
drew no views.

## 3. Meta-findings

These bound everything in section 4 and are stated first.

### M1. The instrument is 26 hours old and the question assumed 60 to 90 days.

Covered in section 1. Consequence: no cohort, retention, or trend claim is
available from this system, and the run cannot be improved by querying
differently. A second run at 14 days, on the same instrument, is the smallest
thing that changes this.

### M2. The window contains at least two instrumentation boundaries.

The entry events and the saved funnels start mid-window (M1, section 1). The
first hours of `Print Page Generated` also precede them. Any cross-funnel or
cross-series comparison across the whole window compares periods with different
instrumentation, and the entry funnels' 59.1% and 100% are measured over a
window in which their step one existed for under half the time.

### M3. The visitor and pageview totals are not a clean population.

52 of 105 visits bounced. Of the 94 sessions, 61 recorded no custom event at
all, and the large majority of those are a single pageview, overwhelmingly
`edge-chromium` on `Windows 10` at common desktop resolutions. Umami filters
known bots by User-Agent only, by the operations runbook's own account, so this
population is expected to carry non-human traffic. The totals are also unstable
between reads: the visit count returns 105 from `get_website_stats`, 106 from
`get_session_stats`, and 94 from the sum of the daily traffic series. Nothing
below uses the 94-visitor or 317-pageview totals as evidence.

### M4. Duplicate-delivery signature in at least one session.

Session `0fbd3430` (GB, `edge-chromium`/`Windows 10` laptop, 34 views, 33
events, 2026-09-30T13:51Z to 14:13Z) contains three pairs of `/songbooks/:token`
pageviews separated by 0.80 s, 0.87 s, and 0.86 s, and fires `Songbook Created`
six times between 13:59:45Z and 14:13:33Z.

The measurement contract declares `Songbook Created` a one-shot-per-visit event,
and `Songbook Created` shows 12 events across 7 visit-occurrences. The obvious
rival explanations are duplicate delivery from the Turbo lifecycle, which the
runbook's own smoke test tells an operator to catch and fix before collecting a
baseline, and several distinct sets created in one sitting, which the path
redaction makes indistinguishable. **The available evidence cannot separate
them**, and the runbook's rule for this symptom is explicit: repair the
measurement before analysing it.

### M5. The two organic-search guides are not landing surfaces in this window.

`/print-lyrics-on-one-page` drew 1 entry and 1 view; `/print-a-songbook` drew
none. The recorded Search Console baseline to 2026-09-12 shows
`/print-lyrics-on-one-page` at 323 impressions and `/` at 973, so the guides are
impression-earning surfaces that are not, in this window, session-starting ones.
One day of data cannot tell whether that is a landing-page problem or a
crawl-to-click problem, and the Search Console channel was unavailable to this
run.

## 4. Findings

### F1. A small number of sessions produce most of the depth, so session depth is not yet a cohort.

**Observation.** `page_count_in_session` reports `6+` on 61 of 187 payloads
(33%), `3-5` on 44 (24%), `2` on 22, `1` on 60. `Print Page Generated` is 111
events from 26 visitors, 4.3 events per visitor. Individual sessions carry the
tail: `373dc6d6` (GB, mobile) produced 36 views and 41 events in 45 minutes,
`0fbd3430` produced 34 views and 33 events in 22 minutes, `fd423c1b` (CA)
produced 24 views and 26 events.

**Hypotheses.** (a) A real multi-document workflow exists and is common. (b) A
small number of actors, human or not, produce the depth. (c) The depth is
duplicate delivery (M4).

**Evidence.** E1 for the counts. The distribution is consistent with (b) and
(c) and does not require (a): the three busiest sessions hold 100 of the
window's 323 custom events, or 31% of the window from 3 of 94 sessions, and (c)
is independently supported by M4.

**Missing evidence.** Per-session distinct-document counts that survive the
redaction, and delivery integrity.

**Smallest experiment.** After M4 is resolved, read the same bucket over a
14-day window and split the top ten sessions by event count from the rest. If
the `6+` share is carried by fewer than ten sessions in two weeks, (a) is
unsupported and the tail is an actor artefact.

### F2. The songbook offer never converted; every set in the window was built through the add-song path.

**Observation.** `Songbook Created From Offer` did not fire once in 26 hours.
The `songbook_origin` property carries only `add_song`, 12 times, matching the
12 `Songbook Created` events exactly. Meanwhile `Second Print Page Generated`
fired 14 times, which is the moment the offer is presented.

**Hypotheses.** (a) The offer is shown and ignored. (b) The offer is not
reached, because the second sheet is produced in a way that does not surface it.
(c) The offer's origin is recorded wrongly, so it is being taken but reported as
`add_song`.

**Evidence.** E1. The event vocabulary confirms the subset event exists in code
(`songbook_origin === "offer"` in `app/javascript/lib/analytics.js`,
`remember_created_songbook(songbook, origin: "offer")` in
`app/controllers/songbooks_controller.rb`), so (c) requires a specific fault
rather than a missing feature. Against (c): the set-related events together
carry `songbook_size` values of `2`, `3-5`, and `1`, and 14 of the
`Print Dialog Opened` events carry `entry_method: "songbook"`, so the set
surfaces are reachable and used. The window is too small to choose between (a)
and (b).

**Missing evidence.** Whether the offer was rendered on the 14 second-sheet
moments. Nothing records an impression of the suggestion, by design: neither the
offer nor its dismissal sends an event.

**Smallest experiment.** Over a 14-day window, compare
`Second Print Page Generated` against `Songbook Created From Offer` and
`Songbook Created` with `songbook_origin`. If the offer stays at zero while
`add_song` creates continue, hypothesis (a) or (b) is confirmed and the code
path is worth reading; if it becomes non-zero, the window was the problem. The
falsifier for "the nudge does not work" is any window in which the offer
converts.

### F3. Multi-document work is expressed by returning to the homepage, not by the set surfaces.

**Observation.** `run_journey` over the window returns `/` alone as the single
most common journey, 49 visitors, and `/` alone again as the second, 10
visitors. The most common journey that completes anything is `/` →
`Song Search Submitted` → `Manual Entry Submitted` → `/lyrics/:token` →
`Print Page Generated` → `Print Dialog Opened`, 5 visitors, which contains both
entry paths in one session. Two further sequences are the return loop: `/` →
`/lyrics/:token` → `Print Page Generated` → `Print Dialog Opened` → `/` →
`/lyrics/:token` (2 visitors) and `/` → `Print Page Generated` →
`/lyrics/:token` → `Print Dialog Opened` → `/` → `Print Page Generated`
(1 visitor). The homepage is 89 of 105 entry views.

**Hypotheses.** (a) The homepage is the hub visitors return to between
documents, and the set surfaces are not part of that loop. (b) The loop is an
artefact of one or two sessions.

**Evidence.** E1. The loop appears in three of the returned journeys and in at
least one session in detail: `fd423c1b` repeats `/` with `?songbook=:token` →
`Manual Entry Submitted` → `/lyrics/:token` → `Print Page Generated` seven
times in twenty-three minutes, which is a single visitor building seven
documents. Against (b): the loop's members are few, and F1 shows the tail of
depth is actor-concentrated, so this evidence supports the existence of the
pattern and not its frequency.

**Missing evidence.** Whether the returning visitor passes through the songbook
surfaces at all, which the three saved funnels do not answer and the journey
report answers only for the sequences above.

**Smallest experiment.** Over 14 days, count sessions whose journey contains
two or more `Print Page Generated` events, and within those, count how many
contain a `/songbooks/:token` pageview. The falsifier for "the set surfaces are
not in the loop" is a majority of multi-sheet sessions containing a songbook
pageview.

### F4. The two entry funnels are not comparable, and `Paste to sheet` at 100% is a property of where its first step sits.

**Observation.** `Paste to sheet` is 15 to 15. `Search to sheet` is 22 to 13.
`Song Search Missed` is 6 against 53 `Song Search Submitted`.

**Hypotheses.** (a) Pasting is a better-served path than searching. (b) The two
funnels measure different things, because `Manual Entry Submitted` fires when a
visitor submits their own lyrics, which already contains the content the next
step needs, while `Song Search Submitted` fires before a lookup that can fail.

**Evidence.** E2 for (b) as a structural fact, E1 for the counts. The code
places `Manual Entry Submitted` on the submit of the form that creates the lyric
(`app/views/lyrics/new.html.erb`), and `Song Search Submitted` on the submit of
the search form, whose result set may be empty. The 100% is therefore near-tautological,
and the two rates do not describe the same kind of step. The `Search to sheet`
drop of 40.9% is consistent with search misses, but `Song Search Missed` is only
11% of searches, so the funnel drop is larger than the recorded misses.

**Missing evidence.** Whether the 9 dropped search visitors saw an empty result
set, an error, or left before choosing. `Song Search Missed` counts an outcome
the server knows; it does not count a search that succeeded and was abandoned.

**Smallest experiment.** No new event is needed. Over 14 days, compare
`Song Search Missed` against the `Search to sheet` drop. If misses stay near 10%
while the funnel drops near 40%, the leak is after a successful search, in
selection or generation, and the funnel's first step is fine.

### F5. Bing and Yahoo supply more arriving visitors than Google, in both systems.

**Observation.** Umami referrers over 26 hours: `bing.com` 35, `search.yahoo.com`
21, `google.com` 13, `duckduckgo.com` 7. The closing Plausible record to
2026-09-21 gives Bing 305, Direct 214, Yahoo 141, Google 109, DuckDuckGo 96.

**Hypotheses.** (a) The site's visibility is genuinely stronger on Bing. (b) One
of the two systems attributes referrers differently.

**Evidence.** E2. Two independent systems, six weeks apart, agree on the
ordering and the rough ratio. This is the only finding in the brief that is
corroborated across both systems and both windows.

**Missing evidence.** Nothing needed for the ordering. What is missing is
whether the Bing visitors behave differently, which needs a window long enough
to compare funnels per channel.

**Smallest experiment.** Over 30 days, run `Sheet to printer` with
`filters.referrer` set to `bing.com` and to `google.com`. The falsifier for
"Bing traffic converts at least as well" is Google converting better by more
than the funnel's noise band.

### F6. The device mix in analytics and the device mix in search clicks disagree.

**Observation.** Umami devices: laptop 69, mobile 21, desktop 4. The recorded
Search Console baseline to 2026-09-12: mobile 40 clicks at position 6.08,
desktop 23 clicks at position 26.71. The runbook already flags this as the thing
to check, because printing is a desktop task.

**Hypotheses.** (a) Mobile search traffic arrives and does not print, so it is
under-represented in the engaged population. (b) The two systems count devices
differently, or the windows are too far apart. (c) The laptop population
includes non-human traffic, which would inflate it.

**Evidence.** E1. (c) is supported by M3. (a) is consistent with the runbook's
existing concern and with the journey data, where mobile sessions do print, but
26 hours cannot show a mix.

**Missing evidence.** A device split of a product event over a window matched to
a Search Console export.

**Smallest experiment.** Read `get_website_metrics` with `type: "device"` and
`filters.event: "Print Dialog Opened"` at 30 days, beside a Search Console
export for the same window. The falsifier for (a) is mobile holding a share of
print completions comparable to its share of search clicks.

## 5. What the evidence cannot decide

- Whether any multi-document behaviour here belongs to a repeatable class of
  user or to a handful of sessions (F1, F3).
- Whether the songbook offer is ignored or unreached (F2).
- Whether the depth in the tail is behaviour or duplicate delivery (M4, F1).
- Whether the organic-search guides are failing to rank or failing to land (M5).
- Whether mobile search traffic prints at all (F6).

The Search Console channel was unavailable to this run, so no finding above
compares external demand with observed behaviour. That comparison is the one the
method was built for and it has not yet been made.

## 6. The single highest-value uncertainty

**The measurement's delivery integrity: whether the duplicated pageviews and the
repeated `Songbook Created` events in M4 are real behaviour or duplicate
payloads.**

It is first because it bounds F1 and F3, and because the runbook's own rule for
this symptom is to repair the measurement before drawing a baseline from it.
Every distribution in section 2 is suspect while it is open, and no amount of
extra window changes that.

The smallest experiment is not a new event. It is the production smoke test the
operations runbook already specifies, run deliberately against the Turbo
lifecycle: generate a second sheet, create a set, add a song, and then navigate
back to each surface with the Back button and with a reload, asserting that
`Songbook Created`, `Print Page Generated`, and `Second Print Page Generated`
each keep their one-shot behaviour and that a single navigation sends exactly
one pageview. `Songbook Created` currently has no client-side dedupe, unlike
`Print Page Generated`, which uses session storage
(`app/javascript/lib/session_pages.js`); a snapshot restored from Turbo's cache
carries the `<body>` marker that fires it.

The falsifier for "this is duplicate delivery" is a session in which the same
reported path carries distinct documents and the one-shot events fire once each.
The falsifier for "this is real behaviour" is a single navigation that emits two
pageviews or a reload that re-emits `Songbook Created`.

# Product Investigator

A protocol for interrogating one product's analytics instruments and returning an
evidence-graded Opportunity Brief: what the behaviour is, what competing
explanations survive, what would distinguish them, and what the cheapest next
measurement is. It is not a dashboard, and it does not recommend features.

It exists because the two easy failure modes of model-assisted analysis are
opposite and both common. The first is confirmation bias: a model handed a
product thesis will find the thesis in any dataset. The second is over-reading:
a model handed a small, contaminated dataset will narrate cohorts and trends
that are one crawler and two duplicate payloads. This protocol is the set of
constraints that prevents both.

The output is a brief an operator can act on, and its most valuable sentences
are usually the ones that say what the evidence cannot decide.

## 1. The evidence model

Analytics is one channel among several, and it is the weakest of them for
deciding direction. It is a detector of where a shipped flow leaks; it is never
a generator of what to build. Read the brief with that ordering in mind.

### 1.1 The channels

| Channel | Where it lives | What it answers | What it cannot answer |
| --- | --- | --- | --- |
| Behaviour | Umami, through the read-only MCP endpoint | What visitors did to the shipped flow, step by step | Why; who they were; anything about a session that did not use JS |
| Private intent | The feedback table, read on the production host | What a visitor asked for and could not get | Whether that visitor is representative |
| External demand | Search Console export, supplied as a file | What the query space wants before it arrives | What those visitors did after arriving |
| Product change | `CHANGELOG.md`, `version.txt`, git history | When the product changed, which explains step changes in behaviour | Whether a change caused a change in behaviour |
| Inferred intent | Search results, competitor review pages, forum threads | Candidate jobs and vocabulary | Whether any of it describes this product's actual visitors |

The last row is a hypothesis generator. It MUST NOT be presented as evidence
about this product's visitors, and it MUST NOT be mixed into a finding's
evidence line. Web research and behavioural analytics describe different
populations; agreement between them is a coincidence to be tested, not a
confirmation.

### 1.2 Product changes are part of the evidence model

A step change in an event series has two families of explanation: the visitors
changed, or the instrument changed. The second is at least as common and is
cheap to check. Before any trend is read, the investigator aligns the window
against releases and asks, for every series that moves, whether a release moved
it.

Three instrument changes are invisible in the analytics and must be supplied by
the operator or the repository:

- an event that did not exist yet, so its series starts at a release;
- a funnel that was saved on a later date than its steps first fired;
- a destination cutover, where the two systems define a visit and a visitor
  differently and their totals are not comparable.

### 1.3 Units and windows

Every figure carries three qualifiers, and a figure without them is not
evidence: the system it came from, the window it covers, and the unit it
counts. Two systems that disagree are not evidence of a bug; they are evidence
that the comparison was wrong.

The smallest defensible window for a cohort or trend claim is **14 days**, and
that is a floor, not a threshold. At populations below roughly a hundred events a
week, differences below an order of magnitude are noise. Below 14 days the
investigator reports the window as a limitation and downgrades every
distribution claim to a single-window observation.

## 2. Operating rules

### 2.1 Evidence levels

Every claim in the brief carries one of these, and the level is decided by the
evidence, not by the confidence of the prose.

- **E0 — Unsupported.** A hypothesis, a projection, or external-research
  vocabulary. Never presented as a finding.
- **E1 — Observed once.** One window, one system, contamination not excluded.
  A single-window distribution, or a series that could be one actor.
- **E2 — Corroborated.** Two independent reads agree: two different tools over
  the same window, or two windows over the same flow, or two systems with
  stated and compatible unit differences. Contamination bounded and argued.
- **E3 — Replicated with mechanism.** Reproduced across windows or systems with
  a named mechanism connecting the cause to the effect, and the mechanism
  checked against the code.

### 2.2 The population rule

The visitor and pageview totals include traffic that never used the product: a
tracker that runs is counted, and only a User-Agent check stands in front of it.
The population is therefore the event, never the visitor total. Read an event's
own visitors and events counts, or a funnel whose first step is a product event.
When a finding depends on the visitor total, say so and downgrade it.

### 2.3 The competing-explanation rule

Every observation gets its strongest rival explanation written down, and the
brief states whether the available evidence eliminates it. Noisy, duplicated,
or bot-contaminated delivery and a genuine behavioural cohort produce very
similar counts; they are distinguished by looking at the individual sessions,
not the aggregate.

### 2.4 The redaction rule

Saved surfaces report a synthetic path. Distinct documents therefore collapse
into one reported name, and an event list cannot distinguish "many documents"
from "the same document many times". Where a finding depends on that
distinction, the investigator says so and proposes a measurement that does not
depend on reading a token — a count, a bucket, or a per-session depth — rather
than proposing to record the token, which is prohibited.

### 2.5 The right to say "we don't know"

A brief that ends without an unresolved question has either found nothing or
invented something. State the largest uncertainty explicitly, name the two
competing explanations, and name the smallest measurement that separates them.
Do not resolve an ambiguity with plausible prose.

## 3. The finding format

Every finding is one of these blocks. Nothing is a finding without all five
lines.

```
### F<n>. <one-line claim, stated as a measurement>

**Observation** — what was read, with system, window, unit, and exact counts.
**Hypotheses** — the competing explanations, including the boring ones
  (instrumentation change, duplicate delivery, one heavy actor, bot traffic).
**Evidence** — which reads support or eliminate each hypothesis, at what level.
**Missing evidence** — what is not recorded that would separate the survivors.
**Smallest experiment** — the cheapest change or query that moves the level up,
  and what result would falsify the leading hypothesis.
```

An experiment that cannot fail is not an experiment. If the investigator cannot
say what observation would kill the leading hypothesis, the finding is E0 and
does not ship.

## 4. The query plan

Run in this order. Each step can end the investigation.

1. `list_websites` — resolve the website ID.
2. `get_website_daterange` — the honest window. Compare it against the window
   the question assumes and report the difference before doing anything else.
3. `get_website_metrics` with `type: "event"` — the event population. Compare
   the names against the declared vocabulary. A name that is not declared is
   instrumentation drift; a declared name that is absent is a flow that never
   completed.
4. `get_event_stats`, once unfiltered and once per event in `filters.event` —
   events, visitors, and visits for each name. This is the population the rest
   of the brief must use.
5. `get_website_stats` — totals, for context only. Never a finding's evidence.
6. `list_funnels`, then `run_funnel` for each — the ordered questions. Check
   each funnel's created date against the window.
7. `get_event_properties`, then once per property name — the bucket
   distributions. Record which events carry each property; a property that
   never arrived is absent, not zero.
8. `get_website_metrics` for `entry`, `path`, `referrer`, `channel`, `device`,
   `country`, and any `utm*` dimension — acquisition against behaviour.
9. `get_sessions`, then `get_session` for the sessions with the highest event
   counts — the individual actors. Aggregate shapes are decided here.
10. `get_annotations` — dated operator notes. Currently the release timeline
    comes from `CHANGELOG.md` instead.
11. `run_journey` — the loops visitors actually follow, which is where a
    repeated workflow shows up before any cohort report can find it.
12. `run_retention` — only at 14 days or more.

### 4.1 PrintLyrics instance

The vocabulary, the funnels, and the properties for this deployment live in
`docs/measurement-contract.md` and `docs/organic-search-operations.md`. The
load-bearing constraints for the query plan:

- The nine event names are `Print Page Generated`,
  `Second Print Page Generated`, `Print Dialog Opened`, `Songbook Created`,
  `Songbook Created From Offer`, `Songbook Printed`, `Song Search Submitted`,
  `Song Search Missed`, and `Manual Entry Submitted`. There are no others; a
  tenth name is drift.
- `Second Print Page Generated` is not a funnel step. It fires before the second
  print dialog, so it is read as a standalone packet-intent signal.
- The three saved funnels are `Search to sheet`, `Paste to sheet`, and
  `Sheet to printer`, each with a 60-minute window.
- The properties are `entry_method`, `songbook_size`, `songbook_origin`,
  `campaign_source`, `campaign_name`, `page_count_in_session`, and
  `songbook_offer_surface`, and each rides only on the events that set it.
- Saved pages report `/lyrics/:token` and `/songbooks/:token`, so document
  identity is not recoverable from a reported path.

## 5. The output contract

The deliverable is an Opportunity Brief with these sections, in this order:

1. **Window and instruments** — what was actually readable, from which system,
   and the differences from what the question assumed.
2. **Readings** — the event population as counts, with the unit named. No
   interpretation.
3. **Meta-findings** — anything wrong or limited about the measurement itself,
   stated before the findings, because it bounds them.
4. **Findings** — the blocks from section 3, ordered by how much they would
   change a decision, each with its evidence level.
5. **What the evidence cannot decide** — the surviving ambiguities.
6. **The single highest-value uncertainty** — one, not a list, with its smallest
   experiment and its falsification condition.

The brief MUST NOT: recommend a feature; propose an instrumentation change
unless a finding names the specific reading it would unblock; cite external
research as evidence about this product's visitors; or state a distribution
without its window and unit.

## 6. The prompt

Supply this verbatim, with the repository and the Umami MCP endpoint available
and the Search Console export attached if there is one.

```text
You are the Product Investigator for one product. You have read access to the
product's repository, its analytics through a read-only MCP endpoint, and — if
one is attached — a Search Console export. You produce an Opportunity Brief.
You do not write product code, you do not recommend features, and you do not
invent personas.

Method.

1. Read the product's measurement contract and its analytics runbook in the
   repository before querying anything. The event vocabulary, the saved
   funnels, and the properties are defined there, and you must use those names
   exactly.

2. Call list_websites, then get_website_daterange. Report the honest window
   first. If it is shorter than the window the question implies, say so before
   any other analysis, and treat every distribution and trend claim as a
   single-window observation.

3. Run the query plan in docs/product-investigator.md section 4, in order.

4. Do not start from a product thesis. Derive from the readings. If you catch
   yourself looking for a cohort you expected, stop and enumerate what the data
   contains instead.

5. Before reading any trend, align the window against the product's release
   history. For every series that changes, state whether a release, a new
   event, a saved funnel's creation date, or a destination cutover explains it.

6. For every observation, write the strongest rival explanation — including
   instrumentation change, duplicate delivery, a single heavy actor, and
   non-human traffic — and say whether the available evidence eliminates it.
   The visitor and pageview totals include traffic that never used the product;
   the population is the event, never the visitor total.

7. Where a reported path is redacted to a synthetic form, you cannot tell many
   documents from one document repeated. Say so, and propose a measurement that
   does not depend on reading the redacted value.

8. Assign every claim an evidence level: E0 unsupported, E1 observed once,
   E2 corroborated across two independent reads, E3 replicated across windows
   or systems with a checked mechanism. Never write a finding without all five
   lines of the format in section 3, and never present E0 as a finding.

9. Diagnose individual sessions, not only aggregates, for any finding that
   depends on a small number of actors or on a distribution. Read the sessions
   with the highest event counts before you characterise a cohort.

10. End with exactly one highest-value uncertainty, the smallest experiment
    that would resolve it, and the observation that would falsify your leading
    hypothesis. If nothing would falsify it, it is not a finding.

Output the Opportunity Brief in the section 5 format. Use plain prose and
tables. Name the system, window, and unit beside every figure. State clearly
what you do not know. Do not pad the brief; a short brief with three real
findings is better than a long one with none.
```

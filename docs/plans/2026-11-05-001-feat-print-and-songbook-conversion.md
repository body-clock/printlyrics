---
title: Print and Set Conversion - Plan
type: feat
date: 2026-11-05
topic: print-and-songbook-conversion
---

# Print and Set Conversion - Plan

## Goal Capsule

- **Objective:** Raise two rates that the 2026-11-05 reading puts below their traffic: a
  generated sheet reaching the print dialog (`Sheet to printer`, 833 → 503), and a visit
  that holds several sheets turning them into one set (`Set to printer`, 132 → 86).
- **Evidence:** [the reading](#the-reading) below, taken through the Umami MCP endpoint
  over 2026-10-06 → 2026-11-05.
- **Authority:** this plan owns print and set conversion only. It changes no lyric entry
  path and adds no public surface. `docs/measurement-contract.md` still owns the events.
- **Ordering:** U1 first, because every later unit is judged against the funnel it fixes.
- **Targets:** `Sheet to printer` 60.4% → 68%; `Set to printer` 65% → 75%; one-sheet
  print rate 53% → 62%.

---

## The reading

30 days, 2026-10-06 → 2026-11-05. 3,391 visitors · 3,928 visits · 11,240 pageviews ·
bounce 37.3% · 183 s · 2.86 views per visit.

| Funnel | Steps | Read |
| --- | --- | --- |
| Search to printer | 1,840 → 852 → 622 → 469 | 54% never pick a result |
| Search to miss | 1,840 → 353 | 19.2% hit the empty prompt |
| **Sheet to printer** | **833 → 503** | **39.6% generate and never print** |
| **Set to printer** | **132 → 86** | **35% of sets never printed** |
| Offer to printed set | 270 → 47 → 21 | offer converts, 17% |
| Account to saved item | 409 → 18 → 6 | separate track |

Sheets generated per session, and what each band did:

| Sheets | Sessions | Opened a dialog | Made a set |
| --- | --- | --- | --- |
| 1 | 451 | 53% | 1% |
| 2 | 134 | 70% | 20% |
| 3–4 | 112 | 82% | 31% |
| 5–9 | 73 | 82% | 41% |
| 10+ | 63 | 89% | 59% |

Three facts drive every unit below.

1. **213 one-sheet sessions printed nothing.** In a 45-session sample of them, 18 did
   nothing at all after the sheet rendered: 8 fired no further event, 10 fired only the
   render markers (`Feedback Prompt Shown`, `Account Prompt Shown`). The sheet arrives and
   the visit ends.
2. **69 sessions generated 5 or more sheets and never created a set.** They hand-built
   what a songbook is. `Second Print Page Generated` fired 407 times across 334 sessions,
   and only 132 sessions ever created a set.
3. **A dismissed offer is dead for the visit.** `Visit#answer_offer!` settles
   `offer_answered` for the whole 30-minute visit, so a visitor who dismisses at two sheets
   is never offered again at ten. 66 dismissals, 58 of them on a visit that never created
   a set.

---

## Implementation Units

### U1. Report the print the browser actually performs

- **Goal:** Make `Sheet to printer` measure printing rather than one button.
- **Evidence:** `Print Dialog Opened` fires only inside `preview#print`
  (`app/javascript/controllers/preview_controller.js:105`). A visitor who prints with
  ⌘P, the browser menu, or a share-sheet print never reports it, so an unknown part of the
  213 is printing without a marker. Nothing can recover that split after the fact, which
  is why this comes first.
- **Files:** `app/javascript/controllers/preview_controller.js`,
  `app/javascript/lib/analytics.js`, `app/views/lyrics/show.html.erb`,
  `app/views/songbooks/show.html.erb`, `docs/measurement-contract.md`,
  `test/system/organic_conversion_test.rb`.
- **Approach:** Move the report to the window's `beforeprint` event and keep the button as
  a trigger. Report once per print: the app's own `window.print()` also raises
  `beforeprint`, so one guard per print attempt deduplicates the pair. `Songbook Printed`
  stays where it is, on the set's own print path. The contract's wording changes from
  "the print action" to "the browser's print dialog", in the same commit.
- **Acceptance:** ⌘P and the button each produce exactly one `Print Dialog Opened`; a
  single click still produces one. `entry_method` and the sheet-count properties still
  ride. A browser with no `beforeprint` falls back to the button.
- **Effort:** 2 h.

### U2. Put a print action where the sheet ends

- **Goal:** Give the one-sheet cohort a print action at the point the eye lands, not only
  in the fixed bar.
- **Evidence:** 213 one-sheet sessions printed nothing, and half the sampled ones stopped
  dead on the sheet. The only print control is in a fixed header that is 7 rem tall on
  mobile (`app/assets/tailwind/application.css`, `.control-inner`), so on a 700 px screen
  the first screenful is mostly bar.
- **Files:** `app/views/lyrics/show.html.erb`,
  `app/views/songbooks/show.html.erb`, `app/assets/tailwind/application.css`,
  `config/locales/en.yml`, `test/integration/lyrics_flow_test.rb`.
- **Approach:** Repeat the existing `preview#print` action as a primary button immediately
  under the paper on a generated sheet, and again under a set. It is the same handler, so
  it reports nothing new and needs no contract change. Keep it `no-print`.
- **Acceptance:** Both controls work and report identically; the second one appears where
  the visit generated the page, so a shared sheet keeps the one control in its bar. The
  printed sheet is unchanged.
- **Reads:** `Sheet to printer`, split by device.
- **Effort:** 1 h.

### U3. Re-arm the offer when the visit grows past its answer

- **Goal:** Stop one dismissal at two sheets from silencing the offer at ten.
- **Evidence:** `Visit#answer_offer!` writes `offer_answered: true` for the visit;
  `offer_pending?` clears it only when the visit lapses. 66 dismissals, and 58 of those
  visits created no set.
- **Files:** `app/models/visit.rb`, `app/controllers/songbook_offers_controller.rb`,
  `app/views/shared/_songbook_prompt.html.erb`, `test/models/visit_test.rb`,
  `test/integration/songbooks_flow_test.rb`.
- **Approach:** Record the sheet count at the answer instead of a boolean, and treat the
  offer as pending again once the visit holds three more sheets. A dismissal still settles
  the offer for the sheets it was shown against, and one answer still ends the visit's
  offer when the count does not move again.
- **Acceptance:** Dismiss at 2 → no offer at 2, 3, 4 → offered again at 5. Accepting still
  creates the set once and settles the visit. `Songbook Offer Dismissed` stays one per
  visitor per answer.
- **Reads:** `Offer to printed set`.
- **Effort:** 1.5 h.

### U4. Show the visit the sheets it is accumulating

- **Goal:** Give the 69 sessions that never made a set a visible path from their own sheets
  to one job.
- **Evidence:** Nothing in the product lists a visit's sheets. The offer is the only
  surface that mentions more than one, it is dismissible, and `10+` sessions still reach
  41% with no set. Meanwhile the builder loop is visible in the data: the homepage carries
  `?songbook=:token` on 169 views, and the busiest sessions repeat it every eight seconds.
- **Files:** `app/models/visit.rb`, `app/views/lyrics/show.html.erb`,
  `app/views/lyrics/new.html.erb`, `app/controllers/lyrics_controller.rb`,
  `config/locales/en.yml`, `test/integration/lyrics_flow_test.rb`.
- **Approach:** From the third sheet on, render a compact strip naming the count and one
  primary action ("Print these 4 as one job"), reusing `songbooks_path` with the visit's
  tokens. It sits under the paper on the sheet and inside the entry panel. It is not the
  offer: it does not dismiss, it does not re-fire `Songbook Offer Shown`, and it renders
  whether or not the offer was answered.
- **Acceptance:** A visit with 3+ sheets sees the strip on both surfaces; a visit with 1–2
  does not; pressing it creates the set with `songbook_origin` unchanged and reports no
  new event name.
- **Reads:** `Set to printer`, and `Songbook Created` against sessions with 5+ sheets.
- **Effort:** 4 h.

### U5. Compress the sheet header on mobile

- **Goal:** Put the lyrics inside the first screenful.
- **Evidence:** `.control-inner` is `min-height: 7rem` in the mobile block while the bar is
  `position: fixed`, and the songbook prompt renders above the paper
  (`app/views/lyrics/show.html.erb:69`), so a phone shows header plus prompt before any
  lyrics. Mobile prints at 58% on one sheet against 52% on laptop, so the loss is not
  device-specific, but the first screenful is.
- **Files:** `app/assets/tailwind/application.css`, `app/views/lyrics/show.html.erb`.
- **Approach:** Move the songbook prompt below the paper on the sheet surface and reduce
  the mobile bar to a single row with the print action visible. No markup moves that a
  test asserts on, beyond the prompt's position.
- **Acceptance:** On a 390 × 844 viewport the first lyric line is visible without scrolling;
  every control still has a 44 px touch target; the printed output is unchanged.
- **Reads:** `Sheet to printer` on mobile.
- **Effort:** 1 h.

### U6. Record the reading and hold the targets

- **Goal:** Make the next reading comparable and stop the targets drifting.
- **Files:** `docs/organic-search-operations.md`.
- **Approach:** Add `Third Umami reading, 2026-11-05` with the figures in [the
  reading](#the-reading), the window, and the targets this plan sets. Annotate each later
  reading against it.
- **Acceptance:** The section states the window and each figure's funnel; every unit above
  names the funnel that judges it.
- **Effort:** 1 h.

---

## Risks

- **`beforeprint` may double-report.** The guard is per print attempt, not per event; a
  test that stubs both paths covers it.
- **A re-armed offer can nag.** The three-sheet watermark bounds it; a visit that adds
  nothing is offered nothing.
- **The strip can compete with the offer.** Both can render on one sheet; the strip is
  passive and the offer stays the only one that asks a question. If `Offer to printed set`
  falls while `Set to printer` rises, the strip is the cause and the offer should move
  below it.
- **Traffic is growing fast enough to read as improvement.** Every comparison states the
  window, and each rate is read against the band it belongs to, not against the total.

## Out of scope

- The 54% of searchers who never pick a result. That is the search surface, and larger.
- Account and library conversion, which the same reading puts at 18 of 409.
- Any new event name. Nothing here needs one; U1 changes when an existing event fires and
  edits the contract to match.

---
sourcesHash: 6ef1b1e925c2287078b8e035abfe468edb7362a0171a6268fe45bb2d21a2d0ba
id: lyric-entry
description: >-
  Find or paste lyrics, review a recoverable draft, and create an independent
  print sheet or immutable revision without requiring an account.
status: discoverable
sources:
  - app/views/lyrics/new.html.erb
  - app/javascript/controllers/lyric_search_controller.js
  - app/javascript/controllers/lyric_entry_controller.js
  - app/views/lyrics/_entry_context.html.erb
  - app/controllers/lyrics_controller.rb
tests:
  - test/system/organic_conversion_test.rb
  - test/system/workspace_interaction_test.rb
  - test/integration/lyrics_flow_test.rb
---

# Lyric entry

## When to use

- The homepage, signed in or out, with or without a songbook token.
- The visitor arrives with a song title or copied lyrics.
- A generated sheet needs revised words without mutating its shared link.

## When not to use

- Updating an existing generated sheet in place. Revisions create independent
  outputs; they do not replace library membership or songbook entries.
- The preview or the library.
- A bulk import of many songs. The pattern creates one sheet per submission; a
  songbook is assembled from generated sheets, not entered here.

## Structure

Required regions, in order:

1. **Intro** — one compact `h1` and explanatory paragraph.
2. **Entry modes** — `.entry-modes` tablist, Find/Paste tabs and associated
   panels. Find contains labelled search and normal-flow results.
3. **Review words** — Paste panel contains words-first textarea, associated
   feedback, optional title/artist below, and Preview sheet with Cancel.
4. **Recovery status** — announces tab-scoped draft recovery or unavailable
   storage honestly. A revision note explains independent-output semantics.

Optional regions:

- **Songbook context** — when the visitor is adding to an existing set, one line
  names the count and links to the set.
- **Results panel** — a header with status/error and close, a list of matching
  songs, and a miss panel. Each match is a submit that loads the lyrics into the
  form.
- **Miss panel** — explains that the source had nothing, offers an external
  lookup and an anchor to the manual textarea, and offers a feedback form.
- **Songbook offer** — the inline offer for a visit holding more than one sheet.

The explainer and FAQ follow the entry panel and are part of the page, not the
task.

## Composition

- Both modes remain reachable during search, no matches and provider failure.
  Only the active panel is visible; switching never clears either input.
- Results stay inside `lyric_entry` in normal document flow at every width.
  They never overlay the editor or require horizontal body scrolling.
- Selecting a result fills the form; it does not create a record. A record is
  created only when the visitor generates the page.
- The miss panel's external lookup opens in a new tab and carries no analytics
  marker, so the query does not reach the destination's URL through this
  application's tracking.
- The manual submit is the one primary action on the page. Search and the miss
  actions are secondary.
- Miss feedback is a separate form outside the review form; never nest forms.
- A songbook token travels in hidden fields on search, result selection, and
  manual submission. Do not drop it when composing a new submit.
- Drafts use tab-scoped session storage, separated by new/revision/songbook
  context. Reload/navigation recover words and metadata; closing the tab ends
  storage lifetime. Storage failure leaves editing usable and says recovery is
  unavailable. No lyric text or token enters analytics.
- Server search/select/validation responses preserve the current draft unless
  the visitor deliberately accepts replacing it with a selected result.
- Edit lyrics copies an active sheet into a draft. Preview creates a new link;
  the old sheet, library membership and book entry remain unchanged. Cancel
  returns to the source sheet/book and clears only that draft after confirmation.
- Modified drafts warn on departure. Successful Preview is not an abandoned edit.
- Tabs use Left/Right, Home/End and roving tabindex. Escape closes results and
  restores search focus; a visible Paste action remains available after errors.
- The results-close control is pattern-private, not a general icon-button API.
  It requires an accessible name and the shared 44px target.

## Verification

Static:

- Both forms are present in the response, and neither is inside the other.
- Every input has a label; the search label may be `sr-only`.
- The page has one `h1` and ordered section headings.

Behavioural:

- A search with results lists them and selecting one fills the manual form
  without creating a lyric.
- A no-results or failed search retains both modes' input.
- Preview creates a sheet; revision preview leaves the original and memberships
  unchanged.
- Keyboard tab switching preserves input; reload recovers only the current
  context. Cancelling or declining replacement never silently discards words.

Commands:

```sh
bin/rails test test/integration/lyrics_flow_test.rb
bin/rails test test/system/organic_conversion_test.rb
```

Intentional violations: clearing pasted words on a failed search, replacing a
shared sheet in place, or nested forms must be rejected.

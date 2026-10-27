---
sourcesHash: 1ecac465f747ad65ca2fba91b09b75769feb38da6b36364d5db3867d391857a9
id: print-preview
description: >-
  Let a visitor review a generated sheet or songbook, adjust lyric size and
  columns for a sheet or for each song in a set, print or save it as PDF, and
  optionally gather sheets into a songbook.
status: discoverable
sources:
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_preview_controls.html.erb
  - app/javascript/controllers/preview_controller.js
  - app/javascript/controllers/layout_preference_controller.js
  - app/javascript/controllers/workspace_controller.js
  - app/views/shared/_preview_view_controls.html.erb
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
  - test/system/workspace_interaction_test.rb
---

# Print preview

## When to use

- A generated lyric page or an existing songbook.
- The visitor needs to compare the screen preview with what will print and
  adjust the two supported display dimensions.

## When not to use

- The entry form or editing. Use the lyric-entry pattern.
- A print-only job with no screen review. The preview is the review surface.
- A PDF export service. The browser's print dialog is the export path.

## Structure

Required regions:

1. **Action band** — Edit sheet for a sheet or Add another song for a book,
   responsive Format trigger named for its target and primary Print.
2. **Document stage** — measured count, Fit inspection scale (explicit zoom on
   wide screens), browser Save as PDF guidance, and one or more physical paper
   sheets.
3. **Inspector** — responsive single-sheet settings, or a named current-song
   group and a collapsed whole-book `All songs` disclosure.
4. **Failure feedback** — visible retryable layout-save error when needed.

Optional regions:

- Song outline on a book, disclosure on compact screens and persistent where
  three usable columns fit. It navigates, never formats.
- Secondary new-sheet/book, library/account and feedback actions below paper.
- Flash for server outcomes.

Every region except the paper is `no-print`.

## Composition

- A single sheet has one pair of size/column fieldsets in the inspector. A book
  has one named current-song pair and one whole-book pair inside a collapsed
  `All songs` disclosure. Both use segmented-control; the outline contains no
  formatting controls.
- The print action is the bar's only filled action. Do not add "Save PDF" beside
  it; the print dialog provides it.
- Size and column changes apply immediately and repaginate through the preview
  controller. They do not navigate or submit a form. On a songbook the choice is
  saved to the entry in the background; a bulk choice is saved to every entry.
  A bulk control changes only its own dimension, so a set that deliberately
  mixes columns keeps that mix when its size changes.
- Each song reconciles its own size and column count, so one song may print large
  in one column while another prints small in two. A song that outgrows one sheet
  continues onto bare pages in the same format.
- Outline links navigate to the first sheet. The song crossing the viewport
  midpoint owns current formatting; scrolling/repagination updates the target,
  pressed options, Reading text and `aria-current`.
- Mixed whole-book values leave options unselected and display Mixed text.
- The mobile inspector is a compact nonmodal bottom panel; Close/Escape restore
  the invoking control. Desktop settings are inline beside the paper.
- Fit changes inspection on every width. Explicit zoom exists only at 1100px
  and wider, scrolls inside the stage, never the body, and never changes print
  type size.
- Failed saves remain visible and retryable. Pending changes are tracked per
  entry and dimension; a newer success must not conceal an older failed update.
- Starting a songbook from a sheet carries that sheet's current size and column
  count into its first entry. A new song added later inherits the layout of the
  last song in the set.
- Removing a song reloads and remeasures the remaining ordered book.
- Offers appear after the paper; their server conditions decide visibility.
- The page summary is updated by the controller after measurement; it is not a
  static string.
- Edit sheet (a sheet) or Edit this song (in a book's current-song group)
  creates an independent revision, including title and artist. The original
  shared sheet and its library/book membership never change; the editor explains
  this before preview.

## Verification

Static:

- All workspace chrome is no-print and the paper remains white in dark mode.
- Inspector settings identify their target; the Format trigger names the sheet
  or the song in view; whole-book Mixed is visible when the disclosure is open.
- Every song source has its persisted size/columns and first-page anchor.

Behavioural:

- All four sizes and both layouts repaginate without losing words/stanza order.
- Per-song changes leave other entries unchanged; bulk size preserves mixed
  column choices. Reload restores persisted settings.
- Outline selection reaches first page; scrolling/repagination retain a correct
  current target. Removal keeps counts and order coherent.
- Failed persistence exposes Retry saving and retains all unsaved dimensions.
- Mobile Format, Close and Escape handle focus correctly at 320px.
- Zoom changes screen scale but PDF geometry, text size and page order match the
  fitted preview. No outline, inspector, status or action reaches paper.
- Revision preview preserves words/formatting while leaving original membership
  unchanged.

Commands:

```sh
bin/rails test test/system/organic_conversion_test.rb
bin/rails test test:system
```

An intentional violation: a second filled action in the control bar, or screen
chrome appearing in the printed result, must be rejected.

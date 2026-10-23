---
sourcesHash: 9ff3b2bc39fd210595013f11d4d357091a60964964741d2025c1b299d0009d49
id: print-preview
description: >-
  Let a visitor review a generated sheet or songbook, adjust lyric size and
  columns, print or save it as PDF, and optionally gather sheets into a songbook.
status: discoverable
sources:
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_preview_controls.html.erb
  - app/javascript/controllers/preview_controller.js
tests:
  - test/system/organic_conversion_test.rb
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

1. **Control bar** — back link, size control, columns control, print action.
   On a sheet it also offers "Add another song"; on a songbook the back link is
   the add action.
2. **Page summary** — paper size, margins, and page count, updated after
   pagination.
3. **Paper** — one or more sheets from the paper-sheet contract.
4. **Flash** — if the server has an outcome for this page.

Optional regions:

- **Songbook offer** — when the visit has more than one sheet and has not
  answered the offer.
- **Track list** — on a songbook, the ordered songs with remove actions.
- **Library/account offer** — after the paper.
- **Feedback line** — after the paper for a freshly generated sheet.

The control bar, track list, summary, prompts, and feedback line are
`no-print`. The paper is not.

## Composition

- Exactly one size control with the four supported sizes and one columns
  control with one or two columns. Both use the segmented-control contract.
- The print action is the bar's only filled action. Do not add "Save PDF" beside
  it; the print dialog provides it.
- Size and column changes apply immediately and repaginate through the preview
  controller. They do not submit a form or change the saved lyric.
- A songbook renders its track list before the paper. Removing a track updates
  the set and may change the page count; the summary follows the new render.
- Offers appear after the paper; their server conditions decide visibility.
- The page summary is updated by the controller after measurement; it is not a
  static string.

## Verification

Static:

- Chrome elements carry `no-print`; the paper does not.
- The control bar has one print action and two segmented controls.
- Each sheet has a title `h1` and stanzas in DOM order.

Behavioural:

- Changing size changes the paper's lyric variables and page count.
- Changing columns changes the stanza grid and may reduce page count.
- At 390px the paper is scaled to the frame and the page does not scroll
  horizontally.
- Printing or saving as PDF hides the bar, summary, prompts, and track list, and
  preserves paper white and print ink.
- The page summary updates after pagination and is announced politely.

Commands:

```sh
bin/rails test test/system/organic_conversion_test.rb
bin/rails test test:system
```

An intentional violation: a second filled action in the control bar, or screen
chrome appearing in the printed result, must be rejected.

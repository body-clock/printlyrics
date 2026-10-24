---
sourcesHash: 823032e6386d1afd6c92f024f566f8f0ee6355044be19da0ec00bd73eeb8d50d
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
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
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

1. **Control bar** — back link and print action. A single sheet has its size and
   columns controls here; a songbook's bar keeps only the two actions, so it can
   be one row on a phone. On a sheet the bar also offers "Add another song"; on a
   songbook the back link is the add action.
2. **Page summary** — paper size, margins, and page count, updated after
   pagination.
3. **Paper** — one or more sheets from the paper-sheet contract.
4. **Flash** — if the server has an outcome for this page.

Optional regions:

- **Songbook offer** — when the visit has more than one sheet and has not
  answered the offer.
- **Songbook binder** — on a songbook, the home above the paper: a heading and
  count, a set-wide format card, and one navigable card per song with its title,
  artist, format summary, remove action, and a current-song marker.
- **Song format dock** — on a songbook, a fixed `no-print` bar that names the
  song occupying the middle of the viewport and carries that song's size and
  columns controls. Its "All songs" link returns to the binder's format card.
- **Layout status** — a polite status region that reports a save failure; it is
  visually hidden until it has something to say.
- **Library/account offer** — after the paper.
- **Feedback line** — after the paper for a freshly generated sheet.

The control bar, binder, format dock, summary, prompts, and feedback line are
`no-print`. The paper is not.

## Composition

- A single sheet has exactly one size control with the four supported sizes and
  one columns control with one or two columns. A songbook has one pair in the
  binder's format card, where every option applies to the whole set, and one pair
  in the dock, where the option applies to the song in view. Both use the
  segmented-control contract. The binder's song cards carry no controls; the
  dock is the only per-song formatting surface.
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
- The binder is an index, not a second control surface. Each card links to its
  song's first sheet. The card for the song in view gets an accent edge, a
  "Reading" label, and `aria-current`; the label carries the state without
  relying on colour.
- The format dock follows the sheet crossing the middle of the viewport. It
  updates its title and selected options as the visitor scrolls, and its controls
  change that song only. Its "All songs" link jumps to the binder's set-wide
  format card, so a whole-book change is still reachable while reading.
- The dock is visually hidden in print, and the shell reserves bottom space so a
  last sheet can scroll clear of it.
- A songbook's binder is one column on a phone and two columns from the desktop
  breakpoint, widening past the paper so the index does not feel squeezed into
  the sheet.
- Starting a songbook from a sheet carries that sheet's current size and column
  count into its first entry. A new song added later inherits the layout of the
  last song in the set.
- A songbook renders its binder before the paper. Removing a song updates the
  set and may change the page count; the summary follows the new render.
- Offers appear after the paper; their server conditions decide visibility.
- The page summary is updated by the controller after measurement; it is not a
  static string.

## Verification

Static:

- Chrome elements carry `no-print`; the paper does not.
- A songbook's control bar has one print action and no size controls.
- The binder's format card has one set-wide size control and one columns control.
- Binder cards have no formatting controls and do link to their sheets.
- A songbook renders a fixed format dock with the song's two controls and an
  "All songs" link.
- Each sheet has a title `h1` and stanzas in DOM order.

Behavioural:

- Changing size changes the paper's lyric variables and page count.
- Changing columns changes the stanza grid and may reduce page count.
- Changing the dock's controls leaves every other song's layout alone.
- The binder's controls change every song and stay active only while all songs
  agree.
- A binder card scrolls to its song and marks that card current.
- A songbook reloads with each entry's saved layout.
- Scrolling to another song updates the dock's title and pressed options, and a
  dock change leaves every other song's layout alone.
- The dock is absent from the printed result.
- At 390px the paper is scaled to the frame and the page does not scroll
  horizontally.
- Printing or saving as PDF hides the bar, summary, prompts, binder, and dock,
  and preserves paper white and print ink.
- The page summary updates after pagination and is announced politely.

Commands:

```sh
bin/rails test test/system/organic_conversion_test.rb
bin/rails test test:system
```

An intentional violation: a second filled action in the control bar, or screen
chrome appearing in the printed result, must be rejected.

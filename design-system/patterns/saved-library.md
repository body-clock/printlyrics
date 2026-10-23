---
sourcesHash: f573503267da8eb3b3634988c4f105a3cda6f7c941df4c9345b194051c631919
id: saved-library
description: >-
  Show a signed-in visitor's ten library slots, the saved sheets and songbooks
  in them, and the empty state that starts the first sheet.
status: discoverable
sources:
  - app/views/saved_items/index.html.erb
  - app/controllers/saved_items_controller.rb
  - app/models/saved_item.rb
  - app/models/user.rb
tests:
  - test/system/accounts_test.rb
  - test/models/saved_item_test.rb
---

# Saved library

## When to use

- The signed-in `/library` page.
- Any future surface that lists the same owned saved items with the same limit.

## When not to use

- A public or unlisted set of pages. Songbooks are token-addressed and use the
  print-preview pattern.
- Search results, feedback demand, or any list the visitor does not own.
- A library with more than `SavedItem::LIMIT` items. There is no pagination; the
  limit is the product rule.

## Structure

Required regions, in order:

1. **Heading** — eyebrow, `h1`, intro with the limit, the count, and the
   capacity meter.
2. **Flash** — if an item was saved or removed.
3. **Content** — either the card grid or the empty panel.

The capacity meter is `SavedItem::LIMIT` dots. The first `capacity` dots carry
`.is-filled`; the meter exposes `role="progressbar"` with min, max, and now.

The card grid is a `<ul class="library-grid">` of library-card items. It is two
columns at wide widths and one below `700px`.

The empty panel is a bordered surface with an eyebrow, `h2`, one explanatory
paragraph, and a primary action back to the entry page.

## Composition

- The count and meter describe the same number. Do not compute one from the
  other in the view; both derive from the loaded saved items and the model
  limit.
- A songbook counts as one slot even though it contains many sheets. The list
  does not expand a songbook into its songs.
- Removing an item uses the card's quiet danger action. It returns the item to
  the anonymous retention window; the page re-renders with the new count.
- The empty state is not an error and does not use danger styling.
- The page reuses the account shell for width (`--layout-library`) but is not a
  single-form account page. Do not add an account panel around the grid.
- There is no "create folder" or bulk action. The library is a flat set of ten.

## Verification

Static:

- The meter has exactly `SavedItem::LIMIT` dots and a matching
  `aria-valuenow`.
- Every card is an `<li>` inside the grid `<ul>` and has a titled `h2` link and
  a named remove action.
- The empty state renders only when there are no saved items.

Behavioural:

- Saving a sheet from the preview adds it and the count/meter increase.
- Removing an item decreases the count/meter and the card disappears.
- A full library shows the full state and does not offer an eleventh save.
- At 390px the grid is one column and no card overflows.

Commands:

```sh
bin/rails test test/system/accounts_test.rb
bin/rails test test/models/saved_item_test.rb
```

An intentional violation: a meter that counts sheets inside a songbook, or a
library with an unlabelled remove control, must be rejected.

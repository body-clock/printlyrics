---
sourcesHash: 569899b3df4c0805891aa1951c41c3a753dd0af2948ef40f1f7767b4cf1440c9
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

1. **Heading** — `h1`, short intro, and understated count/capacity.
2. **Flash** — if an item was saved or removed.
3. **Content** — either a saved-item list or the empty panel. A populated list
   has a visible removal explanation; full capacity adds an informational note.

Capacity is a plain count derived from the loaded items and `SavedItem::LIMIT`.
It remains secondary to titles and actions; no progress meter competes with them.

The list is a `<ul class="library-grid">` of library-card rows, one readable
column at every width. Extra width aligns actions rather than creating a dashboard.

The empty panel uses a quiet top rule, eyebrow, `h2`, explanatory paragraph and
primary action back to entry.

## Composition

- The count derives from loaded saved items and the model limit.
- A songbook counts as one slot even though it contains many sheets. The list
  does not expand a songbook into its songs.
- Removing an item uses the quiet “Remove from library” action, whose accessible
  name includes the title and whose description references the visible retention
  explanation. It removes library membership, not the shared output; the usual
  180-day retention window resumes. The outcome returns to the updated list.
- The empty state is not an error and does not use danger styling.
- The page reuses the account shell for width (`--layout-library`) but is not a
  single-form account page. Do not add an account panel around the list.
- There is no "create folder" or bulk action. The library is a flat set of ten.

## Verification

Static:

- Capacity counts saved items, never individual songs inside books.
- Every row is an `<li>` inside the list `<ul>` with a titled `h2` link and a
  named removal action associated with its consequence.
- The empty state renders only when there are no saved items.

Behavioural:

- Saving a sheet adds it and increases the count.
- Removing membership decreases the count and removes the row.
- A full library shows the full state and does not offer an eleventh save.
- At 390px the grid is one column and no card overflows.

Commands:

```sh
bin/rails test test/system/accounts_test.rb
bin/rails test test/models/saved_item_test.rb
```

Intentional violations: counting songs inside a book as library slots, or an
unlabelled removal action without its retention consequence, must be rejected.

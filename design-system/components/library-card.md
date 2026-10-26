---
sourcesHash: ceef69350d151d60299e9d29b678f5c6cf573bf8edafa5195ec5ada753ad22fc
id: library-card
description: >-
  Present one saved lyric sheet or songbook in the library with its kind, save
  date, title link, and open and remove actions.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/saved_items/index.html.erb
tests:
  - test/system/accounts_test.rb
---

# Library card

## When to use

- Listing a saved lyric sheet or songbook as one restrained row in the library.
- Both kinds use the same row and differ in the visible kind and title derivation.

## When not to use

- Search results or any public list. Those are not owned saved items.
- The ordered contents of a songbook. Use the print-preview track list.
- A single item's detail page. The card is a summary with actions.

## Public API

```erb
<li class="library-card">
  <div class="library-card-head">
    <p class="library-kind">Lyric sheet</p>
    <time class="library-saved" datetime="...">Saved ...</time>
  </div>
  <h2><%= link_to title, item_path %></h2>
  <div class="library-card-actions">
    <%= link_to "Open", item_path, class: "library-open" %>
    <%= button_to "Remove from library", saved_item_path(saved_item),
          method: :delete,
          class: "button-text button-text-danger",
          form: { class: "library-remove-form" },
          aria: { label: "Remove #{title} from your library", describedby: "library-removal-note" } %>
  </div>
</li>
```

- `.library-grid` owns a single-column readable list and row separation.
- `.library-card` is a restrained row, not an enclosing raised card. It stacks
  metadata and actions on narrow screens and may align them on wider screens.
- `.library-card-head` holds `.library-kind` and `.library-saved`, aligned on
  their baselines.
- The title is an `h2` containing the link. `.library-open` is a secondary
  text-and-arrow action; the remove action is the shared quiet danger action.
- The consumer supplies the title, kind label, saved timestamp, and paths. The
  songbook title derivation belongs to the application helper.

## Behaviour and states

- The card itself is not a link. Opening happens through the title or the
  "Open" action.
- Removing returns the item to the anonymous retention window; it does not
  invalidate its shared link. The list visibly explains this consequence and
  the action references that explanation with `aria-describedby`.
- A songbook's kind is "Songbook"; its title names the first song and the count.
- The saved date uses a `<time datetime>` so it stays machine-readable.
- Cards wrap their title anywhere and truncate nothing else; a long title must
  not overflow the grid.

## Accessibility

- The list parent is a `<ul>`; each card is an `<li>`. Do not render cards as a
  div grid without list semantics.
- The title link is the primary way to open the item. Give it the full title.
- Open and Remove each provide a minimum 44px pointer target.
- The remove button's accessible name includes the item title; the visible
  label says “Remove from library”, not an ambiguous “Remove”.
- Do not convey the item kind by colour; `.library-kind` is text and the
  uppercase eyebrow treatment is not required for meaning.

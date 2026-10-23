---
sourcesHash: 149c950155cb3d815470d191aced502271f3f858b1c816e477906cb24ae75793
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

- Listing an item the signed-in visitor has saved, inside the library grid.
- The item is a lyric sheet or a songbook; both use the same card and differ
  only in the kind label and the title derivation.

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
    <%= button_to "Remove", saved_item_path(saved_item),
          method: :delete,
          class: "button-text button-text-danger",
          form: { class: "library-remove-form" },
          aria: { label: "Remove #{title}" } %>
  </div>
</li>
```

- `.library-grid` is the parent and owns the two-column (one-column on mobile)
  layout and the gap. The card does not set its own width.
- `.library-card` is a flex column with `--radius-md`, a
  `--border-default` edge, and `--space-5` padding.
- `.library-card-head` holds `.library-kind` and `.library-saved`, aligned on
  their baselines.
- The title is an `h2` containing the link. `.library-open` is a secondary
  text-and-arrow action; the remove action is the shared quiet danger action.
- The consumer supplies the title, kind label, saved timestamp, and paths. The
  songbook title derivation belongs to the application helper.

## Behaviour and states

- The card itself is not a link. Opening happens through the title or the
  "Open" action.
- Removing returns the item to the anonymous retention window. There is no
  confirmation step in this component; the action's label and danger hover are
  the only signals.
- A songbook's kind is "Songbook"; its title names the first song and the count.
- The saved date uses a `<time datetime>` so it stays machine-readable.
- Cards wrap their title anywhere and truncate nothing else; a long title must
  not overflow the grid.

## Accessibility

- The list parent is a `<ul>`; each card is an `<li>`. Do not render cards as a
  div grid without list semantics.
- The title link is the primary way to open the item. Give it the full title.
- The Open and Remove actions each provide a 24px minimum pointer target
  without enlarging their text.
- The remove button has an accessible name that includes the item title, while
  the visible label may remain "Remove".
- Do not convey the item kind by colour; `.library-kind` is text and the
  uppercase eyebrow treatment is not required for meaning.

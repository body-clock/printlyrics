---
sourcesHash: 5b91f2547063c2c5f40f734d03bef68059216d03b69397010e993a9dda49d366
id: paper-sheet
description: >-
  Render one letter-size, print-first lyric sheet with a title, optional artist,
  stanzas, and the scan mark, in one of four supported size variants.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_sheet_mark.html.erb
  - app/helpers/application_helper.rb
  - app/javascript/controllers/preview_controller.js
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
  - test/models/sheet_mark_test.rb
---

# Paper sheet

## When to use

- A generated lyric page or a songbook page: the screen preview and the printed
  result are the same element.
- The sheet is the product's output. Every lyric surface uses it.

## When not to use

- Screen-only summaries, guide content, or the entry form. Those are text on the
  elevation canvas, not paper.
- A printable receipt or a generic document. The sheet's margins, scan mark, and
  lyric sizing are specific to lyrics.
- A single typographic block without a title or stanzas.

## Public API

```erb
<div class="paper-frame" data-preview-target="pageFrame">
  <div class="paper-pages" data-preview-target="pages">
    <article class="paper size-m is-unpaginated" data-preview-page data-preview-song>
      <header class="lyric-header">
        <h1>The Quiet Part</h1>
        <p>Metric Field</p>
      </header>
      <div class="lyrics">
        <section class="stanza">...</section>
      </div>
    </article>
  </div>
</div>
```

- `.paper` is the sheet. It owns `--sheet-width`, `--sheet-height`,
  `--sheet-margin`, the print colours, the serif family, and the four size
  variants.
- `.size-s`, `.size-m`, `.size-l`, `.size-xl` set `--lyric-body-size`,
  `--lyric-line-height`, `--lyric-title-size`, `--lyric-artist-size`, and
  `--stanza-gap`. There is no other supported size.
- `.is-unpaginated` lets the sheet grow past one page on screen until the
  preview controller measures and paginates it. The controller owns page
  splitting and the `--preview-scale` used on phones.
- `.lyrics` is the stanza container. `.cols-2` selects two columns; the
  controller and print layout own the rest.
- `.stanza` preserves whitespace and avoids breaking inside a stanza where the
  browser allows it.
- `.lyric-header` holds the title `h1` and optional artist `<p>`. The title
  falls back to the application's untitled translation; the consumer supplies
  the resolved title.
- `.sheet-mark` is rendered once per response from the shared template and
  cloned onto each page by the preview controller. Its code and label are
  helper-owned; the component only positions it in the paper's bottom margin.

## Behaviour and states

- The screen and print appearances are the same promise: paper white, print ink,
  and the same margins. A theme change must not tint the sheet.
- Interactivity lives outside the sheet: size, columns, pagination, and print
  are preview-shell controls.
- The sheet can appear more than once in a songbook. Page order follows DOM
  order and the binder order.
- `size-m` is the default. Other sizes are chosen only through the segmented
  control.
- Each songbook entry carries its own size and column count. A song's
  continuation pages keep that entry's format, and changing one entry never
  restyles another.

## Accessibility

- Each sheet is an `<article>` with a real `h1`; a songbook repeats the pattern
  for each song. Do not replace headings with styled paragraphs.
- Stanza text remains selectable, readable, and in DOM order. Two columns do not
  change reading order for assistive technology.
- The scan mark is decorative (`aria-hidden`) and has a visible domain label; a
  screen reader does not need the QR payload.
- Printed contrast is inherent: black ink on paper white, with
  `--print-muted` only for the artist and mark label. Do not use a screen
  status colour on paper.
- The sheet has no focusable elements. Controls around it carry their own
  names and focus states.

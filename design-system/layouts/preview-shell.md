---
sourcesHash: c0f8d0b8f5801b67f388928bec9cd277b81634d2659a99b6da70970ecdf01a9a
id: preview-shell
description: >-
  Own the print-preview page: a fixed control bar, the neutral stage, one or
  more paper sheets with per-song formatting, and the optional offers that follow
  them.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_preview_controls.html.erb
  - app/views/shared/_sheet_mark.html.erb
  - app/javascript/controllers/preview_controller.js
  - app/javascript/controllers/layout_preference_controller.js
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
---

# Preview shell

## When to use

- A generated lyric sheet or a songbook: the screen where the visitor checks the
  paper before printing or saving it.
- Any future surface whose main content is the paper sheet.

## When not to use

- The entry form or editing flow. That is the landing shell.
- A guide or account page.
- A page that needs the site header. The preview hides site chrome because its
  own control bar owns the top of the viewport.

## Public API

```erb
<div class="preview-shell"
     data-controller="preview"
     data-action="resize@window->preview#fitPagePreview afterprint@window->preview#restorePagePreview">
  <%= render "shared/flash" %>

  <nav class="control-bar no-print" aria-label="...">
    <div class="control-inner">
      <div class="control-start">...</div>
      <div class="control-groups">
        <%# A sheet puts size and columns here; a songbook keeps only Print. %>
        <%= render "shared/preview_controls" %>
        <button type="button" class="button button-print" data-action="preview#print">...</button>
      </div>
    </div>
  </nav>

  <p class="page-summary no-print" data-preview-target="pageSummary" aria-live="polite"></p>
  <p class="layout-status sr-only" role="status" aria-live="polite"
     data-preview-target="layoutStatus"></p>
  <%= render "shared/sheet_mark" %>

  <section class="songbook-binder no-print" aria-labelledby="songbook-heading">
    <div class="songbook-binder-head">
      <h2 id="songbook-heading">This songbook</h2>
      <p class="songbook-binder-count">3 songs</p>
    </div>
    <section class="songbook-format" id="songbook-format">
      <div class="songbook-format-copy">...</div>
      <div class="songbook-format-controls">
        <%= render "shared/preview_controls", scope: "all" %>
      </div>
    </section>
    <ol class="songbook-tracks">
      <li class="songbook-track" data-preview-binder-song="...">
        <a class="songbook-track-link" href="#song-...">...</a>
        <%= button_to "Remove", "...", method: :delete %>
      </li>
    </ol>
  </section>

  <div class="paper-frame" data-preview-target="pageFrame">...</div>

  <aside class="song-format-dock no-print" aria-label="Format the song you are reading">
    <div class="song-format-dock-heading">
      <p class="song-format-dock-title">...</p>
      <a class="song-format-dock-all" href="#songbook-format">All songs</a>
    </div>
    <div class="song-format-dock-controls" role="group"
         data-preview-target="songFormatGroup">
      <%= render "shared/preview_controls", scope: "active" %>
    </div>
  </aside>
</div>
```

- The page sets `content_for :body_class, "preview-body"` and
  `content_for :hide_site_chrome, true`.
- `.preview-shell` owns the top padding below the fixed bar and the stage
  padding. The `.preview-body` background is `--elevation-preview`.
- `.control-bar` is fixed, full width, and `no-print`. `.control-inner` uses
  `--layout-toolbar` and `--control-md` actions.
- `.control-start` holds the back link and, on a sheet, the add-to-songbook
  action. `.control-groups` holds the segmented controls and the print action.
  On a sheet the pair formats that sheet. A songbook's bar keeps only the print
  action; its set-wide formatting lives in the binder.
- `.page-summary` reports paper size, margins, and page count; the preview
  controller updates it and it is `aria-live="polite"`.
- `.layout-status` is a polite, visually hidden region. The controller fills it
  only when a songbook layout save fails.
- `.song-format-dock` is a fixed `no-print` bar for a songbook. It names the song
  crossing the middle of the viewport and holds that song's size and columns
  controls. The controller updates the title, the group label, and the pressed
  options as the visitor scrolls and repaginates. Its `.song-format-dock-all`
  link jumps to the binder's `#songbook-format` card.
- The shell adds bottom padding while the dock is present so the last sheet can
  scroll clear of it.
- `.paper-frame` > `.paper-pages` holds the sheets. The controller owns
  pagination, per-song layout, `--preview-scale`, and the frame height.
- A songbook adds `.songbook-binder` before the paper. It is `no-print`, widens
  past the paper on desktop, and holds the heading, set-wide `.songbook-format`
  card, and `.songbook-tracks` as one card per song. Cards are links into the
  set; they carry no formatting controls.
- A card gets `.is-current` and `aria-current="location"` while its song is in
  view. Its "Reading" label is hidden otherwise.
- The forms that start a songbook carry the current size and columns from the
  visitor's stored preference. `layout_preference_controller.js` fills their
  hidden fields on connect and again on submit, so the sheet keeps the format it
  was viewed in.
- A songbook's shell carries `data-songbook-size`, `data-songbook-layout-url`,
  and `data-layout-error`; each song source carries `data-preview-size`,
  `data-preview-columns`, and `data-preview-layout-url`.
- Offers, prompts, and the sheet mark follow the paper in the order the page
  renders them.

## Composition

- Exactly one print action. A sheet has one pair of segmented controls; a
  songbook has one set-wide pair in the binder and one current-song pair in the
  dock. Do not add a second action to the bar that competes with Print.
- The sheet is the content; chrome is `no-print` and must not overlap the paper.
- The shell owns the fixed-bar offset. A child must not add its own top padding
  to clear the bar.
- On a phone a sheet's control bar becomes a two-row grid. A songbook's bar has
  only the add action and Print, so it stays one row and its shell top padding
  shrinks with it. The paper is scaled rather than clipped, and the page must
  not scroll horizontally.
- A songbook may render many sheets. The binder order and the page order are
  the same; the controller measures pages but does not reorder songs. A binder
  card jumps to its song; the dock formats the song in view; the binder's format
  card changes every song.
- The binder is one column on a phone and two columns from the desktop
  breakpoint. The dock is the always-reachable per-song control and must not
  become a second bulk control. On a phone the dock wraps its heading above the
  two controls.
- The shell supports zero offers (a shared page) through all offers (a freshly
  generated sheet). Visibility is server-owned.

## Accessibility

- The control bar is a `<nav>` with a visible label and native buttons.
- The page summary is a polite live region; it must not be the only way to know
  the page count. The paper itself remains readable.
- Print hides chrome, so the printed document starts with the sheet's title.
- The paper is not focusable; controls remain the only tab stops.
- The dock's scrolling title is not a live region: scrolling through a set must
  not announce every song. Its control group carries an `aria-label` that names
  the current song when focus reaches it.
- A binder card is a real link to the song's first sheet. The current card adds
  `aria-current="location"` and a visible "Reading" label, so the state does not
  depend on the accent edge alone.
- `scrollbar-gutter: stable` is deliberate: it keeps the scaled paper from
  changing width when the scrollbar appears.

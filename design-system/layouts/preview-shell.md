---
sourcesHash: e3ddab999f98edac85b00a961cc955a4c20ed65cbc6f59d7f9027bb8d8ab817b
id: preview-shell
description: >-
  Own the print-preview page: a fixed control bar, the neutral stage, one or
  more paper sheets, and the optional offers that follow them.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_preview_controls.html.erb
  - app/views/shared/_sheet_mark.html.erb
  - app/javascript/controllers/preview_controller.js
tests:
  - test/system/organic_conversion_test.rb
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
        <%= render "shared/preview_controls" %>
        <button type="button" class="button button-print" data-action="preview#print">...</button>
      </div>
    </div>
  </nav>

  <p class="page-summary no-print" data-preview-target="pageSummary" aria-live="polite"></p>
  <%= render "shared/sheet_mark" %>
  <div class="paper-frame" data-preview-target="pageFrame">...</div>
</div>
```

- The page sets `content_for :body_class, "preview-body"` and
  `content_for :hide_site_chrome, true`.
- `.preview-shell` owns the top padding below the fixed bar and the stage
  padding. The `.preview-body` background is `--elevation-preview`.
- `.control-bar` is fixed, full width, and `no-print`. `.control-inner` uses
  `--layout-toolbar` and `--control-md` actions.
- `.control-start` holds the back link and, on a sheet, the add-to-songbook
  action. `.control-groups` holds the size and column segmented controls and the
  print action.
- `.page-summary` reports paper size, margins, and page count; the preview
  controller updates it and it is `aria-live="polite"`.
- `.paper-frame` > `.paper-pages` holds the sheets. The controller owns
  pagination, `--preview-scale`, and the frame height.
- A songbook adds `.songbook-tracks` before the paper. It is `no-print`.
- Offers, prompts, and the sheet mark follow the paper in the order the page
  renders them.

## Composition

- Exactly one print action and one pair of segmented controls. Do not add a
  second action to the bar that competes with Print.
- The sheet is the content; chrome is `no-print` and must not overlap the paper.
- The shell owns the fixed-bar offset. A child must not add its own top padding
  to clear the bar.
- On a phone the control bar becomes a two-row grid; the paper is scaled rather
  than clipped. The page must not scroll horizontally.
- A songbook may render many sheets. The track list order and the page order are
  the same; the controller measures pages but does not reorder songs.
- The shell supports zero offers (a shared page) through all offers (a freshly
  generated sheet). Visibility is server-owned.

## Accessibility

- The control bar is a `<nav>` with a visible label and native buttons.
- The page summary is a polite live region; it must not be the only way to know
  the page count. The paper itself remains readable.
- Print hides chrome, so the printed document starts with the sheet's title.
- The paper is not focusable; controls remain the only tab stops.
- `scrollbar-gutter: stable` is deliberate: it keeps the scaled paper from
  changing width when the scrollbar appears.

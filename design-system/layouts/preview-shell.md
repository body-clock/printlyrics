---
sourcesHash: fb5d3a3d9e6ec84670ae408464cbee28f3cc822e00c7c30e88618b8b1757b2d7
id: preview-shell
description: >-
  Arrange a document-led sheet or songbook workspace with a sticky action band,
  fitted paper stage, responsive format inspector and optional song outline.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/views/shared/_preview_controls.html.erb
  - app/views/shared/_sheet_mark.html.erb
  - app/javascript/controllers/preview_controller.js
  - app/javascript/controllers/layout_preference_controller.js
  - app/javascript/controllers/workspace_controller.js
  - app/views/shared/_preview_view_controls.html.erb
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
  - test/system/workspace_interaction_test.rb
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

- Set `content_for :body_class, "preview-body"` and
  `content_for :hide_site_chrome, true`. The workspace replaces normal site
  chrome; it does not duplicate it.
- `.preview-shell` binds `preview workspace`; resize/afterprint call preview
  fitting, and window keydown calls `workspace#escape`.
- `.control-bar.workspace-actions.no-print` is sticky. `.control-inner`
  contains task navigation and one primary Print action. A sheet offers Edit
  lyrics; a book offers Add another song. Format invokes the mobile inspector.
- `.workspace-layout` contains `.workspace-stage` followed by
  `.workspace-inspector`. A book adds `.workspace-layout-songbook` and a
  `.workspace-outline` details region before the stage.
- The stage owns `shared/preview_view_controls` (measured page count, inspection
  zoom, browser-PDF explanation), sheet-mark template, and
  `.paper-frame[data-preview-target="pageFrame"]` containing
  `.paper-pages[data-preview-target="pages"]`.
- The inspector has a labelled heading, visible Close action and formatting
  fieldsets. Its `workspace` targets are `inspector`, `heading` and `trigger`.
  `aria-controls` connects Format to the inspector; `aria-expanded` follows
  visibility. The heading is focusable with `tabindex="-1"`.
- `shared/preview_controls` without scope formats one sheet. A book places
  `scope: "active"` in a named current-song group and `scope: "all"` in the
  distinct `#songbook-format` section. Whole-book controls expose Mixed text.
- Each book source carries token, size, columns and its layout PATCH URL.
  `.songbook-track-link` targets that song's first paper; current location has
  `aria-current="location"` and visible Reading text.
- `.layout-save-feedback` is visible on failed persistence, with live status
  and Retry saving. It sticks below the measured action band even while reading
  continuation pages. Every failed dimension remains pending until confirmed;
  a later success cannot erase an earlier failed change.
- `.workspace-secondary.no-print` holds optional book, keep and feedback actions
  after the document. Starting a book carries the sheet's current formatting
  through the existing layout-preference controller.

## Composition

- The paper is the primary content. Exactly one filled Print action appears in
  the action band; Save as PDF is explained as a browser print option.
- At widths below 1100px the inspector is a nonmodal bottom panel, max 55dvh,
  with safe-area spacing. It leaves preview visible and scrolls its own controls.
  It has no backdrop and does not trap focus away from the preview.
  Its heading and Close stay visible while its controls scroll.
- At 1100px and wider the inspector becomes an inline sticky right-hand panel.
  Its close/trigger controls are hidden; all settings stay reachable.
- A book outline is a native disclosure until 1440px. At 1440px it opens as a
  persistent left column; paper and inspector occupy the other two columns.
- The stage has `min-width: 0` and owns horizontal inspection scrolling.
  Fit scales to stage width; explicit zoom never widens the document body.
  Magnification is independent of physical print dimensions and text size.
- Paper count is Measuring until layout completes, then reports the measured
  count. Formatting repaginates and preserves the current song's reading anchor.
- Selecting a song closes the compact outline before scrolling to its first
  page. Scrolling and repagination update the named formatting target.
- Per-song changes affect only that entry. Whole-book changes affect only the
  selected dimension, preserving intentionally mixed values in the other.
- Remove reloads the book and remeasures remaining pages in entry order. Adding
  keeps the book token throughout entry/search/select/preview.
- All outline, inspector, action, view-control and status surfaces are no-print.
  Print resets workspace grid, stage overflow, transform and frame height.

## Accessibility

- Action bands and outlines have accessible names and native controls.
- Format moves focus to the panel heading. Close and Escape dismiss the mobile
  panel and return focus to Format. Desktop settings remain inline.
- Working controls retain at least 44px targets; zoom select uses 16px text.
- Count and save feedback announce politely; a save error remains visible.
- Current song has both `aria-current` and text, never colour alone.
- Printed pages preserve DOM/outline order, white paper and print ink in either
  screen theme. No workspace controls or messages reach paper.
- `scrollbar-gutter: stable` prevents fitting shifts as vertical scroll appears.

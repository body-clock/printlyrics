---
sourcesHash: c7df2ca65f9ffdc5f4ed13ec265ef8c44546c6ad4fa3d20101c953690a28c849
id: segmented-control
description: >-
  Let the visitor choose one value from a small fixed set of display options
  for a sheet, one song in a set, or every song, with every option visible at
  once.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_preview_controls.html.erb
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/javascript/controllers/preview_controller.js
tests:
  - test/system/organic_conversion_test.rb
  - test/system/songbook_layout_test.rb
---

# Segmented control

## When to use

- Two to four mutually exclusive display options must stay visible because the
  visitor compares them while looking at the result: lyric size (`S M L XL`) and
  column count (`1`, `2`).
- The options have short, unambiguous labels and apply immediately.
- The change is presentational and does not leave the page or submit a form.
- In a songbook, the dock's control changes the song in view and the binder's
  control changes every song. The two scopes are distinct; do not let a
  per-song control update its neighbours.

## When not to use

- A form value that is submitted, such as a feedback reason. Use a select in a
  [Field](field.md).
- Navigation between pages or views.
- More than four options, or options whose labels need explanation. Use a
  select or a separate choice surface.
- A one-off binary action such as "Show punctuation". There is no toggle
  component; a checkbox inside a form is the native answer.
- An irreversible action. Use [Button](button.md).

## Public API

```erb
<%= render "shared/preview_controls",
      size: "m",
      columns: 1,
      scope: "all" %>
```

The partial renders two fieldsets:

```erb
<fieldset class="segmented-control"
          data-preview-layout="size"
          data-preview-layout-scope="<%= scope %>">
  <legend><%= t(".size") %></legend>
  <button type="button"
          class="is-active"
          aria-pressed="true"
          data-action="preview#setSize"
          data-preview-value="m">M</button>
</fieldset>
```

- The root is a `<fieldset class="segmented-control">` with a visible
  `<legend>`; the legend names the dimension being chosen.
- `data-preview-layout` names the dimension (`size` or `columns`).
  `data-preview-layout-scope="all"` scopes the control to the whole set, and
  `data-preview-layout-scope="active"` scopes it to the song in view. A control
  with neither attribute belongs to a single sheet.
- Each option is a native `<button type="button">` with a
  `data-preview-value`. `.is-active` and `aria-pressed="true"` mark the selected
  option; all others carry `aria-pressed="false"`.
- The preview controller owns the state, the paper class, repagination, and the
  background save for a songbook. The partial accepts `size`, `columns`, and
  `scope` locals.
- `.columns-control` is an empty marker class used by markup; it has no styles.
  Do not rely on it for layout.
- The component owns only the visual group. The caller supplies the option
  values, labels, selected value, and the action that consumes it.

## Behaviour and states

- Exactly one option is active at a time. Activating an option is immediate and
  does not submit.
- A bulk control is active only while every song agrees. A mixed set leaves every
  option unselected so it cannot claim a format the set does not have.
- A bulk control changes its own dimension only. Applying a size to every song
  must not overwrite a column choice that songs deliberately differ on, and the
  reverse holds too.
- A control scoped to the active song updates its pressed options as the visitor
  scrolls between songs. Its change applies only to that song.
- The selected option uses `--elevation-sunken`, a `--border-default` edge, and
  `--ui-accent` text. Unselected options are transparent and use
  `--content-secondary`.
- Hover is a `--elevation-sunken` fill without the accent.
- Below `700px` the option box shrinks from `--control-icon` to `1.9rem`; the
  group stays on one row.
- Keyboard activation is the native button behaviour: Tab reaches each option,
  Enter/Space activates it.

## Accessibility

- The fieldset and legend group the options; do not replace them with a `div`
  and an `aria-label`.
- `aria-pressed` is the state; the visual `.is-active` class alone is
  insufficient.
- The legend is visible and names the dimension ("Size", "Columns"). The option
  labels may be abbreviated because the legend supplies the context.
- Focus uses the global focus ring; do not remove it to tighten the group.

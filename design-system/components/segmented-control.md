---
sourcesHash: 9ff3b2bc39fd210595013f11d4d357091a60964964741d2025c1b299d0009d49
id: segmented-control
description: >-
  Let the visitor choose one value from a small fixed set of display options
  that changes the current preview, with every option visible at once.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_preview_controls.html.erb
  - app/views/lyrics/show.html.erb
  - app/views/songbooks/show.html.erb
  - app/javascript/controllers/preview_controller.js
tests:
  - test/system/organic_conversion_test.rb
---

# Segmented control

## When to use

- Two to four mutually exclusive display options must stay visible because the
  visitor compares them while looking at the result: lyric size (`S M L XL`) and
  column count (`1`, `2`).
- The options have short, unambiguous labels and apply immediately.
- The change is presentational and does not leave the page or submit a form.

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
<fieldset class="segmented-control">
  <legend><%= t(".size") %></legend>
  <% %w[s m l xl].each do |size| %>
    <button type="button"
            class="<%= size == "m" ? "is-active" : nil %>"
            aria-pressed="<%= size == "m" %>"
            data-preview-target="sizeButton"
            data-action="preview#setSize"
            data-size="<%= size %>"><%= t(".sizes.#{size}") %></button>
  <% end %>
</fieldset>
```

- The root is a `<fieldset class="segmented-control">` with a visible
  `<legend>`; the legend names the dimension being chosen.
- Each option is a native `<button type="button">`. `.is-active` and
  `aria-pressed="true"` mark the selected option; all others carry
  `aria-pressed="false"`.
- The `data-*` names connect the option to the Stimulus controller. The
  preview controller owns the state, the paper class, and repagination.
- `.columns-control` is an empty marker class used by markup; it has no styles.
  Do not rely on it for layout.
- The component owns only the visual group. The caller supplies the option
  values, labels, selected value, and the action that consumes it.

## Behaviour and states

- Exactly one option is active at a time. Activating an option is immediate and
  does not submit.
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

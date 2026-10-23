---
sourcesHash: 719cc781a5d0bad3dfd9ec6d051675c046e283c83d112e67cae084255030007f
id: field
description: >-
  Pair one label with one text, email, password, search, select, or textarea
  control and an optional hint, using the shared control edge and focus state.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/new.html.erb
  - app/views/sessions/new.html.erb
  - app/views/registrations/new.html.erb
  - app/views/passwords/new.html.erb
  - app/views/passwords/edit.html.erb
  - app/views/feedbacks/new.html.erb
tests:
  - test/integration/accounts_flow_test.rb
  - test/integration/feedback_flow_test.rb
---

# Field

## When to use

- The visitor enters or chooses one value: song title, artist, lyrics, email,
  password, feedback reason, message, or contact address.
- Use the hint row (`.field-label-row` with a `<span>`) for a short qualifier
  such as "Optional", "Required", or the password-length hint.
- Use `.field.grow` inside a flex row when the field should take the remaining
  width, as in the song search.
- Use `.metadata-grid` for two short fields that read as one row: title and
  artist.

## When not to use

- For an action. Use [Button](button.md).
- For read-only information that is not editable. Use a paragraph or a
  definition list.
- For a group of mutually exclusive display options that change a preview. Use
  [Segmented control](segmented-control.md).
- For validation messages. Use [Form errors](form-errors.md) and keep the field
  labels intact.

## Public API

```erb
<div class="field">
  <%= form.label :title, t(".title") %>
  <%= form.text_field :title, placeholder: t(".optional") %>
</div>

<div class="field">
  <div class="field-label-row">
    <%= form.label :lyrics, t(".lyrics") %>
    <span><%= t(".required") %></span>
  </div>
  <%= form.text_area :lyrics, rows: 15, required: true %>
</div>
```

- The wrapper `.field` owns a `--space-2` vertical gap and the full width.
- `.field input`, `.field select`, and `.field textarea` share a
  `--border-control` edge, `--radius-sm`, `--elevation-surface` fill, and
  `--control-lg` height for single-line controls.
- A textarea keeps the serif family and `--leading-body`; its minimum height is
  component-owned (the lyrics box is tall, the feedback note is shorter).
- Placeholder text uses `--content-placeholder`; it never replaces a label.
- Focus changes the edge to `--ui-focus` and the global focus ring appears.
  Hover uses `--border-control-hover`.
- The consumer supplies the input type, name, value, autocomplete, and
  required/maxlength constraints from the form's domain rules.

## Behaviour and states

- Empty, filled, hover, focus, disabled, and read-only are native states.
- The placeholder disappears when the field is filled; no floating label is
  used.
- The field does not render its own error text. A failed form renders the
  page-level error summary and the field returns with its submitted value where
  the controller does so.
- There is no inline success state.

## Accessibility

- Every control has a programmatically associated `<label>`. `sr-only` labels
  are allowed for search where the placeholder and section heading provide the
  visible context.
- The hint is advisory only. Do not put a requirement exclusively in the hint
  when a native `required` attribute can express it.
- The control edge meets 3:1 against the surrounding surface through
  `--border-control`; do not restyle a field with `--border-default`.
- Errors are announced by [Form errors](form-errors.md); the consumer must keep
  the summary near the form and must not clear a field to hide an error.

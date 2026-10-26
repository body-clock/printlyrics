---
sourcesHash: 654de67c0c9706417209994c90054d32d21ee4713ff206eb611c1013627901be
id: form-errors
description: >-
  Summarise the validation errors of one form in a single announced alert above
  its fields.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_form_errors.html.erb
  - app/views/registrations/new.html.erb
  - app/views/passwords/edit.html.erb
  - app/views/feedbacks/new.html.erb
tests:
  - test/integration/accounts_flow_test.rb
  - test/integration/feedback_flow_test.rb
---

# Form errors

## When to use

- A model rejected the submitted form and the visitor needs the reasons before
  correcting the fields: registration, password reset, feedback.
- Render it once per form, above the first field inside the panel.

## When not to use

- A page-level outcome that is not about the fields. Use [Flash](flash.md).
- A hint that is always present, such as a password length. Use the
  [Field](field.md) hint row.
- A single field's success or helper text.

## Public API

```erb
<%= render "shared/form_errors", errors: @user.errors %>
```

- The partial renders nothing when `errors` is absent or empty.
- When present, it prints `errors.full_messages.to_sentence()` in
  `.form-errors`.
- Optional `id` supplies a stable association target for form-level feedback
  through `aria-describedby`, including base errors not owned by one field.
  Omitted `id` leaves existing consumers unchanged.
- The panel owns the spacing above the summary; inside an account panel the
  summary sits at the top with no added outer margin.

## Behaviour and states

- The block appears only on a failed submission; there is no success variant.
- It uses `--ui-danger-surface` with a `--border-danger` edge and
  `--ui-danger` text.
- It lists every message in one sentence rather than one row per field. The
  fields themselves are not annotated by this component.
- A Turbo response may replace the panel; the summary is part of that render.

## Accessibility

- `role="alert"` announces the summary once when it appears.
- The summary is not a substitute for a field label. The consumer must keep
  labels and the submitted values so the visitor can find the field each
  message refers to.
- Attribute-level invalid state and associated messages use the Field helper and
  partial alongside this summary; the summary does not replace inline feedback.
- Do not focus the summary automatically. The project's form controller may
  choose to move focus; that is behaviour outside this component.
- The error colour is paired with the summary's position and wording; colour is
  not the only cue.

---
sourcesHash: 27758e811567c1b86302904101ac4a28419a1dc30704293f21c5a42ccbd49c61
id: flash
description: >-
  Announce one page-level success or error outcome from the server in a fixed
  notice that the visitor can read without leaving the page.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_flash.html.erb
  - app/views/layouts/application.html.erb
tests:
  - test/integration/feedback_flow_test.rb
---

# Flash

## When to use

- A server response produced one outcome the visitor must know about: signed in,
  signed out, saved, removed, or a submission that could not be accepted.
- The message is a short sentence about what happened, not a field correction.

## When not to use

- Field-level validation. Use [Form errors](form-errors.md) inside the form.
- A permanent explanation or a next-step offer. Use [Inline offer](inline-offer.md)
  or page copy.
- A progress or busy state. The search results own their own loading indicator.
- More than one message at a time. If two outcomes occur, combine them into one
  sentence rather than stacking notices.

## Public API

```erb
<%= render "shared/flash" %>
```

- The partial iterates `flash`. The `alert` key renders `.flash-error`;
  every other key renders `.flash-success`.
- Placement is the caller's: the layout renders it inside `<main>` for normal
  pages, while the entry frame and the preview place it near the top of their
  own shell.
- The partial adds `role="alert"` for errors and `role="status"` for success,
  plus a filled mark (`!` or `✓`) that is `aria-hidden`. The mark is the
  non-colour status cue.

## Behaviour and states

- The notice is fixed, centred, and bounded to `34rem`. It does not push
  content and does not auto-dismiss; the next navigation or Turbo render
  replaces it.
- `detail` success and error surfaces use `--ui-success-surface` /
  `--ui-danger-surface` with `--border-success` / `--border-danger`. A 3px
  status rule on the leading edge carries `--ui-success` or `--ui-danger`, and
  the mark is filled with the same colour while its glyph takes
  `--elevation-surface`, so the outcome reads at a glance and without colour.
- The message is body-size, medium-weight text in `.flash-message`; it is the
  one sentence the visitor must read, so it is not set at label size.
- On preview pages the notice sits below the fixed control bar through the
  `.preview-body .flash` offset.
- Print hides `.flash`; a notice is never part of the sheet.

## Accessibility

- `role="alert"` interrupts for an error; `role="status"` is polite for success.
  Do not add a second live region around the same message.
- The message must stand alone without the mark or the colour.
- Do not move focus to the notice. A visitor who triggered the action remains
  where they were.
- Long messages wrap; the notice has no close button, so it must not obscure a
  control the visitor needs in order to continue.

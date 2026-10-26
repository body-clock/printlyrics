---
sourcesHash: efd4ae5e884ab3bd476e5d9e6d90fc3bf0b6799faf785b5e55cab45d51bc6ff0
id: button
description: >-
  Invoke one immediate action or styled navigation step through the shared
  filled, outlined, print, or quiet text action.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/lyrics/new.html.erb
  - app/views/lyrics/show.html.erb
  - app/views/shared/_account_prompt.html.erb
  - app/views/shared/_google_sign_in.html.erb
  - app/views/shared/_library_prompt.html.erb
  - app/views/shared/_songbook_prompt.html.erb
  - app/views/saved_items/index.html.erb
  - app/views/sessions/new.html.erb
  - app/views/registrations/new.html.erb
  - app/views/feedbacks/new.html.erb
tests:
  - test/system/accounts_test.rb
  - test/integration/lyrics_flow_test.rb
---

# Button

## When to use

- The visitor's next step changes server state or commits the form they are
  looking at: generate a page, sign in, save, print, send feedback.
- The page presents a destination as an action rather than as navigation, such
  as making a first sheet from an empty library.
- Use `.button-primary` for the one commitment of the surface. A second action
  beside it is `.button-secondary` or `.button-text`.
- Use `.button-secondary` for retry, cancel, add-another, or a comparable action
  next to a primary one.
- Use `.button-print` in the print-preview control bar for the print action. It
  is the bar's primary action and is never used outside that bar.
- Use `.button-text` for a dismiss, remove, or decline that must stay quieter
  than the decision the surface is asking for. Add `.button-text-danger` when
  the action removes something.

## When not to use

- Navigation among the site's pages, guides, and account surfaces. Use the site
  header or footer links instead.
- A choice between mutually exclusive display options, such as lyric size or
  column count. Use [Segmented control](segmented-control.md).
- A value entered into a form, including a submit styled as part of the field.
  Use [Field](field.md) and its form's native submit.
- An icon-only control. Those remain component-owned; give the control an
  accessible name and do not reduce it to a glyph-only Button.

## Public API

```erb
<%= form.button t(".submit"), class: "button button-primary" %>
<%= form.button t(".retry"), class: "button button-secondary" %>
<%= link_to t(".make_one"), root_path, class: "button button-primary" %>
<%= button_to t(".dismiss"), path, method: :delete, class: "button-text" %>
<%= button_to t(".remove"), path, method: :delete,
      class: "button-text button-text-danger" %>
```

- `.button` is the base for `<button>` and `<a>`. It owns the inline-flex
  layout, `--control-lg` minimum height, horizontal padding, the label size
  (`--text-label`), weight, radius, and focus/hover transitions.
- `.button-primary` fills with `--ui-primary` and uses `--ui-on-primary`. On
  hover it fills with `--ui-accent`. Use it once per surface.
- `.button-secondary` uses a `--elevation-surface` fill and a
  `--border-default` edge. It is the normal partner to a primary action.
- `.button-print` fills with `--ui-primary` at the shared 44px control height.
  The workspace action band owns its placement.
- `.button-wide` stretches to the available width and separates its label from
  a trailing glyph when that composition needs one.
- `.button-text` is the quiet action: no border or fill, `--text-meta`,
  underline, `--content-secondary`, and a 44px minimum pointer target.
  `.button-text-danger` changes the hover colour to `--ui-danger`.
- There is no size modifier. Primary form actions use the 48px base; compact
  working contexts may use the shared 44px control height, never less.
- Labels wrap within their available width under enlarged text. Form actions use
  `<button>` rather than nonwrapping submit inputs; never clip an action label.

The label is consumer-supplied and should name the outcome in sentence case.
Do not use a Button to toggle a setting; the control's pressed state would be
lost.

## Behaviour and states

- Hover changes colour or fill only. There is no movement, scale, or shadow.
- Focus uses the global 3px opaque focus ring.
- Disabled state is the native `disabled` attribute with reduced opacity and a
  non-interactive cursor. Search results retain their explicit loading labels.
- `.button-text` follows the same focus and disabled rules.
- Turbo and form semantics stay with the caller; the component does not submit,
  confirm, or navigate on its own.

## Accessibility

- Use a native `<button>` for an action and an `<a>` for navigation. Do not put
  a click handler on a `<div>`.
- Every Button has visible text that names the outcome. An icon may accompany
  the text and is `aria-hidden="true"`.
- A destructive quiet action keeps its accessible name specific ("Remove
  The Quiet Part"); the visible label may be the generic "Remove" when the
  accessible name supplies the object.
- Do not use colour alone to distinguish primary from secondary; the fill and
  edge differ.

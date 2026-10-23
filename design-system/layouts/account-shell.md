---
sourcesHash: 5e5515ad089be3bf57706e94b9c0d9e78cfd342778d2c6d128a5967b54935a78
id: account-shell
description: >-
  Arrange a narrow account page with one heading, a single bordered panel for
  one form, and the secondary account links below it.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/sessions/new.html.erb
  - app/views/registrations/new.html.erb
  - app/views/passwords/new.html.erb
  - app/views/passwords/edit.html.erb
  - app/views/shared/_google_sign_in.html.erb
  - app/views/shared/_form_errors.html.erb
tests:
  - test/integration/accounts_flow_test.rb
---

# Account shell

## When to use

- Sign in, registration, password reset request, and password change.
- Any future single-form account task that fits the same reading width.

## When not to use

- The library, which is a grid of saved things. It reuses `.account-shell` only
  as a width base through `.library-shell` and uses the saved-library pattern.
- The entry page or feedback form. Use the site shell's `.landing-shell`.
- A settings page with several independent panels. The shell supports one
  panel; multiple panels need a layout decision.

## Public API

```erb
<div class="account-shell">
  <header class="account-heading">
    <p class="eyebrow">Your account</p>
    <h1>Sign in</h1>
    <p>...</p>
  </header>

  <%= render "shared/flash" %>

  <div class="account-panel">
    <%= render "shared/google_sign_in" if google_sign_in_available? %>
    <p class="account-divider">or use your email</p>
    <%= render "shared/form_errors", errors: @user.errors %>
    <%= form_with ..., class: "account-form" do |form| %>...<% end %>
  </div>

  <div class="account-links">...</div>
</div>
```

- `.account-shell` is `--layout-reading` wide with the page-shell top padding.
- `.account-heading` is bounded by `--measure-prose`; the `h1` uses
  `--text-display`; the intro uses `--content-secondary`.
- `.account-panel` is bounded by `--measure-panel`, has a
  `--border-default` edge, `--radius-md`, `--elevation-surface`, and `--space-6`
  padding.
- `.account-form` is a single-column grid; its submit is
  `.button-secondary` except the Google action, which is the panel's one filled
  button.
- `.account-divider` separates the Google route from the email route.
- `.account-links` holds the reset and alternate-flow links below the panel.

## Composition

- One panel per page. Google is first and loudest when configured; the email
  form is the fallback. Do not reorder them.
- The error summary is the first content inside the panel when the model has
  errors, before the form or between the Google control and the form.
- The flash sits between the heading and the panel, not inside the panel.
- The heading, panel, and links share the same left edge. Do not centre the
  panel independently.
- The form owns its fields and labels; the shell does not add field spacing.
- Below `700px` the shell narrows, the heading display resolves to its 2rem
  floor, and the panel padding drops to `--space-5`.

## Accessibility

- The page has one `h1` and its intro paragraph follows it.
- The panel is a plain container, not a landmark. The form is the landmark
  through its native form semantics and labels.
- The Google action and the email submit both name their route; do not label
  either simply "Continue".
- The decorative divider is a `<p>` with visible text; it is not an `hr` with
  an aria-label and it does not carry meaning that exists only in styling.
- The error summary is announced by its own `role="alert"`; the shell does not
  add a second live region.

---
sourcesHash: d9370eb8cf105a34159407b6a4a2d1b24d820eafd1ec89e16cbfd1d4a09d6954
id: account-shell
description: >-
  Arrange a narrow account or feedback task with one heading, a single bordered
  form panel, and secondary account links when relevant.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/sessions/new.html.erb
  - app/views/registrations/new.html.erb
  - app/views/passwords/new.html.erb
  - app/views/passwords/edit.html.erb
  - app/views/shared/_google_sign_in.html.erb
  - app/views/shared/_form_errors.html.erb
  - app/views/feedbacks/new.html.erb
  - app/views/shared/_account_context.html.erb
tests:
  - test/integration/accounts_flow_test.rb
---

# Account shell

## When to use

- Sign in, registration, password reset request, and password change.
- Feedback or another single-form task that fits the same reading width.

## When not to use

- The library uses `.account-shell.library-shell` only as a width base and
  composes the saved-library list rather than a form panel.
- The entry page uses its dedicated workspace shell.
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
- `.account-form` is a single-column grid. Its submit is secondary when a
  configured Google action is the panel's primary route; without Google, email
  is primary. Reset/feedback forms have one primary submit.
- `.account-divider` separates the Google route from the email route.
- `.account-links` holds the reset and alternate-flow links below the panel.
- `.account-context` explains the pending item's save-and-return detour above
  the panel. `.account-cancel` is a visible, minimum-44px action in the account
  links region; it does not abandon the pending item silently.

## Composition

- One panel per page. Google is first and loudest when configured; the email
  form is the fallback. Do not reorder them.
- The error summary is the first content inside the panel when the model has
  errors, before the form or between the Google control and the form.
- The flash sits between the heading and the panel, not inside the panel.
- The heading, panel, and links share the same left edge. Do not centre the
  panel independently.
- The form owns its fields and labels; the shell does not add field spacing.
- The shell stays a readable column at every width. Phone padding reduces
  without reducing action height, 16px input text, or label/error readability.

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

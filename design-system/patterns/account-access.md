---
sourcesHash: d822c906f1cb4b58966446d706a32d1d62da1d438aa7f6c8fc06a22cfc93f2a4
id: account-access
description: >-
  Sign in, create an account, or reset a password while keeping the sheet the
  visitor came to save, with Google first when configured and email as fallback.
status: discoverable
sources:
  - app/views/sessions/new.html.erb
  - app/views/registrations/new.html.erb
  - app/views/passwords/new.html.erb
  - app/views/passwords/edit.html.erb
  - app/views/shared/_google_sign_in.html.erb
  - app/controllers/sessions_controller.rb
  - app/controllers/registrations_controller.rb
  - app/controllers/passwords_controller.rb
  - app/views/shared/_account_context.html.erb
  - app/views/shared/_field_feedback.html.erb
  - app/helpers/application_helper.rb
tests:
  - test/integration/accounts_flow_test.rb
  - test/integration/google_sign_in_flow_test.rb
  - test/system/accounts_test.rb
---

# Account access

## When to use

- A visitor chooses to sign in, register, or recover a password.
- A save-to-library action needs an account; the flow returns the visitor to the
  sheet or library after success.

## When not to use

- Managing saved items. Use the saved-library pattern.
- Gating the tool. Search, manual entry, preview, printing, and token-addressed
  pages must remain usable signed out.

## Structure

Required regions, in order:

1. **Heading** — `h1` and one short paragraph explaining the account's benefit.
2. **Flash** — if the request produced an outcome.
3. **Panel** — Google action when configured, a decorative divider, optional
   error summary, and one email form.
4. **Links** — password reset, alternate flow (sign in ↔ register), and an
   explicit Cancel and return action.

The email form differs by page:

- **Sign in** — email and current password; submit "Sign in with email".
- **Register** — email, new password, confirmation, and the length hint;
  submit "Create account".
- **Reset request** — email; submit "Email reset instructions".
- **Reset** — new password and confirmation; submit "Save password".

## Composition

- Google is first and is the panel's only filled action when available. The
  email submit is secondary. When Google is not configured, the Google block and
  divider are absent and email becomes the single primary action.
- The Google action is a real POST form, not a link and not a Turbo form: the
  request must leave the application for the provider.
- One panel, one form. A page does not stack "sign in" and "register" forms;
  the link moves to the other page.
- The error summary appears inside the panel above the form, after the Google
  block when present.
- The password hint is advisory and does not replace the native length
  constraint.
- After success, return to the sheet or library the visitor was trying to keep.
  Do not land on a generic dashboard.
- When a save is pending, show the item's title and explain that authentication
  keeps it and returns to that same item. Printing remains available without an
  account. Invalid registration or sign-in retains the pending save and email;
  moving among sign-in, registration, and reset does not clear it.
- Cancel submits DELETE to the session endpoint with `cancel=true`, clears the
  pending save and authentication return destination, and returns to the current
  task without saving or signing out an already authenticated visitor.
- Model validation uses the shared field feedback helper/partial: invalid fields
  expose `aria-invalid` and reference their inline errors. Password hints are
  associated by `aria-describedby`; password fields state the model's minimum.

## Verification

Static:

- Exactly one `h1` and one email form per page; Google and Cancel are separate
  action forms, never competing email forms.
- Google renders only when both credentials are configured.
- Every field has a label and an autocomplete value appropriate to its route.

Behavioural:

- A wrong password re-renders with HTTP 422, an associated error, and the entered
  email intact.
- A short password on registration shows the model's message next to the field
  as well as in the summary and preserves any pending save.
- Google sign-in creates or signs into an account and returns to the intended
  destination; an unconfigured deployment hides the control and refuses the
  request phase.
- Signing out returns the header to the signed-out state.

Commands:

```sh
bin/rails test test/integration/accounts_flow_test.rb
bin/rails test test/integration/google_sign_in_flow_test.rb
bin/rails test test/system/accounts_test.rb
```

An intentional violation: a second filled action in the panel, or a Google
control rendered without credentials, must be rejected.

---
sourcesHash: e73b121e0b3a3116abb5ee03964035379a316a860048fc6555bc1b922a04db9b
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

1. **Heading** — eyebrow, `h1`, and one paragraph explaining the account's
   benefit.
2. **Flash** — if the request produced an outcome.
3. **Panel** — Google action when configured, a decorative divider, optional
   error summary, and one email form.
4. **Links** — password reset and the alternate flow (sign in ↔ register).

The email form differs by page:

- **Sign in** — email and current password; submit "Sign in with email".
- **Register** — email, new password, confirmation, and the length hint;
  submit "Create account".
- **Reset request** — email; submit "Email reset instructions".
- **Reset** — new password and confirmation; submit "Save password".

## Composition

- Google is first and is the panel's only filled action when available. The
  email submit is secondary. When Google is not configured, the Google block and
  divider are absent and the email submit remains the single route.
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

## Verification

Static:

- Exactly one `h1` and one form per page.
- Google renders only when both credentials are configured.
- Every field has a label and an autocomplete value appropriate to its route.

Behavioural:

- A wrong password re-renders the page with the error summary and a flash-free
  form.
- A short password on registration shows the model's message.
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

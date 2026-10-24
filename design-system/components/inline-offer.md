---
sourcesHash: 4afeb3e04e2a67ba59d535eadc0556153f1dcd6df5ab1726bcff14480561a36a
id: inline-offer
description: >-
  Offer one optional next step beneath the page's main result, such as keeping a
  sheet, gathering sheets into a songbook, saving to a library, or reporting a
  print problem.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_account_prompt.html.erb
  - app/views/shared/_library_prompt.html.erb
  - app/views/shared/_songbook_prompt.html.erb
  - app/views/shared/_feedback_prompt.html.erb
tests:
  - test/system/organic_conversion_test.rb
  - test/system/accounts_test.rb
---

# Inline offer

## When to use

- The page has already delivered its main result (a generated sheet, a library
  page, a search miss) and there is one optional next step tied to that result.
- The offer can be declined without losing the result.
- The offer is placed after the thing it refers to: under the paper, under the
  entry panel, or under the search miss.

## When not to use

- The visitor must decide before continuing. There is no modal or blocking
  prompt component; use page copy instead.
- The outcome is a server status or an error. Use [Flash](flash.md).
- The offer is unrelated to the current sheet or visit.
- The offer has already been dismissed for this visit. Visibility is
  server-owned; do not re-render it client-side.

## Public API

Four partials with distinct anatomy and one shared visual role:

```erb
<%= render "shared/account_prompt", item: @lyric, surface: "sheet" %>
<%= render "shared/library_prompt", item: @lyric %>
<%= render "shared/songbook_prompt", surface: "sheet" %>
<%= render "shared/feedback_prompt", page_key: @generated_page_key %>
```

- **Account offer** (`.account-prompt`): title, body, a primary save action,
  and a `.button-text` dismiss. `surface` is required and is either `sheet` or
  `entry`; it labels the analytics property and selects the copy.
- **Library offer** (`.library-prompt`): a one-line signed-in save, a
  "already saved" line, or a "library is full" line. The save action is
  secondary. No dismiss is needed because the visitor already has an account.
- **Songbook offer** (`.songbook-prompt`): one message with `role="status"`, a
  primary "Make a songbook" action, and a compact dismiss button. It is
  server-gated by `visit.offer_pending?`; `surface` is required.
- **Feedback line** (`.feedback-prompt`): one line of copy and a link to the
  feedback page. It only renders when `page_key` is present.

All variants are `no-print` and sit below the result. The offer width follows
the result (sheet width on the preview, full width on the entry panel).

## Behaviour and states

- An offer never auto-dismisses and never steals focus.
- Dismiss sends a request; the visit stores the answer, so the offer disappears
  on the next server render for the rest of the visit.
- The songbook offer's dismiss is a compact bordered control
  (`.songbook-prompt-dismiss`) rather than a bare text action, because it sits
  beside a primary action in a narrow strip.
- A prompt is not interactive until its server condition is true. Do not hide
  or reveal it with client-side state.
- On a phone the sheet-width prompts shrink to the viewport; the entry prompt is
  already fluid.

## Accessibility

- The songbook message uses `role="status"`; the other prompts are ordinary
  landmarks-free content and need no live region.
- Every action names its outcome: "Save this sheet", "Make a songbook",
  "Remove…", "Send feedback". A dismiss action is labelled by its visible text
  or an `aria-label` on the containing form.
- Do not make the whole strip clickable; the action is a real button or link.
- The account and songbook offers appear after the result in DOM order, so a
  screen-reader user reaches the result first.

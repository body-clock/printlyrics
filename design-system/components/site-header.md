---
sourcesHash: 2b3823499de15ba74c592a9d6c2cc74241d2f838648aed5fd7ebbfa7a1e5501e
id: site-header
description: >-
  Provide the site's single global navigation surface with the brand, a
  current-page-aware tool link, and the account controls.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/shared/_site_header.html.erb
  - app/views/layouts/application.html.erb
tests:
  - test/system/accounts_test.rb
  - test/integration/accounts_flow_test.rb
---

# Site header

## When to use

- Every normal page, rendered once by the layout above `<main>`.
- It is the only global navigation. The footer holds the guides and feedback,
  not the primary tool link.

## When not to use

- Print previews and songbooks, which hide site chrome because their control
  bar owns the top of the page.
- Email layouts.
- A page-local section navigation or a table of contents.

## Public API

```erb
<%= render "shared/site_header" %>
```

- The root is `<header class="site-header no-print">` with
  `.site-header-inner` bounded by `--layout-wide`.
- `.site-brand` links home.
- `.site-nav` holds the tool link and is omitted on the homepage and below
  `700px`.
- `.site-account` holds the account controls. Signed in: a truncated email
  span, a library link (omitted on the library page), and a
  `.site-account-link` sign-out button. Signed out: sign-in and register links;
  register uses `.site-account-register`.
- The current page is never linked to itself.

## Behaviour and states

- The header is sticky at `z-index: 35` with a `--border-default` bottom edge
  and the canvas fill.
- Every header item occupies `--control-xs`, and the inner band reserves that
  height plus padding, so the header cannot change height from page to page.
- Below `700px` the one-item nav is hidden and the email is not shown.
- Sign-out is a `button_to` DELETE form styled as a link.
- The brand hover and account link hover use `--ui-accent-hover`.

## Accessibility

- The root is a `<header>` containing two `<nav>` landmarks, each with an
  `aria-label` from the locale files. Keep both labels when the nav content
  changes.
- The brand is a link to the homepage; do not remove it on inner pages.
- The sign-out control is a real button inside a form, not an anchor.
- The email is informational; its `title` carries the full address when the
  span truncates. Do not rely on the truncated text as an accessible name for
  an action.
- Focus uses the global ring. The sticky header must not cover the focused
  element; `scroll-margin` belongs to the focused content, not the header.

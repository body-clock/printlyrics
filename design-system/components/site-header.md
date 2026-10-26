---
sourcesHash: 02aecd5b6234454405da66b9854e30f51d1169d4e2cd62010bfb49280c343fac
id: site-header
description: >-
  Provide the site's single quiet global navigation surface with a home-linked
  brand and one account navigation region.
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
- The brand is the tool/home navigation; do not duplicate it with another tool
  link or navigation landmark.
- `.site-account` holds account controls. Signed in: a truncated email span,
  a library link (omitted on the library page), and a `.site-account-link`
  sign-out button. Signed out: only a quiet sign-in link; account creation is
  available within sign-in, not as a competing global action.
- The account region omits a link to its current page. The brand remains the
  stable home destination, including on entry.

## Behaviour and states

- The header is sticky at `z-index: 35` with a `--border-default` bottom edge
  and the canvas fill.
- Interactive controls have at least a 44px target, including brand and sign-out.
- Narrow layouts hide the informational email rather than shrinking controls.
- Sign-out is a `button_to` DELETE form styled as a link.
- The brand hover and account link hover use `--ui-accent-hover`.

## Accessibility

- The root is a `<header>` containing one labelled account `<nav>` landmark.
  The home-linked brand is outside that region.
- The brand is a link to the homepage; do not remove it on inner pages.
- The sign-out control is a real button inside a form, not an anchor.
- The email is informational; its `title` carries the full address when the
  span truncates. Do not rely on the truncated text as an accessible name for
  an action.
- Focus uses the global ring. The sticky header must not cover the focused
  element; `scroll-margin` belongs to the focused content, not the header.
